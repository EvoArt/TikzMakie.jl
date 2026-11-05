# Image and Heatmap: external PNG + \includegraphics, or rectangles for
# irregular grids.

"Convert a Makie colour matrix (x along dim 1, y up along dim 2) to PNG rows."
function to_png_matrix(colors::AbstractMatrix)
    nx, ny = size(colors)
    out = Matrix{RGBA{N0f8}}(undef, ny, nx)
    for j in 1:ny, i in 1:nx
        c = to_rgba(colors[i, j])
        out[ny - j + 1, i] = RGBA{N0f8}(clamp(c.r, 0, 1), clamp(c.g, 0, 1), clamp(c.b, 0, 1), clamp(c.alpha, 0, 1))
    end
    return out
end

"Nearest-neighbour upsampling so viewers cannot blur small images."
function upsample(img::Matrix, maxside::Int)
    m = maximum(size(img))
    m >= 512 && return img
    k = clamp(min(1024, maxside) ÷ m, 1, 64)
    return k == 1 ? img : repeat(img; inner = (k, k))
end

function add_image!(ctx, png::Matrix{RGBA{N0f8}})
    name = string(ctx.opts.image_basename, "-", length(ctx.images) + 1, ".png")
    push!(ctx.images, name => png)
    return ctx.opts.image_prefix * name
end

"""
Place `colors` (Makie orientation) in the figure-space box with corners
`p0` (x0, y0) and `p1` (x1, y1).
"""
function write_image_node(ctx, colors::AbstractMatrix, p0, p1; interpolate::Bool)
    colors = copy(colors)
    if p1[1] < p0[1]
        colors = reverse(colors; dims = 1)
        p0, p1 = Point2d(p1[1], p0[2]), Point2d(p0[1], p1[2])
    end
    if p1[2] < p0[2]
        colors = reverse(colors; dims = 2)
        p0, p1 = Point2d(p0[1], p1[2]), Point2d(p1[1], p0[2])
    end
    png = to_png_matrix(colors)
    interpolate || (png = upsample(png, ctx.opts.max_upsample))
    ref = add_image!(ctx, png)
    w, h = p1[1] - p0[1], p1[2] - p0[2]
    (w > 0 && h > 0) || return
    opts = "width=" * pt(ctx, w) * ", height=" * pt(ctx, h) * (interpolate ? ", interpolate=true" : "")
    println(ctx.io, "\\node[mknode, anchor=south west] at ", coord(ctx, p0), " {\\includegraphics[", opts, "]{", ref, "}};")
    return
end

function isregular(v::AbstractVector; rtol = 1.0e-3)
    length(v) <= 2 && return true
    d = diff(v)
    return all(x -> isapprox(x, d[1]; rtol, atol = 1.0e-6 * abs(v[end] - v[1])), d)
end

function draw_plot!(ctx, scene::Scene, plot::Image)
    img = getattr(plot, :image)
    prod(size(img)) == 0 && return
    colors = computed_color(plot)
    colors isa AbstractMatrix || return
    P = Projector(scene, plot)
    rect = plot_positions(plot)   # rect vertices: (x0,y0), (x1,y0), (x1,y1), (x0,y1)
    p0, p1 = P(rect[1]), P(rect[3])
    # rotation or 3D projection would need a different treatment
    if !(isapprox(P(rect[2])[2], p0[2]; atol = 0.01) && isapprox(P(rect[4])[1], p0[1]; atol = 0.01))
        warn_once(ctx, :image_rotated, "TikzMakie: rotated/projected images are drawn axis-aligned.")
    end
    write_image_node(ctx, colors, p0, p1; interpolate = getattr(plot, :interpolate, false) === true)
    return
end

function draw_plot!(ctx, scene::Scene, plot::Heatmap)
    img = getattr(plot, :image)
    prod(size(img)) == 0 && return
    hasattr(plot, :x_transformed_f32c) || Makie.add_computation!(plot.attributes, nothing, Val(:heatmap_transform))
    xs = getattr(plot, :x_transformed_f32c)
    ys = getattr(plot, :y_transformed_f32c)
    colors = computed_color(plot)
    colors isa AbstractMatrix || return
    P = Projector(scene, plot)
    pxs = [P(Point2d(x, ys[1]))[1] for x in xs]
    pys = [P(Point2d(xs[1], y))[2] for y in ys]
    interpolate = getattr(plot, :interpolate, false) === true
    if isregular(pxs) && isregular(pys)
        write_image_node(ctx, colors, Point2d(pxs[1], pys[1]), Point2d(pxs[end], pys[end]); interpolate)
    else
        nx, ny = size(colors)
        if nx * ny > 40_000
            warn_once(ctx, :big_irregular_heatmap, "TikzMakie: large irregular heatmap ($nx×$ny cells) written as rectangles; output will be big.")
        end
        r = clip_rect(ctx)
        for j in 1:ny, i in 1:nx
            fs = fill_style(ctx, colors[i, j])
            fs === nothing && continue
            a = Point2d(clamp(pxs[i], r[1], r[3]), clamp(pys[j], r[2], r[4]))
            b = Point2d(clamp(pxs[i + 1], r[1], r[3]), clamp(pys[j + 1], r[2], r[4]))
            # same-colour hairline hides seams between cells
            st = coloralpha(colors[i, j]) >= 0.999 ? fs * ", draw=" * colorname!(ctx, colors[i, j]) * ", line width=0.1pt" : fs
            println(ctx.io, "\\path[", st, "] ", coord(ctx, a), " rectangle ", coord(ctx, b), ";")
        end
    end
    return
end
