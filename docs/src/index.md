# TikzMakie.jl

Turn [Makie](https://docs.makie.org) figures into TikZ code for LaTeX
documents, with **all text typeset by LaTeX**: tick labels, axis labels,
legends and titles appear in your document's font, and `L"..."` strings become
real LaTeX math.

```julia
using CairoMakie, TikzMakie   # any Makie backend, or none at all

fig = lines(0..10, sin; axis = (; xlabel = L"t", ylabel = L"\sin(t)"))
savetikz("sine.tex", fig)
```

```latex
\usepackage{tikz}       % plus graphicx if the figure contains images/heatmaps
...
\begin{figure}
  \centering
  \input{sine.tex}
\end{figure}
```

Nothing about your plotting code changes. TikzMakie reads the finished
figure, so the output has the same layout as CairoMakie's PDF. See the
[Gallery](@ref) for side-by-side comparisons.

## Installation

```julia
using Pkg
Pkg.add(url = "https://github.com/EvoArt/TikzMakie.jl")
```

Requires Makie 0.24 and Julia ≥ 1.10.
