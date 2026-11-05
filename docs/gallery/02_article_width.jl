# Sized for a document
# `size_pt` and `latex_theme` make the picture exactly `\textwidth` wide with 10pt Computer Modern text.
with_theme(latex_theme(fontsize = 10)) do
    fig = Figure(size = size_pt(345, 200))   # 345pt = \textwidth of a 10pt article
    ax = Axis(fig[1, 1]; xlabel = L"time $t$ (s)", ylabel = L"x(t)", title = "Damped oscillator")
    ts = range(0, 10, length = 300)
    for γ in (0.1, 0.3, 1.0)
        lines!(ax, ts, exp.(-γ .* ts) .* cos.(2ts); label = L"\gamma = %$γ")
    end
    axislegend(ax; position = :rt)
    ax2 = Axis(fig[1, 2]; title = "Phase portrait", xlabel = L"x", ylabel = L"\dot{x}", aspect = 1)
    x = exp.(-0.1 .* ts) .* cos.(2ts)
    v = -0.1 .* x .- 2 .* exp.(-0.1 .* ts) .* sin.(2ts)
    lines!(ax2, x, v; color = ts, colormap = :viridis)
    colsize!(fig.layout, 2, Auto(0.6))
    fig
end
