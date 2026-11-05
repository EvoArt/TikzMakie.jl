# Lines and LineSegments

linecap_name(c::Symbol) = linecap_name(Makie.convert_attribute(c, Makie.key"linecap"()))
linecap_name(c::Integer) = c == 1 ? "rect" : c == 2 ? "round" : "butt"
linecap_name(::Nothing) = "butt"

joinstyle_name(j::Symbol) = joinstyle_name(Makie.convert_attribute(j, Makie.key"joinstyle"()))
joinstyle_name(j::Integer) = j == 2 ? "round" : j == 3 ? "bevel" : "miter"
joinstyle_name(::Nothing) = "miter"

"`dash pattern=...` for a Makie linestyle, or `nothing` for solid lines."
function dash_style(ctx, linestyle, linewidth::Real)
    linestyle === nothing && return nothing
    ls = linestyle isa Makie.Linestyle ? linestyle.value :
        Makie.convert_attribute(linestyle, Makie.key"linestyle"()).value
    pattern = diff(Float64.(ls)) .* linewidth
    isempty(pattern) && return nothing
    isodd(length(pattern)) && push!(pattern, 0.0)
    parts = String[]
    for i in 1:2:length(pattern)
        push!(parts, "on " * pt(ctx, pattern[i]) * " off " * pt(ctx, pattern[i + 1]))
    end
    return "dash pattern=" * join(parts, " ")
end

function line_common_style(ctx, plot, linewidth, islines::Bool)
    cap = linecap_name(getattr(plot, :linecap, :butt))
    parts = String[]
    cap != "butt" && push!(parts, "line cap=" * cap)
    if islines
        join_ = joinstyle_name(getattr(plot, :joinstyle, :miter))
        join_ != "miter" && push!(parts, "line join=" * join_)
        if join_ == "miter"
            ml = getattr(plot, :miter_limit, pi / 3)
            ml isa Real && push!(parts, "miter limit=" * fmt(2 * Makie.miter_angle_to_distance(ml), 2))
        end
    end
    lw = linewidth isa Real ? linewidth : 1.0
    d = dash_style(ctx, getattr(plot, :linestyle, nothing), lw)
    d !== nothing && push!(parts, d)
    return parts
end

"Write `\\draw[style] (a) -- (b) -- ...;` for each run, wrapping long lines."
function write_runs(ctx, style::AbstractString, runs; closed = false)
    isempty(runs) && return
    io = ctx.io
    print(io, "\\draw[", style, "]")
    for run in runs
        print(io, "\n  ", coord(ctx, run[1]))
        for (k, p) in enumerate(@view run[2:end])
            print(io, k % 6 == 0 ? "\n  -- " : " -- ", coord(ctx, p))
        end
        closed && print(io, " -- cycle")
    end
    println(io, ";")
    return
end

function draw_plot!(ctx, scene::Scene, plot::Lines)
    pts = plot_positions(plot)
    isempty(pts) && return
    P = Projector(scene, plot)
    px = project(P, pts)
    color = computed_color(plot)
    lw = getattr(plot, :linewidth, 1.0)
    common = line_common_style(ctx, plot, lw, true)
    r = clip_rect(ctx)

    if color isa AbstractArray || lw isa AbstractArray
        # per-vertex colour or width: one segment at a time, averaging endpoints
        for i in 1:(length(px) - 1)
            a, b = px[i], px[i + 1]
            (isfinitepoint(a) && isfinitepoint(b)) || continue
            ok, a2, b2 = clip_segment(a, b, r)
            ok || continue
            c = color isa AbstractArray ? mixcolor(color[i], color[i + 1]) : color
            w = lw isa AbstractArray ? (lw[i] + lw[i + 1]) / 2 : lw
            ds = draw_style(ctx, c, w)
            ds === nothing && continue
            # round caps hide the joints between separately stroked segments
            write_runs(ctx, joinstyles(ds, "line cap=round", common...), [[a2, b2]])
        end
    else
        ds = draw_style(ctx, color, lw)
        ds === nothing && return
        write_runs(ctx, joinstyles(ds, common...), split_polyline(px, r))
    end
    return
end

function mixcolor(a, b)
    a, b = to_rgba(a), to_rgba(b)
    return RGBA((a.r + b.r) / 2, (a.g + b.g) / 2, (a.b + b.b) / 2, (a.alpha + b.alpha) / 2)
end

function draw_plot!(ctx, scene::Scene, plot::LineSegments)
    pts = plot_positions(plot)
    isempty(pts) && return
    P = Projector(scene, plot)
    px = project(P, pts)
    color = computed_color(plot)
    lw = getattr(plot, :linewidth, 1.0)
    r = clip_rect(ctx)
    nseg = length(px) ÷ 2
    colat(i) = color isa AbstractArray ? (length(color) == length(px) ? mixcolor(color[2i - 1], color[2i]) : color[min(i, end)]) : color
    lwat(i) = lw isa AbstractArray ? (length(lw) == length(px) ? (lw[2i - 1] + lw[2i]) / 2 : lw[min(i, end)]) : lw

    # group consecutive segments with identical style into one \draw
    cur_style = nothing
    runs = Vector{Point2d}[]
    for i in 1:nseg
        a, b = px[2i - 1], px[2i]
        (isfinitepoint(a) && isfinitepoint(b)) || continue
        ok, a2, b2 = clip_segment(a, b, r)
        ok || continue
        w = lwat(i)
        ds = draw_style(ctx, colat(i), w)
        ds === nothing && continue
        style = joinstyles(ds, line_common_style(ctx, plot, w, false)...)
        if style != cur_style
            cur_style !== nothing && write_runs(ctx, cur_style, runs)
            cur_style = style
            runs = Vector{Point2d}[]
        end
        push!(runs, [a2, b2])
    end
    cur_style !== nothing && write_runs(ctx, cur_style, runs)
    return
end
