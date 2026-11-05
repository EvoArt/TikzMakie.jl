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
is_tikz_atomic(p::Plot) = isempty(p.plots) || rasterize_level(p) != 0
is_tikz_atomic(::Text) = true
is_tikz_atomic(::Poly) = true
is_tikz_atomic(::Band) = true

"""
Makie's `rasterize` attribute as a number (0 = vector output). Makie stores
`rasterize = true` as `1`; both mean "use `rasterize_scale`".
"""
rasterize_level(p::Plot) = Int(to_value(get(p, :rasterize, false)))

"""
    rasterize_plot(scene, plot, scale) -> Union{Nothing, Matrix{RGBA{N0f8}}}

Render `plot` into an image covering `scene`'s viewport at `scale` pixels per
unit. Implemented by the CairoMakie extension; returns `nothing` without it.
"""
rasterize_plot(scene, plot, scale) = nothing

function draw_rasterized!(ctx, scene::Scene, plot::Plot)
    level = rasterize_level(plot)
    scale = level == 1 ? ctx.opts.rasterize_scale : Float64(level)
    img = rasterize_plot(scene, plot, scale)
    if img === nothing
        warn_once(ctx, :rasterize, "TikzMakie: plots with `rasterize` set need CairoMakie loaded (`using CairoMakie`); drawing them as vectors instead.")
        return draw_plot!(ctx, scene, plot)
    end
    r = viewport_rect(scene)
    o, w = Makie.origin(r), Makie.widths(r)
    ref = add_image!(ctx, img)
    println(
        ctx.io, "\\node[mkimg, anchor=south west] at ", coord(ctx, o),
        " {\\includegraphics[width=", pt(ctx, w[1]), ", height=", pt(ctx, w[2]), "]{", ref, "}};"
    )
    return
end

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
        if rasterize_level(p) != 0
            draw_rasterized!(ctx, pscene, p)
        else
            draw_plot!(ctx, pscene, p)
        end
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
    lines = split(body, '\n')
    istext(l) = startswith(l, "\\node[mknode")
    counts = Dict{String, Int}()
    for l in lines
        istext(l) || continue
        m = match(NODE_FONT_RE, l)
        m === nothing || (counts[m.captures[1]] = get(counts, m.captures[1], 0) + 1)
    end
    isempty(counts) && return body, nothing
    font = first(sort!(collect(counts); by = x -> (-x[2], x[1])))[1]
    pat = ", font=" * font * "]"
    return join((istext(l) ? replace(l, pat => "]"; count = 1) : l for l in lines), '\n'), font
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
    nodestyle = "inner sep=0pt, outer sep=0pt"
    # Makie aligns text by the font's ascender/descender, not the ink; a
    # phantom parenthesis gives every node at least that height and depth
    o.strut && (nodestyle *= ", execute at begin node={\\vphantom{(}}")
    nodefont === nothing || (nodestyle *= ", font=" * nodefont)
    # mknode: text; mkimg: images and character markers (no strut, no font)
    println(
        io, "\\begin{tikzpicture}[x=", u, "pt, y=", u, "pt, mknode/.style={", nodestyle,
        "}, mkimg/.style={inner sep=0pt, outer sep=0pt}]"
    )
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
