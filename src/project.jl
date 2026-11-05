# Access to Makie compute-graph attributes and projection to figure pixels.

hasattr(p, name::Symbol) = haskey(p.attributes, name)
getattr(p, name::Symbol) = p.attributes[name][]
getattr(p, name::Symbol, default) = hasattr(p, name) ? p.attributes[name][] : default

unref(x) = x
unref(x::Base.RefValue) = x[]

"""
    computed_color(plot)

Resolved colours of an atomic plot (colormapping applied): a single colour or
an array. Registers Makie's `computed_color` node if a backend has not yet.
"""
function computed_color(plot)
    if !hasattr(plot, :computed_color)
        if hasattr(plot, :scaled_color)
            Makie.compute_colors!(plot.attributes)
        else
            return to_colorlike(getattr(plot, :color))
        end
    end
    return to_colorlike(getattr(plot, :computed_color))
end

to_colorlike(c::Colorant) = RGBAf(c)
to_colorlike(c::AbstractArray{<:Colorant}) = RGBAf.(c)
to_colorlike(c::AbstractArray) = map(x -> to_colorlike(x), c)
to_colorlike(c) = try
    RGBAf(Makie.to_color(c))
catch
    RGBAf(0.5, 0.5, 0.5, 1)  # patterns, samplers: grey placeholder
end

"""
    Projector

Maps points in a plot's (transformed, f32-converted) space to figure
coordinates: Makie units, origin at the bottom-left of the root scene, y up.
"""
struct Projector
    M::Mat4d
    offset::Vec2d
end

function Projector(scene::Scene, space::Symbol, model = Mat4d(I))
    M = Mat4d(Makie.get_space_to_space_matrix(scene, space, :pixel)) * Mat4d(model)
    o = Makie.origin(Makie.viewport(scene)[])
    return Projector(M, Vec2d(o[1], o[2]))
end

function Projector(scene::Scene, plot::Plot; space = getattr(plot, :space, :data))
    model = getattr(plot, :model_f32c, getattr(plot, :model, Mat4d(I)))
    return Projector(scene, space, model)
end

function (P::Projector)(p::VecTypes)
    p4 = P.M * Vec4d(p[1], p[2], length(p) > 2 ? p[3] : 0.0, 1.0)
    return Point2d(p4[1] / p4[4] + P.offset[1], p4[2] / p4[4] + P.offset[2])
end

"Depth of a projected point (larger = further away), for painter's sorting."
function depth(P::Projector, p::VecTypes)
    p4 = P.M * Vec4d(p[1], p[2], length(p) > 2 ? p[3] : 0.0, 1.0)
    return p4[3] / p4[4]
end

project(P::Projector, ps::AbstractVector) = Point2d[P(p) for p in ps]

"Positions of a plot, transformed and f32-converted, ready for a Projector."
plot_positions(plot) = getattr(plot, :positions_transformed_f32c)

isfinitepoint(p) = all(isfinite, p)

# ---------------------------------------------------------------------------
# Clipping of polylines to a padded rectangle (Liang–Barsky)

"Rectangle (xmin, ymin, xmax, ymax) beyond which geometry is cut in Julia."
function clip_rect(ctx)
    w, h = ctx.size
    pad = ctx.opts.clip_padding
    return (-pad * w, -pad * h, (1 + pad) * w, (1 + pad) * h)
end

inrect(p, r) = r[1] <= p[1] <= r[3] && r[2] <= p[2] <= r[4]

"""
    clip_segment(a, b, r) -> (inside, a′, b′)

Liang–Barsky clipping of segment `a`–`b` to rectangle `r`.
"""
function clip_segment(a, b, r)
    t0, t1 = 0.0, 1.0
    dx, dy = b[1] - a[1], b[2] - a[2]
    for (p, q) in ((-dx, a[1] - r[1]), (dx, r[3] - a[1]), (-dy, a[2] - r[2]), (dy, r[4] - a[2]))
        if p == 0
            q < 0 && return (false, a, b)
        else
            t = q / p
            if p < 0
                t > t1 && return (false, a, b)
                t > t0 && (t0 = t)
            else
                t < t0 && return (false, a, b)
                t < t1 && (t1 = t)
            end
        end
    end
    return (true, Point2d(a[1] + t0 * dx, a[2] + t0 * dy), Point2d(a[1] + t1 * dx, a[2] + t1 * dy))
end

"""
    split_polyline(points, r) -> Vector{Vector{Point2d}}

Split a projected polyline at NaN points and clip it to rectangle `r`,
returning the visible runs (each with at least two points).
"""
function split_polyline(points::AbstractVector, r)
    runs = Vector{Point2d}[]
    current = Point2d[]
    flush!() = (length(current) >= 2 && push!(runs, current); current = Point2d[])
    for i in eachindex(points)
        p = points[i]
        if !isfinitepoint(p)
            flush!()
            continue
        end
        if i == firstindex(points) || !isfinitepoint(points[i - 1])
            # start of a run: only record if inside, otherwise wait for the
            # next segment to enter the rectangle
            inrect(p, r) && push!(current, p)
            continue
        end
        a = points[i - 1]
        if inrect(a, r) && inrect(p, r)
            isempty(current) && push!(current, a)
            push!(current, p)
        else
            ok, a2, b2 = clip_segment(a, p, r)
            if ok
                if isempty(current)
                    push!(current, a2)
                elseif current[end] != a2
                    # we re-entered: start a new run
                    flush!()
                    push!(current, a2)
                end
                push!(current, b2)
                inrect(p, r) || flush!()
            else
                flush!()
            end
        end
    end
    flush!()
    return runs
end

"""
    recipe_mapper(scene, plot) -> (f, P)

For recipe-level plots (Poly, Band) whose raw arguments we read directly:
`f` applies the transform function, model matrix and float32 conversion to
a raw point, and `P` projects the result to figure coordinates.
"""
function recipe_mapper(scene::Scene, plot::Plot)
    tf = Makie.transform_func(plot)
    space = getattr(plot, :space, :data)
    model = Mat4d(getattr(plot, :model, Mat4d(I)))
    f32c = scene.float32convert
    function f(p)
        q = Makie.apply_transform(tf, Point3d(p[1], p[2], length(p) > 2 ? p[3] : 0.0))
        q4 = model * Vec4d(q[1], q[2], q[3], 1.0)
        return Makie.f32_convert(f32c, Point3d(q4[1], q4[2], q4[3]) ./ q4[4], space)
    end
    return f, Projector(scene, space, Mat4d(I))
end
