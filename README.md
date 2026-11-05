# TikzMakie.jl

[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://evoart.github.io/TikzMakie.jl/dev/)
[![CI](https://github.com/EvoArt/TikzMakie.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/EvoArt/TikzMakie.jl/actions/workflows/CI.yml)

Turn [Makie](https://docs.makie.org) figures into TikZ code for LaTeX
documents, with all text typeset by LaTeX: tick labels, axis labels,
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

With the default `fontsize = :native`, text nodes request exact sizes such as
`\fontsize{10.5}{12.6}`, so use a scalable font: `\usepackage{lmodern}`
(with `\usepackage[T1]{fontenc}`), `fix-cm`, or any OpenType font under
LuaLaTeX/XeLaTeX. Plain OT1 Computer Modern substitutes the nearest
size and warns.

Nothing about your plotting code changes. TikzMakie reads the finished
figure, so the output has the same layout as CairoMakie's PDF. The
[gallery](https://evoart.github.io/TikzMakie.jl/dev/gallery/) shows each
example compiled with pdfLaTeX next to CairoMakie's rendering.


## Matching the document

LaTeX typesets the text, but Makie's layout decided where it goes and how
much room it gets. For the best match, build the figure at its final size and
font size, and let Makie measure text with Computer Modern:

```julia
with_theme(latex_theme(fontsize = 10)) do      # 10pt text, Computer Modern metrics
    fig = Figure(size = size_pt(345, 200))     # 345pt = \textwidth of a 10pt article
    ...
    savetikz("fig.tex", fig)
end
```

- `size_pt(w, h)` converts TeX points to Makie units (1 unit = 0.75pt by
  default, as in CairoMakie's PDFs).
- `latex_theme(fontsize = 10)` sets Makie's font size so the text comes out at
  10pt, and switches Makie to Computer Modern so its layout measures text the
  way LaTeX will set it.
- The whole picture can be rescaled in LaTeX by editing `x=0.75pt, y=0.75pt`
  in the `tikzpicture` options. Line widths and text keep their absolute size.

See [examples/article.jl](examples/article.jl) and
[examples/article.tex](examples/article.tex) for a complete document.

## API

| | |
|---|---|
| `savetikz(path, fig; kwargs...)` | Write `path` (`.tex`) plus any images as `<name>-<n>.png` next to it. |
| `tikz(fig; kwargs...)` | Return a `TikzFigure`: `.code` (a `String`) and `.images`. |
| `savetikz(path, t::TikzFigure)` | Write a previously generated `TikzFigure`. |
| `latex_theme(; fontsize, pt_per_unit, latexfonts)` | Makie theme for figures destined for LaTeX. |
| `size_pt(w, h)` | Figure size in Makie units for `w`×`h` points. |
| `RawLaTeX(latex; preview)` | Text written verbatim as LaTeX; Makie draws and sizes `preview`. |
| `latextable(data; ...)` | A PrettyTables table as `RawLaTeX` (needs `using PrettyTables`). |

`fig` can be a `Figure`, the return value of e.g. `lines(...)`, or a `Scene`.

### Keyword options

| option | default | |
|---|---|---|
| `pt_per_unit` | `0.75` | TeX points per Makie unit. |
| `fontsize` | `:native` | `:native` sets each node's size from Makie (`\fontsize`); `:inherit` uses the surrounding document's size. |
| `numbers_as_math` | `true` | Numeric strings (tick labels) are set in math mode: `$-1.5$`, `$10^{-3}$`. |
| `unicode` | `true` | Replace −, °, ×, Greek letters, … with LaTeX commands (for pdfLaTeX). Use `false` with LuaLaTeX/XeLaTeX. |
| `textfilter` | `identity` | Function applied to each node's LaTeX string. |
| `background` | `false` | Draw the figure background (`false` = transparent; axis backgrounds are always drawn). |
| `standalone` | `false` | Wrap in a compilable `standalone` document. |
| `preamble` | `""` | Extra preamble lines for `standalone`, e.g. `"\\usepackage{booktabs}"`. |
| `image_prefix` | `""` | Prefix for `\includegraphics` paths, e.g. `"figures/"` if you `\input{figures/plot.tex}` from the parent directory (or use `\graphicspath`). |
| `displaystyle` | `false` | Prefix math with `\displaystyle`, so `\frac`/`\int` are full size, as Makie draws them. |
| `simplify` | `0.05` | Line simplification tolerance in Makie units (invisible; shrinks dense lines). `0` disables. |
| `rasterize_scale` | `4` | Pixels per unit for plots with `rasterize = true` (needs `using CairoMakie`). |
| `strut` | `true` | Give text nodes the font's full height/depth, matching Makie's alignment. |
| `digits` | `2` | Decimals for coordinates. |
| `color_prefix` | `"mkc"` | Prefix of the `\definecolor` names. |

## What is supported

Lines (dashes, caps, joins, per-point colours), line segments, scatter
(circles, rects, all Bézier markers, character markers), text (plain strings,
`LaTeXString`s, rich text with super/subscripts, rotation, alignment, bold and
italic), polys and bands (as clean vector paths), meshes and surfaces
(flat-shaded triangles, depth-sorted), heatmaps and images (embedded PNGs,
upsampled so viewers don't blur them), and everything built from these:
`Axis`, `Axis3`, `PolarAxis`, `Colorbar`, `Legend`, `Label`, `Box`, barplots,
histograms, contours, errorbars, boxplots, violins, pies, arrows, ….

Geometry far outside the figure is clipped in Julia, because TikZ cannot handle
huge coordinates.

### Rasterising heavy plots

Set Makie's own `rasterize` attribute on a plot to embed it as an image while
everything else (axes, labels, other plots) stays vector and LaTeX:

```julia
using CairoMakie, TikzMakie          # CairoMakie does the rasterising
scatter!(ax, huge_points; rasterize = true)   # rasterize_scale px per unit (default 4)
surface!(ax3, xs, ys, zs; rasterize = 6)      # or an explicit px per unit
```

This is also the way to get lit 3D surfaces; vector meshes are flat-shaded.

### Tables and raw LaTeX

`RawLaTeX(latex; preview)` is text that goes into the picture verbatim, while
Makie (layout, CairoMakie, …) sees only `preview`. It works anywhere Makie
takes text (`text!`, `Label`, titles). `latextable` builds one from any table
with PrettyTables.jl: the LaTeX backend's output for TikZ, the text backend's
as the preview, so Makie reserves roughly the right space:

```julia
using CairoMakie, TikzMakie, PrettyTables
tbl = latextable([1 0.12; 2 3.4]; column_labels = [LatexCell(L"n"), LatexCell(L"x")])
text!(ax, 0.98, 0.97; text = tbl, space = :relative, align = (:right, :top))  # inset
Label(fig[1, 2], tbl; tellheight = false)                                     # own cell
savetikz("fig.tex", fig)   # booktabs rules: needs \usepackage{booktabs}
```

## Limitations

- Text width: LaTeX typesets the text after Makie has laid out the figure.
  With `latex_theme()` the widths agree closely; with very different fonts,
  long labels may not fit the space Makie reserved for them.
- 3D surfaces and meshes are flat-shaded (no lighting), and intersecting
  triangles are not split. Use `rasterize` for those.
- Huge scatter plots produce large `.tex` files that are slow for LaTeX;
  rasterise them. (Lines are simplified automatically.)
- Pattern fills (`Makie.LinePattern`) become grey; character markers lose
  their outline.
- Requires Makie 0.24.

## How it works

TikzMakie walks the figure's scene tree the way CairoMakie does, but writes
TikZ instead of making Cairo calls: it collects the primitive plots, sorts them
by depth, clips each scene to its viewport, and projects positions through
Makie's own camera matrices. 
