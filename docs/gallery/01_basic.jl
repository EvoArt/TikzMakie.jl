# Basic line plot
# Tick labels, axis labels, legend and title are all LaTeX text nodes; `L"..."` strings become real LaTeX math.
xs = range(0, 4π, length = 200)
fig = Figure(size = (600, 350))
ax = Axis(fig[1, 1]; xlabel = L"t", ylabel = L"f(t)", title = "Two signals")
lines!(ax, xs, sin.(xs); label = L"\sin t")
lines!(ax, xs, cos.(xs) .* exp.(-xs ./ 8); label = L"e^{-t/8}\cos t", linestyle = :dash, linewidth = 2)
axislegend(ax; position = :rt)
fig
