# Meshes: flat-coloured triangles, painter's-sorted by depth.

function face_color(colors, f)
    colors isa AbstractVector || return colors
    cs = (to_rgba(colors[f[1]]), to_rgba(colors[f[2]]), to_rgba(colors[f[3]]))
    return RGBA(
        sum(c -> c.r, cs) / 3, sum(c -> c.g, cs) / 3, sum(c -> c.b, cs) / 3, sum(c -> c.alpha, cs) / 3
    )
end

function draw_plot!(ctx, scene::Scene, plot::Mesh)
    pts = plot_positions(plot)
    faces = getattr(plot, :faces)
    (isempty(pts) || isempty(faces)) && return
    P = Projector(scene, plot)
    px = project(P, pts)
    colors = computed_color(plot)
    if colors isa AbstractMatrix
        # texture-mapped mesh: sample per vertex via uv coordinates
        uv = getattr(plot, :texturecoordinates, nothing)
        if uv === nothing || length(uv) != length(pts)
            colors = colors[(end + 1) ÷ 2]
        else
            nx, ny = size(colors)
            colors = [colors[clamp(round(Int, u[1] * (nx - 1)) + 1, 1, nx), clamp(round(Int, (1 - u[2]) * (ny - 1)) + 1, 1, ny)] for u in uv]
        end
    end
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
        tri = (px[f[1]], px[f[2]], px[f[3]])
        all(isfinitepoint, tri) || continue
        all(q -> !inrect(q, r), tri) && continue
        c = face_color(colors, f)
        fs = fill_style(ctx, c)
        fs === nothing && continue
        # a hairline in the same colour hides the antialiasing seams between
        # adjacent triangles (only for opaque faces, where it is invisible)
        style = coloralpha(c) >= 0.999 ? fs * ", draw=" * colorname!(ctx, c) * ", line width=0.1pt, line join=round" : fs
        tri = map(q -> Point2d(clamp(q[1], r[1], r[3]), clamp(q[2], r[2], r[4])), tri)
        println(ctx.io, "\\path[", style, "] ", coord(ctx, tri[1]), " -- ", coord(ctx, tri[2]), " -- ", coord(ctx, tri[3]), " -- cycle;")
    end
    return
end

function draw_plot!(ctx, scene::Scene, plot::Surface)
    if !hasattr(plot, :faces)
        Makie.add_computation!(plot.attributes, Val(:surface_as_mesh))
    end
    pts = getattr(plot, :positions_transformed_f32c)
    faces = getattr(plot, :faces)
    P = Projector(scene, plot)
    px = project(P, vec(pts))
    colors = computed_color(plot)
    colors isa AbstractArray && (colors = vec(colors))
    order = collect(eachindex(faces))
    depths = [sum(depth(P, pts[j]) for j in faces[k]) for k in order]
    sort!(order; by = k -> -depths[k], alg = Base.Sort.DEFAULT_STABLE)
    r = clip_rect(ctx)
    for k in order
        f = faces[k]
        tri = (px[f[1]], px[f[2]], px[f[3]])
        all(isfinitepoint, tri) || continue
        c = colors isa AbstractVector && length(colors) == length(px) ? face_color(colors, f) : (colors isa AbstractVector ? first(colors) : colors)
        fs = fill_style(ctx, c)
        fs === nothing && continue
        style = coloralpha(c) >= 0.999 ? fs * ", draw=" * colorname!(ctx, c) * ", line width=0.1pt, line join=round" : fs
        tri = map(q -> Point2d(clamp(q[1], r[1], r[3]), clamp(q[2], r[2], r[4])), tri)
        println(ctx.io, "\\path[", style, "] ", coord(ctx, tri[1]), " -- ", coord(ctx, tri[2]), " -- ", coord(ctx, tri[3]), " -- cycle;")
    end
    return
end
