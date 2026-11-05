# 3D and rasterisation
# Vector 3D meshes are flat-shaded; set Makie's `rasterize` attribute to embed a lit surface as an image while axes and labels stay vector + LaTeX.
xs = range(-1, 1, length = 40)
zs = [x^2 - y^2 for x in xs, y in xs]
fig = Figure(size = (700, 330))
ax1 = Axis3(fig[1, 1]; title = "vector (flat-shaded)", xlabel = L"x", ylabel = L"y", zlabel = L"z")
surface!(ax1, xs[1:3:end], xs[1:3:end], zs[1:3:end, 1:3:end])
ax2 = Axis3(fig[1, 2]; title = "rasterize = true", xlabel = L"x", ylabel = L"y", zlabel = L"z")
surface!(ax2, xs, xs, zs; rasterize = true)
fig
