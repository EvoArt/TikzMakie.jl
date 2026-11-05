# Poly and Band, drawn as vector paths instead of triangle meshes.

"""
    resolve_colors(plot, color)

Resolve a recipe-level `color` attribute (colours, numbers to colormap, or
vectors of either) to concrete colours, using the plot's colormap
attributes. Returns a colour, a vector of colours, or `nothing` if it cannot
be resolved (patterns, per-vertex arrays, …).
"""
function resolve_colors(plot, color)
    color isa Makie.AbstractPattern && return nothing
    if color isa Real || (color isa AbstractVector{<:Real})
        cmap = Makie.to_colormap(getattr(plot, :colormap, :viridis))
        cr = getattr(plot, :colorrange, Makie.automatic)
        vals = Float64.(color isa Real ? [color] : color)
        if cr === Makie.automatic || cr === nothing
            finite = filter(isfinite, vals)
            cr = isempty(finite) ? (0.0, 1.0) : extrema(finite)
        end
        lo, hi = Float64(cr[1]), Float64(cr[2])
        lo == hi && (hi = lo + 1)
        a = getattr(plot, :alpha, 1.0)
        nan = Makie.to_color(getattr(plot, :nan_color, RGBAf(0, 0, 0, 0)))
        cs = map(vals) do v
            isfinite(v) || return RGBAf(nan)
            c = Makie.interpolated_getindex(cmap, clamp(v, lo, hi), (lo, hi))
            RGBAf(red(c), green(c), blue(c), alpha(c) * a)
        end
        return color isa Real ? cs[1] : cs
    end
    try
        a = getattr(plot, :alpha, 1.0)
        if color isa AbstractVector
            return [(c = Makie.to_color(x); RGBAf(red(c), green(c), blue(c), alpha(c) * a)) for x in color]
        else
            c = Makie.to_color(color)
            return RGBAf(red(c), green(c), blue(c), alpha(c) * a)
        end
    catch
        return nothing
    end
end

# geometry → list of rings (each a vector of points in plot space)
poly_rings(p::GeometryBasics.Polygon) = vcat([decompose(Point2d, p.exterior)], [decompose(Point2d, i) for i in p.interiors])
poly_rings(p::GeometryBasics.MultiPolygon) = reduce(vcat, [poly_rings(x) for x in p.polygons]; init = Vector{Point2d}[])
poly_rings(r::Rect2) = [decompose(Point2d, r)]
poly_rings(c::Circle) = [decompose(Point2d, c)]
poly_rings(v::AbstractVector{<:VecTypes{2}}) = [Point2d.(v)]
poly_rings(b::BezierPath) = nothing   # handled separately
poly_rings(x) = nothing

"Split a converted poly argument into a list of shapes, one per colour."
poly_shapes(x::AbstractVector{<:Union{GeometryBasics.Polygon, GeometryBasics.MultiPolygon, Rect2, Circle, BezierPath, AbstractVector{<:VecTypes{2}}}}) = x
poly_shapes(x::AbstractVector{<:VecTypes{2}}) = [x]
poly_shapes(x::Union{GeometryBasics.Polygon, GeometryBasics.MultiPolygon, Rect2, Circle, BezierPath}) = [x]
poly_shapes(x) = nothing

function draw_plot!(ctx, scene::Scene, plot::Poly)
    shapes = poly_shapes(plot[1][])
    fills = resolve_colors(plot, getattr(plot, :color))
    strokes = resolve_colors(plot, getattr(plot, :strokecolor, :black))
    if shapes === nothing || fills === nothing || strokes === nothing ||
            (fills isa AbstractVector && length(fills) != length(shapes))
        # per-vertex colours, patterns or unusual inputs: draw the mesh + lines children
        return draw_children!(ctx, scene, plot)
    end
    sws = getattr(plot, :strokewidth, 0.0)
    f, P = recipe_mapper(scene, plot)
    cap = linecap_name(getattr(plot, :linecap, :butt))
    join_ = joinstyle_name(getattr(plot, :joinstyle, :miter))
    linestyle = getattr(plot, :linestyle, nothing)

    for (i, shape) in enumerate(shapes)
        fc = per_index(fills, i)
        sc = per_index(strokes, i)
        sw = per_index(sws, i)
        fs = fill_style(ctx, fc)
        ds = draw_style(ctx, sc, sw)
        (fs === nothing && ds === nothing) && continue
        if shape isa BezierPath
            path = bezier_to_tikz(ctx, shape, p -> P(f(p)); close = true)
        else
            rings = poly_rings(shape)
            rings === nothing && continue
            parts = String[]
            for ring in rings
                pts = [P(f(p)) for p in ring if isfinitepoint(p)]
                length(pts) >= 2 || continue
                all(isfinitepoint, pts) || continue
                push!(parts, " " * join((coord(ctx, q) for q in pts), " -- ") * " -- cycle")
            end
            isempty(parts) && continue
            path = join(parts)
        end
        extra = String[]
        # holes (polygon interiors, multi-ring bezier paths) need even-odd filling
        count(" -- cycle", path) > 1 && push!(extra, "even odd rule")
        if ds !== nothing
            cap != "butt" && push!(extra, "line cap=" * cap)
            join_ != "miter" && push!(extra, "line join=" * join_)
            d = dash_style(ctx, linestyle, sw)
            d !== nothing && push!(extra, d)
        end
        println(ctx.io, "\\path[", joinstyles(fs, ds, extra...), "]", path, ";")
    end
    return
end

function draw_plot!(ctx, scene::Scene, band::Band)
    lower, upper = band[1][], band[2][]
    color = resolve_colors(band, getattr(band, :color))
    if !(lower isa AbstractVector{<:VecTypes{2}}) || color === nothing || color isa AbstractVector
        return draw_children!(ctx, scene, band)
    end
    fs = fill_style(ctx, color)
    if fs !== nothing
        f, P = recipe_mapper(scene, band)
        xdir = getattr(band, :direction, :x) === :x
        lo = xdir ? lower : reverse.(lower)
        up = xdir ? upper : reverse.(upper)
        r = clip_rect(ctx)
        start = nothing
        n = length(lo)
        segments = UnitRange{Int}[]
        for i in 1:n
            ok = isfinitepoint(lo[i]) && isfinitepoint(up[i])
            if ok && start === nothing
                start = i
            elseif !ok && start !== nothing
                i - start > 1 && push!(segments, start:(i - 1))
                start = nothing
            end
        end
        start !== nothing && n - start >= 1 && push!(segments, start:n)
        for rng in segments
            ring = vcat([P(f(p)) for p in lo[rng]], [P(f(p)) for p in reverse(up[rng])])
            # clip by projecting outliers onto the padded rectangle (fills only)
            ring = [Point2d(clamp(q[1], r[1], r[3]), clamp(q[2], r[2], r[4])) for q in ring]
            println(ctx.io, "\\path[", fs, "] ", join((coord(ctx, q) for q in ring), " -- "), " -- cycle;")
        end
    end
    # outlines etc. (band has no stroke by default, but recipes may add lines)
    for child in band.plots
        child isa Mesh && continue
        plot_visible(child) && draw_plot!(ctx, scene, child)
    end
    return
end
