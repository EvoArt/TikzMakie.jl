# Scatter markers

"Element `i` of a per-element attribute, or the attribute itself if it is a scalar (StaticVectors such as `Vec3f` count as scalars)."
per_index(x, i) = x isa AbstractVector && !(x isa VecTypes) ? x[min(i, end)] : x

to_vec2(x::Real) = Vec2d(x, x)
to_vec2(x::VecTypes) = Vec2d(x[1], length(x) > 1 ? x[2] : x[1])
to_vec2(x::Tuple) = Vec2d(x[1], x[2])

rotation_angle(r::Real) = Float64(r)
rotation_angle(q::Makie.Quaternion) = Float64(Makie.quaternion_to_2d_angle(q))
rotation_angle(b::Makie.Billboard) = rotation_angle(b.rotation)
rotation_angle(r) = 0.0

"2×2 linear map from marker coordinates (unit marker, y up) to figure units."
function marker_basis(ms::Vec2d, angle::Real, scale::Vec2d)
    c, s = cos(angle), sin(angle)
    return (Vec2d(c * ms[1] * scale[1], s * ms[1] * scale[2]), Vec2d(-s * ms[2] * scale[1], c * ms[2] * scale[2]))
end

apply_basis(o, (ex, ey), v) = Point2d(o[1] + ex[1] * v[1] + ey[1] * v[2], o[2] + ex[2] * v[1] + ey[2] * v[2])

"""
Scale from markerspace units to figure units at a projected position. Pixel
markerspace is 1:1; data markerspace is measured by projecting unit steps.
"""
function markerspace_scale(scene, markerspace::Symbol, pos_markerspace)
    markerspace === :pixel && return Vec2d(1, 1)
    P = Projector(scene, markerspace)
    o = P(pos_markerspace)
    ex = P(pos_markerspace .+ Vec3d(1, 0, 0)) .- o
    ey = P(pos_markerspace .+ Vec3d(0, 1, 0)) .- o
    return Vec2d(hypot(ex...), hypot(ey...))
end

function emit_path_command(io, ctx, cmd, mapf)
    if cmd isa MoveTo
        print(io, " ", coord(ctx, mapf(cmd.p)))
    elseif cmd isa LineTo
        print(io, " -- ", coord(ctx, mapf(cmd.p)))
    elseif cmd isa CurveTo
        print(io, " .. controls ", coord(ctx, mapf(cmd.c1)), " and ", coord(ctx, mapf(cmd.c2)), " .. ", coord(ctx, mapf(cmd.p)))
    elseif cmd isa ClosePath
        print(io, " -- cycle")
    elseif cmd isa EllipticalArc
        # the arc's start point is already the current point
        for c in Makie.elliptical_arc_to_beziers(cmd).commands
            c isa MoveTo || emit_path_command(io, ctx, c, mapf)
        end
    end
    return
end

"""
    bezier_to_tikz(ctx, bp, mapf; close = false)

TikZ path for a `BezierPath`, with each control point mapped through `mapf`
(path coordinates → figure units). `close` appends `-- cycle` when the path
does not already end with one.
"""
function bezier_to_tikz(ctx, bp::BezierPath, mapf; close::Bool = false)
    io = IOBuffer()
    foreach(cmd -> emit_path_command(io, ctx, cmd, mapf), bp.commands)
    s = String(take!(io))
    close && !endswith(s, "cycle") && (s *= " -- cycle")
    return s
end

marker_path_commands(ctx, marker::BezierPath, o, basis) = bezier_to_tikz(ctx, marker, v -> apply_basis(o, basis, v))

function marker_path(ctx, marker, o, basis, ms)
    if marker === Circle || marker isa Circle
        ex, ey = basis
        rx, ry = hypot(ex...) / 2, hypot(ey...) / 2
        if isapprox(rx, ry; rtol = 1.0e-3)
            return " " * coord(ctx, o) * " circle[radius=" * fmt(ctx, rx) * "]"
        else
            ang = atan(ex[2], ex[1]) * 180 / pi
            return " " * coord(ctx, o) * " circle[x radius=" * fmt(ctx, rx) * ", y radius=" * fmt(ctx, ry) * ", rotate=" * fmt(ang, 2) * "]"
        end
    elseif marker === Rect || marker isa Rect || marker isa Makie.FastPixel
        cs = (Vec2d(-0.5, -0.5), Vec2d(0.5, -0.5), Vec2d(0.5, 0.5), Vec2d(-0.5, 0.5))
        return " " * join((coord(ctx, apply_basis(o, basis, c)) for c in cs), " -- ") * " -- cycle"
    elseif marker isa BezierPath
        return marker_path_commands(ctx, marker, o, basis)
    else
        return nothing
    end
end

function draw_plot!(ctx, scene::Scene, plot::Scatter)
    pts = plot_positions(plot)
    isempty(pts) && return
    space = getattr(plot, :space, :data)
    markerspace = getattr(plot, :markerspace, :pixel)
    P = Projector(scene, plot)
    to_ms = markerspace === :pixel ? nothing :
        Mat4d(Makie.get_space_to_space_matrix(scene, space, markerspace)) * Mat4d(getattr(plot, :model_f32c, Mat4d(I)))

    colors = computed_color(plot)
    markers = getattr(plot, :marker)
    sizes = getattr(plot, :markersize)
    strokecolors = getattr(plot, :strokecolor, RGBAf(0, 0, 0, 0))
    strokewidths = getattr(plot, :strokewidth, 0.0)
    rotations = getattr(plot, :rotation, 0.0)
    offsets = getattr(plot, :marker_offset, Vec3f(0))

    r = clip_rect(ctx)
    cur_style = nothing
    buf = String[]
    flush!() = (if cur_style !== nothing && !isempty(buf)
        println(ctx.io, "\\path[", cur_style, "]", join(buf), ";")
    end; empty!(buf))

    for i in eachindex(pts)
        p = pts[i]
        isfinitepoint(p) || continue
        o = P(p)
        isfinitepoint(o) && inrect(o, r) || continue
        marker = Makie.to_spritemarker(per_index(markers, i))
        ms = to_vec2(per_index(sizes, i))
        (all(isfinite, ms) && any(!iszero, ms)) || continue
        scale = Vec2d(1, 1)
        if to_ms !== nothing
            pm4 = to_ms * Vec4d(p[1], p[2], length(p) > 2 ? p[3] : 0.0, 1.0)
            scale = markerspace_scale(scene, markerspace, Vec3d(pm4[1], pm4[2], pm4[3]) ./ pm4[4])
        end
        off = per_index(offsets, i)
        o = Point2d(o[1] + off[1] * scale[1], o[2] + off[2] * scale[2])
        angle = rotation_angle(per_index(rotations, i))
        basis = marker_basis(ms, angle, scale)

        fs = fill_style(ctx, per_index(colors, i))
        sw = per_index(strokewidths, i)
        ss = draw_style(ctx, per_index(strokecolors, i), sw)
        (fs === nothing && ss === nothing) && continue

        if marker isa Char
            flush!(); cur_style = nothing
            draw_char_marker(ctx, marker, o, ms[2] * scale[2], angle, per_index(colors, i))
            continue
        end
        path = marker_path(ctx, marker, o, basis, ms)
        if path === nothing
            warn_once(ctx, (:marker, typeof(marker)), "TikzMakie: scatter marker of type $(typeof(marker)) is not supported; drawing a circle instead.")
            path = marker_path(ctx, Circle, o, basis, ms)
        end
        style = joinstyles(fs, ss)
        # merging markers into one path is only exact for opaque fills
        mergeable = coloralpha(per_index(colors, i)) >= 0.999 && ss === nothing
        if style != cur_style || !mergeable || length(buf) >= 8
            flush!()
            cur_style = style
        end
        push!(buf, path)
        mergeable || flush!()
    end
    flush!()
    return
end

function draw_char_marker(ctx, ch::Char, o, size, angle, color)
    fs = isinvisible(color) ? nothing : "text=" * colorname!(ctx, color)
    a = coloralpha(color)
    opts = joinstyles(
        "mknode", "anchor=center", fs, a < 0.999 ? "text opacity=" * fmt(a, 3) : nothing,
        abs(angle) > 1.0e-6 ? "rotate=" * fmt(angle * 180 / pi, 2) : nothing,
        "font=\\fontsize{" * fmt(size * ctx.opts.pt_per_unit, 2) * "}{" * fmt(1.2 * size * ctx.opts.pt_per_unit, 2) * "}\\selectfont"
    )
    println(ctx.io, "\\node[", opts, "] at ", coord(ctx, o), " {", latex_escape(string(ch); unicode = ctx.opts.unicode), "};")
    return
end
