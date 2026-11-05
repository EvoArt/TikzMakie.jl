module TikzMakieCairoMakieExt

# Rasterisation of plots marked `rasterize = true/n`, using CairoMakie to draw
# the plot into an image the size of its parent scene.

using TikzMakie, CairoMakie
using CairoMakie: Makie
using CairoMakie.Colors: RGBA, ARGB32, red, green, blue, alpha
using CairoMakie.Colors.FixedPointNumbers: N0f8

function TikzMakie.rasterize_plot(scene::Makie.Scene, plot::Makie.Plot, scale::Real)
    screen = CairoMakie.Screen(scene; px_per_unit = scale)
    CairoMakie.draw_plot(scene, screen, plot)
    data = screen.surface.data   # (width, height), premultiplied ARGB, top row first
    w, h = size(data)
    img = Matrix{RGBA{N0f8}}(undef, h, w)
    @inbounds for y in 1:h, x in 1:w
        c = data[x, y]
        a = Float64(alpha(c))
        img[y, x] = a > 0 ?
            RGBA{N0f8}(min(1, red(c) / a), min(1, green(c) / a), min(1, blue(c) / a), a) :
            RGBA{N0f8}(0, 0, 0, 0)
    end
    return img
end

end
