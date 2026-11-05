# Heatmap and colorbar
# Regular heatmaps and images are embedded as PNGs (upsampled so viewers don't blur them).
xs = range(-3, 3, length = 40)
zs = [sin(x) * cos(y) + 0.3x for x in xs, y in xs]
fig = Figure(size = (560, 420))
ax = Axis(fig[1, 1]; xlabel = L"x", ylabel = L"y", title = L"z = \sin x \cos y + 0.3x", aspect = DataAspect())
hm = heatmap!(ax, xs, xs, zs; colormap = :balance)
Colorbar(fig[1, 2], hm; label = L"z")
fig
