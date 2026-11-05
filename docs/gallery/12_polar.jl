# Polar axis
θ = range(0, 2π, length = 400)
fig = Figure(size = (450, 450))
ax = PolarAxis(fig[1, 1]; title = "Rose curves")
for k in (2, 3, 5)
    lines!(ax, θ, abs.(cos.(k .* θ)); label = "k = $k")
end
fig
