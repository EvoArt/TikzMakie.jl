# Scatter markers
# Circles, rectangles and Makie's Bézier markers become TikZ paths; colormapped colours and sizes are kept.
fig = Figure(size = (600, 380))
ax = Axis(fig[1, 1]; title = "Marker shapes", yticks = (1:7, ["circle", "rect", "utriangle", "diamond", "cross", "star5", "hexagon"]))
for (i, m) in enumerate([:circle, :rect, :utriangle, :diamond, :cross, :star5, :hexagon])
    scatter!(ax, 1:6, fill(i, 6); marker = m, markersize = 16, strokewidth = 1, strokecolor = :black)
end
scatter!(ax, 1:6, fill(8, 6); color = 1:6, colormap = :plasma, markersize = 6:5:31)
ylims!(ax, 0.3, 8.9)
fig
