# A broad sweep of Makie plot types and blocks. The tests only require that
# conversion succeeds without warnings and the output is well-formed.

using Makie

function stress_recipes()
    fig = Figure(size = (800, 600))
    ax = Axis(fig[1, 1]; title = "stairs/stem/hspan")
    stairs!(ax, 1:10, rand(10))
    stem!(ax, 1:10, rand(10) .- 0.5)
    hspan!(ax, 0.2, 0.3; color = (:gray, 0.2))
    vlines!(ax, [5]; color = :red)
    ablines!(ax, 0, 0.1)
    ax = Axis(fig[1, 2]; title = "boxplot/violin")
    cats = rand(1:3, 200)
    boxplot!(ax, cats, randn(200))
    violin!(ax, cats .+ 3, randn(200))
    ax = Axis(fig[2, 1]; title = "density/rangebars")
    density!(ax, randn(300))
    rangebars!(ax, [0.1, 0.2], [-1, -2], [1, 2]; direction = :x)
    ax = Axis(fig[2, 2]; title = "arrows/pie", aspect = DataAspect())
    arrows2d!(ax, [Point2f(0, 0)], [Vec2f(1, 1)])
    pie!(ax, [1, 2, 3]; offset = 0.0, radius = 0.5, color = [:red, :green, :blue])
    return fig
end

function stress_blocks()
    fig = Figure(size = (700, 500))
    ax = Axis(fig[1, 1]; xlabel = "x", ylabel = "y")
    for i in 1:3
        scatterlines!(ax, 1:5, rand(5) .+ i; label = "series $i", marker = [:circle, :rect, :utriangle][i])
    end
    Legend(fig[1, 2], ax, "Legend title")
    Colorbar(fig[2, 1]; colormap = :plasma, limits = (0, 1), vertical = false, label = "horizontal colorbar")
    Label(fig[2, 2], "rotated label"; rotation = pi / 2)
    Box(fig[3, 1:2]; color = (:orange, 0.2), cornerradius = 8)
    return fig
end

function stress_axis3()
    fig = Figure(size = (500, 450))
    ax = Axis3(fig[1, 1]; title = "Axis3 surface")
    xs = range(-1, 1, length = 12)
    surface!(ax, xs, xs, [x^2 - y^2 for x in xs, y in xs])
    scatter!(ax, rand(Point3f, 10))
    return fig
end

function stress_polar()
    fig = Figure(size = (450, 450))
    ax = PolarAxis(fig[1, 1]; title = "polar")
    lines!(ax, range(0, 2pi, length = 100), 1 .+ 0.3 .* sin.(5 .* range(0, 2pi, length = 100)))
    return fig
end

function stress_images()
    fig = Figure(size = (600, 300))
    image(fig[1, 1], rand(RGBf, 20, 10); axis = (; aspect = DataAspect()))
    ax = Axis(fig[1, 2]; xscale = log10)
    heatmap!(ax, [1, 2, 5, 10, 20], 1:4, rand(4, 4))   # irregular after log transform
    return fig
end

function stress_text()
    fig = Figure(size = (500, 400))
    ax = Axis(fig[1, 1]; title = L"\int_0^\infty e^{-x^2}\,dx", xlabel = "multi\nline label")
    text!(ax, [(1, 1), (2, 2), (3, 3)]; text = ["a", "b", "c"], color = [:red, :green, :blue], fontsize = [10, 15, 20])
    text!(ax, 2, 1; text = "data-space text", markerspace = :data, fontsize = 0.3)
    text!(ax, 0.5, 0.5; text = "relative", space = :relative, align = (:right, :top))
    annotation!(ax, 1, 3, 2, 2.5; text = "annotation")
    textlabel!(ax, 3, 1; text = "textlabel")
    limits!(ax, 0, 4, 0, 4)
    return fig
end

function stress_outside()
    # data far outside the limits must be clipped, never written as huge coordinates
    fig = Figure()
    ax = Axis(fig[1, 1])
    lines!(ax, [-1.0e9, 0, 1, 1.0e9], [0, 1, 0, 1.0e12])
    scatter!(ax, [1.0e10], [1.0e10])
    poly!(ax, Point2f[(0, 0), (1.0e8, 0), (0, 1)])
    band!(ax, [-1.0e9, 1.0e9], [0, 0], [1, 1])
    limits!(ax, 0, 1, 0, 1)
    return fig
end

function stress_categorical()
    fig = Figure()
    ax = Axis(fig[1, 1]; xticks = (1:3, ["low", "mid", "high"]), yticks = [0, 0.5, 1])
    barplot!(ax, 1:3, [0.2, 0.9, 0.5]; color = [:red, :green, :blue], bar_labels = :y)
    hidespines!(ax, :t, :r)
    return fig
end

const STRESS = Pair{String, Function}[
    "recipes" => stress_recipes,
    "blocks" => stress_blocks,
    "axis3" => stress_axis3,
    "polar" => stress_polar,
    "images" => stress_images,
    "text" => stress_text,
    "outside" => stress_outside,
    "categorical" => stress_categorical,
]
