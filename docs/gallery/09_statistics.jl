# Statistical plots
using Random
Random.seed!(3)
fig = Figure(size = (650, 450))
ax1 = Axis(fig[1, 1]; title = "boxplot + violin", xticks = (1:3, ["A", "B", "C"]))
cats = rand(1:3, 300)
vals = randn(300) .+ 0.5cats
violin!(ax1, cats, vals; color = (:steelblue, 0.4))
boxplot!(ax1, cats, vals; width = 0.3, color = :white, strokewidth = 1, whiskerwidth = 0.3)
ax2 = Axis(fig[1, 2]; title = "errorbars + band")
xs = 1:10
ys = sqrt.(xs)
band!(ax2, xs, ys .- 0.4, ys .+ 0.4; color = (:orange, 0.3))
errorbars!(ax2, xs, ys, 0.2 .* ys; whiskerwidth = 6)
scatter!(ax2, xs, ys; color = :black)
ax3 = Axis(fig[2, 1:2]; title = "density + stairs + stem")
density!(ax3, randn(500); color = (:seagreen, 0.4), strokewidth = 1, strokecolor = :seagreen)
stairs!(ax3, -3:0.5:3, rand(13) .* 0.4; color = :crimson)
stem!(ax3, -3:0.5:3, rand(13) .* -0.2)
fig
