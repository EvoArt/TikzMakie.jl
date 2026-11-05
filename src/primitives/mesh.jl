# Meshes and surfaces: flat-coloured triangles, painter's-sorted by depth.

function face_color(colors, f)
    colors isa AbstractVector || return colors
    cs = (to_rgba(colors[f[1]]), to_rgba(colors[f[2]]), to_rgba(colors[f[3]]))
    return RGBA(
        sum(c -> c.r, cs) / 3, sum(c -> c.g, cs) / 3, sum(c -> c.b, cs) / 3, sum(c -> c.alpha, cs) / 3
    )
end

"""
    draw_triangles!(ctx, P, pts, faces, colors)

Project `pts` with `P` and fill each face, far faces first. `colors` is one
colour or one per vertex (averaged per face).
"""
function draw_triangles!(ctx, P::Projector, pts, faces, colors)
    (isempty(pts) || isempty(faces)) && return
    px = project(P, pts)
    if colors isa AbstractVector && length(colors) != length(pts)
        colors = first(colors)
    end
    order = collect(eachindex(faces))
    depths = [sum(depth(P, pts[j]) for j in faces[k]) for k in order]
    if !all(isapprox(first(depths)), depths)
        sort!(order; by = k -> -depths[k], alg = Base.Sort.DEFAULT_STABLE)
    end
    r = clip_rect(ctx)
    for k in order
        f = faces[k]
        tri = [px[f[1]], px[f[2]], px[f[3]]]
        all(isfinitepoint, tri) || continue
        tri = clip_polygon(tri, r)
        length(tri) >= 3 || continue
        c = face_color(colors, f)
        fs = fill_style(ctx, c)
        fs === nothing && continue
        # a hairline in the same colour hides the antialiasing seams between
        # adjacent triangles (only for opaque faces, where it is invisible)
        style = coloralpha(c) >= 0.999 ? fs * ", draw=" * colorname!(ctx, c) * ", line width=0.1pt, line join=round" : fs
        println(ctx.io, "\\path[", style, "] ", join((coord(ctx, q) for q in tri), " -- "), " -- cycle;")
    end
    return
end

function draw_plot!(ctx, scene::Scene, plot::Mesh)
    pts = plot_positions(plot)
    colors = computed_color(plot)
    if colors isa AbstractMatrix
        # texture-mapped mesh: sample the texture at each vertex's uv coordinate
        uv = getattr(plot, :texturecoordinates, nothing)
        if uv === nothing || length(uv) != length(pts)
            colors = colors[(end + 1) ÷ 2]
        else
            nx, ny = size(colors)
            colors = [colors[clamp(round(Int, u[1] * (nx - 1)) + 1, 1, nx), clamp(round(Int, (1 - u[2]) * (ny - 1)) + 1, 1, ny)] for u in uv]
        end
    end
    draw_triangles!(ctx, Projector(scene, plot), pts, getattr(plot, :faces), colors)
    return
end

function draw_plot!(ctx, scene::Scene, plot::Surface)
    if !hasattr(plot, :faces)
        Makie.add_computation!(plot.attributes, Val(:surface_as_mesh))
    end
    pts = vec(getattr(plot, :positions_transformed_f32c))
    colors = computed_color(plot)
    colors isa AbstractArray && (colors = vec(colors))
    draw_triangles!(ctx, Projector(scene, plot), pts, getattr(plot, :faces), colors)
    return
end
