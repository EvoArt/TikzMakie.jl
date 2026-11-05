# Layouts
# GridLayout positions, spanning labels, rotated tick labels and shared legends carry over unchanged.
using Random
Random.seed!(2)
fig = Figure(size = (650, 480))
Label(fig[0, 1:2], "Four panels"; fontsize = 20, font = :bold)
for (k, (i, j)) in enumerate(Iterators.product(1:2, 1:2))
    ax = Axis(fig[i, j]; title = "panel $k", xticklabelrotation = i == 2 ? π / 4 : 0.0)
    for s in 1:3
        lines!(ax, 1:20, cumsum(randn(20)); label = "series $s")
    end
    hlines!(ax, [0]; color = :gray, linestyle = :dot)
end
Legend(fig[1:2, 3], content(fig[1, 1]); framevisible = false)
fig
