# Text, math and escaping
# LaTeXStrings pass through unchanged, rich text maps to super/subscripts, and plain strings are escaped.
fig = Figure(size = (600, 380))
ax = Axis(fig[1, 1]; xlabel = L"\alpha \in [0, 2\pi]", ylabel = L"\frac{\sin \alpha}{\alpha}", title = L"\mathrm{sinc}(\alpha) = \frac{\sin \alpha}{\alpha}")
xs = range(0.01, 2π, length = 200)
lines!(ax, xs, sin.(xs) ./ xs)
text!(ax, 3.2, 0.7; text = "plain text: 50% & #1_x {braces} ~ ^", align = (:center, :center))
text!(ax, 1.0, -0.05; text = rich("rich: x", superscript("2"), " + y", subscript("i")), rotation = π / 8)
text!(ax, 4.5, 0.25; text = L"\int_0^\infty e^{-x^2}\,dx = \frac{\sqrt{\pi}}{2}", align = (:center, :center))
fig
