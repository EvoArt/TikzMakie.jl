# Representative figures used by the tests and the gallery.
# Each entry: name => zero-argument function returning a figure.

using Makie, LaTeXStrings

function fig_lines()
    fig = Figure(size = (500, 350))
    ax = Axis(fig[1, 1]; xlabel = "time (s)", ylabel = "amplitude", title = "Lines")
    xs = range(0, 10, length = 200)
    lines!(ax, xs, sin.(xs); label = "sin")
    lines!(ax, xs, cos.(xs); label = "cos", linestyle = :dash, linewidth = 3)
    axislegend(ax)
    fig
end

function fig_scatter()
    fig = Figure(size = (500, 350))
    ax = Axis(fig[1, 1]; title = "Scatter markers")
    for (i, m) in enumerate([:circle, :rect, :utriangle, :diamond, :cross, :star5, 'A'])
        scatter!(ax, 1:5, fill(i, 5); marker = m, markersize = 14, strokewidth = 1, strokecolor = :black)
    end
    scatter!(ax, 1:5, fill(8, 5); color = 1:5, colormap = :viridis, markersize = 5:5:25)
    fig
end

function fig_latex()
    fig = Figure(size = (500, 350))
    ax = Axis(fig[1, 1]; xlabel = L"\alpha \in [0, 2\pi]", ylabel = L"\frac{\sin(\alpha)}{\alpha}", title = L"f(\alpha) = \mathrm{sinc}\,\alpha")
    xs = range(0.01, 2pi, length = 100)
    lines!(ax, xs, sin.(xs) ./ xs)
    text!(ax, 3, 0.6; text = "50% & #1_x {test} ~ ^", align = (:center, :center))
    text!(ax, 1, -0.1; text = rich("x", superscript("2"), " + y", subscript("i")), rotation = pi / 6)
    fig
end

function fig_bars_band()
    fig = Figure(size = (600, 300))
    ax1 = Axis(fig[1, 1]; title = "barplot")
    barplot!(ax1, 1:5, [3, 1, 4, 1, 5]; color = 1:5, strokewidth = 1)
    ax2 = Axis(fig[1, 2]; title = "band")
    xs = 0:0.1:5
    band!(ax2, xs, sin.(xs) .- 0.3, sin.(xs) .+ 0.3; color = (:blue, 0.3))
    lines!(ax2, xs, sin.(xs); color = :blue)
    poly!(ax2, Point2f[(1, -1), (2, -1.2), (1.5, -0.6)]; color = :red, strokecolor = :black, strokewidth = 1)
    fig
end

function fig_heatmap()
    fig = Figure(size = (500, 400))
    ax = Axis(fig[1, 1]; title = "heatmap + colorbar")
    hm = heatmap!(ax, 1:20, 1:15, [sin(i / 3) * cos(j / 4) for i in 1:20, j in 1:15])
    Colorbar(fig[1, 2], hm; label = "value")
    fig
end

function fig_logaxis()
    fig = Figure(size = (500, 350))
    ax = Axis(fig[1, 1]; yscale = log10, xlabel = "n", ylabel = "error", title = "log scale")
    ns = 1:20
    scatterlines!(ax, ns, 10.0 .^ (-ns ./ 3))
    fig
end

function fig_contour()
    fig = Figure(size = (500, 400))
    ax = Axis(fig[1, 1]; title = "contourf")
    xs = range(-2, 2, length = 40)
    cf = contourf!(ax, xs, xs, [exp(-(x^2 + y^2)) for x in xs, y in xs])
    contour!(ax, xs, xs, [exp(-(x^2 + y^2)) for x in xs, y in xs]; color = :black)
    Colorbar(fig[1, 2], cf)
    fig
end

function fig_layout()
    fig = Figure(size = (600, 450))
    for i in 1:2, j in 1:2
        ax = Axis(fig[i, j]; title = "panel $(i)$(j)", xticklabelrotation = (i == 2 ? pi / 4 : 0.0))
        lines!(ax, 1:10, rand(10) .+ i .* j)
        hlines!(ax, [2]; color = :gray, linestyle = :dot)
    end
    Label(fig[0, :], "A figure title spanning the grid"; fontsize = 20, font = :bold)
    fig
end

function fig_errorbars()
    fig = Figure(size = (500, 350))
    ax = Axis(fig[1, 1]; title = "errorbars + hist")
    xs = 1:8
    ys = sqrt.(xs)
    errorbars!(ax, xs, ys, 0.2 .* ys; whiskerwidth = 8)
    scatter!(ax, xs, ys; color = :red)
    ax2 = Axis(fig[1, 2])
    hist!(ax2, randn(500); bins = 20, strokewidth = 0.5, strokecolor = :white)
    fig
end

const FIGURES = Pair{String, Function}[
    "lines" => fig_lines,
    "scatter" => fig_scatter,
    "latex" => fig_latex,
    "bars_band" => fig_bars_band,
    "heatmap" => fig_heatmap,
    "logaxis" => fig_logaxis,
    "contour" => fig_contour,
    "layout" => fig_layout,
    "errorbars" => fig_errorbars,
]
