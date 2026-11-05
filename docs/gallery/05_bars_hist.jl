# Bars and histograms
# Polygons are written as single vector paths, not triangle meshes, so there are no hairline seams.
using Random
Random.seed!(1)
fig = Figure(size = (650, 300))
ax1 = Axis(fig[1, 1]; title = "barplot", xticks = (1:4, ["north", "east", "south", "west"]))
barplot!(ax1, 1:4, [3.2, 1.4, 4.1, 2.6]; color = [:steelblue, :orange, :seagreen, :crimson], bar_labels = :y, strokewidth = 1)
ylims!(ax1, 0, 5)
ax2 = Axis(fig[1, 2]; title = "hist")
hist!(ax2, randn(2000); bins = 30, strokewidth = 0.5, strokecolor = :white)
fig
