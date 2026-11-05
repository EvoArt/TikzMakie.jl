# End-to-end example: a figure sized for an article's \textwidth, written
# with savetikz and \input into examples/article.tex.
#
#   julia --project=<env with Makie + TikzMakie> examples/article.jl [outdir]

using Makie, TikzMakie, LaTeXStrings

outdir = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "out")
mkpath(outdir)

fig = with_theme(latex_theme(fontsize = 10)) do
    # 345pt is \textwidth in the standard 10pt article class
    fig = Figure(size = size_pt(345, 200))
    ax = Axis(fig[1, 1]; xlabel = L"time $t$ (s)", ylabel = L"x(t)", title = "Damped oscillator")
    ts = range(0, 10, length = 300)
    for (γ, label) in ((0.1, L"\gamma = 0.1"), (0.3, L"\gamma = 0.3"), (1.0, L"\gamma = 1"))
        lines!(ax, ts, exp.(-γ .* ts) .* cos.(2ts); label)
    end
    axislegend(ax; position = :rt)
    ax2 = Axis(fig[1, 2]; title = "Phase portrait", xlabel = L"x", ylabel = L"\dot{x}", aspect = 1)
    x = exp.(-0.1 .* ts) .* cos.(2ts)
    v = -0.1 .* x .- 2 .* exp.(-0.1 .* ts) .* sin.(2ts)
    lines!(ax2, x, v; color = ts, colormap = :viridis)
    colsize!(fig.layout, 2, Auto(0.6))
    fig
end

savetikz(joinpath(outdir, "oscillator.tex"), fig)
println("wrote ", joinpath(outdir, "oscillator.tex"))
