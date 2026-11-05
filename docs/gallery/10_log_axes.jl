# Log axes
# Makie's superscript tick labels become math: `$10^{-4}$`.
ns = 2 .^ (1:12)
fig = Figure(size = (560, 380))
ax = Axis(fig[1, 1]; xscale = log2, yscale = log10, xlabel = L"N", ylabel = "error", title = "Convergence")
scatterlines!(ax, ns, 1 ./ ns; label = L"\mathcal{O}(N^{-1})")
scatterlines!(ax, ns, 1 ./ ns .^ 2; label = L"\mathcal{O}(N^{-2})", marker = :rect)
axislegend(ax; position = :lb)
fig
