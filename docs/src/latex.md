# Using it in LaTeX

## Preamble

```latex
\usepackage[T1]{fontenc}
\usepackage{lmodern}   % or any scalable font
\usepackage{tikz}
\usepackage{graphicx}  % only if figures contain heatmaps, images or rasterised plots
```

With the default `fontsize = :native`, text nodes request exact sizes such as
`\fontsize{10.5}{12.6}`, so use a scalable font: `lmodern`, `fix-cm`, or any
OpenType font under LuaLaTeX/XeLaTeX. Plain OT1 Computer Modern substitutes
the nearest size and warns. With LuaLaTeX/XeLaTeX and a Unicode font, pass
`unicode = false` to keep characters such as `−`, `°` and Greek letters as
they are.

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

- [`size_pt`](@ref) converts TeX points to Makie units (1 unit = 0.75pt by
  default, as in CairoMakie's PDFs).
- [`latex_theme`](@ref) sets Makie's font size so text comes out at the
  requested size, and switches Makie to Computer Modern so its layout
  measures text the way LaTeX will set it.
- The whole picture can be rescaled in LaTeX by editing `x=0.75pt, y=0.75pt`
  in the `tikzpicture` options. Line widths and text keep their absolute size.

To find your document's text width, put `\showthe\textwidth` in it and look
in the log.

## Images and file layout

Heatmaps, images and rasterised plots are written as PNGs next to the `.tex`
file (`plot.tex` → `plot-1.png`, …). `\includegraphics` resolves paths
relative to the *main* document, so if you `\input{figures/plot.tex}` either
pass `image_prefix = "figures/"` to `savetikz` or add
`\graphicspath{{figures/}}` to the preamble.

## Rasterising heavy plots

Set Makie's own `rasterize` attribute on a plot to embed it as an image while
everything else stays vector and LaTeX. This needs CairoMakie loaded:

```julia
using CairoMakie, TikzMakie
scatter!(ax, huge_points; rasterize = true)   # rasterize_scale px per unit (default 4)
surface!(ax3, xs, ys, zs; rasterize = 6)      # or an explicit px per unit
```

## Options

All keywords of [`tikz`](@ref)/[`savetikz`](@ref) are listed in
[`TikzOptions`](@ref). The most useful:

| option | default | |
|---|---|---|
| `pt_per_unit` | `0.75` | TeX points per Makie unit. |
| `fontsize` | `:native` | `:native` sets each node's size from Makie; `:inherit` uses the surrounding document's size. |
| `numbers_as_math` | `true` | Numeric strings (tick labels) are set in math mode: `$-1.5$`, `$10^{-3}$`. |
| `displaystyle` | `false` | Prefix math with `\displaystyle`, so `\frac`/`\int` are full size, as Makie draws them. |
| `unicode` | `true` | Replace −, °, ×, Greek letters, … with LaTeX commands (for pdfLaTeX). |
| `textfilter` | `identity` | Function applied to each node's LaTeX string. |
| `background` | `false` | Draw the figure background (`false` = transparent). |
| `standalone` | `false` | Wrap in a compilable `standalone` document. |
| `image_prefix` | `""` | Prefix for `\includegraphics` paths. |
| `simplify` | `0.05` | Line simplification tolerance in Makie units. `0` disables. |
| `rasterize_scale` | `4` | Pixels per unit for plots with `rasterize = true`. |
