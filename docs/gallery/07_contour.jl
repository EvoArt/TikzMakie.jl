# Filled contours
xs = range(-2, 2, length = 80)
f(x, y) = exp(-(x^2 + y^2)) + 0.6exp(-((x - 1)^2 + (y - 1)^2) / 0.3)
zs = [f(x, y) for x in xs, y in xs]
fig = Figure(size = (560, 440))
ax = Axis(fig[1, 1]; title = "contourf + contour", aspect = DataAspect())
cf = contourf!(ax, xs, xs, zs; levels = 10)
contour!(ax, xs, xs, zs; levels = 10, color = :black, linewidth = 0.5)
Colorbar(fig[1, 2], cf)
fig
