# Scene-tree traversal and document assembly.

root_scene(fig::Figure) = fig.scene
root_scene(fap::Makie.FigureAxisPlot) = fap.figure.scene
root_scene(scene::Scene) = Makie.root(scene)
root_scene(x) = Makie.root(Makie.get_scene(x))

settle!(fig::Figure) = Makie.update_state_before_display!(fig)
settle!(fap::Makie.FigureAxisPlot) = Makie.update_state_before_display!(fap)
settle!(x) = nothing

"""
    is_tikz_atomic(plot)

Plots drawn as a unit by TikzMakie instead of being decomposed into their
children. `Poly` and `Band` become clean vector paths (not triangle meshes);
`Text` becomes LaTeX nodes (its child linesegments are MathTeXEngine's
fraction bars, which LaTeX draws itself).
"""
is_tikz_atomic(p::Plot) = isempty(p.plots)
is_tikz_atomic(::Text) = true
is_tikz_atomic(::Poly) = true
is_tikz_atomic(::Band) = true

function collect_plots!(out, p::Plot)
    if is_tikz_atomic(p)
        push!(out, p)
    else
        foreach(c -> collect_plots!(out, c), p.plots)
    end
    return out
end

function collect_plots!(out, scene::Scene)
    foreach(p -> collect_plots!(out, p), scene.plots)
    foreach(s -> collect_plots!(out, s), scene.children)
    return out
end

plot_visible(p::Plot) = to_value(get(p, :visible, true))::Bool && plot_visible(parent(p))
plot_visible(::Scene) = true
plot_visible(::Nothing) = true

function scene_visible(s::Scene)
    s.visible[] || return false
    return s.parent === nothing ? true : scene_visible(s.parent)
end

viewport_rect(s::Scene) = Makie.viewport(s)[]

function draw_backgrounds!(ctx, scene::Scene, isroot::Bool)
    scene_visible(scene) || return
    if scene.clear[] && (!isroot || ctx.opts.background)
        st = fill_style(ctx, scene.backgroundcolor[])
        if st !== nothing
            r = viewport_rect(scene)
            o, w = Makie.origin(r), Makie.widths(r)
            println(ctx.io, "\\fill[", st, "] ", coord(ctx, o), " rectangle ", coord(ctx, o .+ w), ";")
        end
    end
    foreach(s -> draw_backgrounds!(ctx, s, false), scene.children)
    return
end

function needs_clip(ctx, scene::Scene)
    r = viewport_rect(scene)
    o, w = Makie.origin(r), Makie.widths(r)
    return !(o[1] <= 0 && o[2] <= 0 && o[1] + w[1] >= ctx.size[1] && o[2] + w[2] >= ctx.size[2])
end

function open_clip!(ctx, scene::Scene)
    r = viewport_rect(scene)
    o, w = Makie.origin(r), Makie.widths(r)
    println(ctx.io, "\\begin{scope}")
    println(ctx.io, "\\clip ", coord(ctx, o), " rectangle ", coord(ctx, o .+ w), ";")
    return
end

close_clip!(ctx) = println(ctx.io, "\\end{scope}")

"""
    draw_plot!(ctx, scene, plot)

Emit TikZ for one plot. Methods exist for the atomic plot types; the
fallback recurses into child plots, or warns once if there are none.
"""
function draw_plot!(ctx, scene::Scene, plot::Plot)
    if isempty(plot.plots)
        name = Makie.plotsym(typeof(plot))
        warn_once(ctx, name, "TikzMakie: plot type $name is not supported yet and was skipped.")
    else
        draw_children!(ctx, scene, plot)
    end
    return
end

# PlotLists are containers that are empty when they hold nothing to draw
draw_plot!(ctx, scene::Scene, ::Makie.PlotList) = nothing

function draw_children!(ctx, scene, plot)
    for child in sort(plot.plots; by = Makie.zvalue2d, alg = Base.Sort.DEFAULT_STABLE)
        plot_visible(child) || continue
        draw_plot!(ctx, scene, child)
    end
    return
end

"""
    tikz(fig; kwargs...) -> TikzFigure

Convert a Makie `Figure`, `FigureAxisPlot` or `Scene` to TikZ. See
[`TikzOptions`](@ref) for the keyword arguments. The result's `code` is a
`tikzpicture` environment (or a standalone document with `standalone=true`);
raster images it references are in `images` and are written by
[`savetikz`](@ref).
"""
function tikz(fig; kwargs...)
    opts = TikzOptions(; kwargs...)
    settle!(fig)
    scene = root_scene(fig)
    size = Makie.widths(viewport_rect(scene))
    ctx = TikzContext(opts, size)

    draw_backgrounds!(ctx, scene, true)

    plots = collect_plots!(AbstractPlot[], scene)
    sort!(plots; by = Makie.zvalue2d, alg = Base.Sort.DEFAULT_STABLE)

    current = nothing
    for p in plots
        plot_visible(p) || continue
        pscene = Makie.parent_scene(p)
        scene_visible(pscene) || continue
        if pscene !== current
            current !== nothing && needs_clip(ctx, current) && close_clip!(ctx)
            needs_clip(ctx, pscene) && open_clip!(ctx, pscene)
            current = pscene
        end
        draw_plot!(ctx, pscene, p)
    end
    current !== nothing && needs_clip(ctx, current) && close_clip!(ctx)

    return TikzFigure(assemble(ctx), ctx.images)
end

const NODE_FONT_RE = r", font=(\\fontsize\{[\d.]+\}\{[\d.]+\}\\selectfont)\]"

"""
Move the most common node font (exact size, no weight switches) into the
`mknode` style so that most nodes don't repeat it.
"""
function hoist_node_font(body::String)
    counts = Dict{String, Int}()
    for m in eachmatch(NODE_FONT_RE, body)
        counts[m.captures[1]] = get(counts, m.captures[1], 0) + 1
    end
    isempty(counts) && return body, nothing
    font = first(sort!(collect(counts); by = x -> (-x[2], x[1])))[1]
    return replace(body, ", font=" * font * "]" => "]"), font
end

function assemble(ctx)
    o = ctx.opts
    body = String(take!(ctx.io))
    body, nodefont = hoist_node_font(body)
    io = IOBuffer()
    if o.standalone
        println(io, "\\documentclass[tikz]{standalone}")
        println(io, "\\usepackage[T1]{fontenc}")
        println(io, "\\usepackage{lmodern}")
        println(io, "\\usepackage{graphicx}")
        println(io, "\\begin{document}")
    end
    println(io, "% Generated by TikzMakie.jl. Requires \\usepackage{tikz} (and graphicx if images are used).")
    u = fmt(o.pt_per_unit, 6)
    nodestyle = nodefont === nothing ? "inner sep=0pt, outer sep=0pt" : "inner sep=0pt, outer sep=0pt, font=" * nodefont
    println(io, "\\begin{tikzpicture}[x=", u, "pt, y=", u, "pt, mknode/.style={", nodestyle, "}]")
    foreach(d -> println(io, d), ctx.color_defs)
    println(io, "\\path[use as bounding box] (0,0) rectangle ", coord(ctx, ctx.size), ";")
    print(io, body)
    println(io, "\\end{tikzpicture}")
    o.standalone && println(io, "\\end{document}")
    return String(take!(io))
end

"""
    savetikz(path, fig; kwargs...)
    savetikz(path, t::TikzFigure)

Write the TikZ code for `fig` to `path` (usually `.tex`) and any images next
to it as `<name>-<n>.png`. Include the result in a document with
`\\input{path}`. Returns `path`.
"""
function savetikz(path::AbstractString, fig; kwargs...)
    stem = splitext(basename(path))[1]
    t = tikz(fig; image_basename = stem, kwargs...)
    return savetikz(path, t)
end

function savetikz(path::AbstractString, t::TikzFigure)
    dir = dirname(abspath(path))
    mkpath(dir)
    write(path, t.code)
    for (name, img) in t.images
        PNGFiles.save(joinpath(dir, name), img)
    end
    return path
end
