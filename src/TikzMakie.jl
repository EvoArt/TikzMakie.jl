"""
    TikzMakie

Convert Makie figures to TikZ for LaTeX documents. Text becomes LaTeX
`\\node`s, so it is typeset in the document's fonts; everything else becomes
TikZ paths. Works on any existing figure; no backend switch needed.

```julia
using CairoMakie, TikzMakie
fig = lines(0..10, sin; axis = (; xlabel = L"t", ylabel = L"\\sin(t)"))
savetikz("sine.tex", fig)      # then \\input{sine.tex} in LaTeX
```

See [`tikz`](@ref), [`savetikz`](@ref), [`TikzOptions`](@ref),
[`latex_theme`](@ref), [`size_pt`](@ref), [`RawLaTeX`](@ref), [`latextable`](@ref).
"""
module TikzMakie

using Makie
using Makie: Scene, Plot, AbstractPlot, Lines, LineSegments, Scatter, Text, Poly, Band, Mesh,
    Image, Heatmap, Surface, BezierPath, MoveTo, LineTo, CurveTo, ClosePath, EllipticalArc,
    RGBAf, to_value, VecTypes
using GeometryBasics: GeometryBasics, Point2d, Point3d, Vec2d, Vec3d, Vec4d, Mat4d, Rect2, Circle, decompose
using Colors
using FixedPointNumbers: N0f8
using LinearAlgebra: I
using Printf: Printf
using LaTeXStrings: LaTeXString
using PNGFiles: PNGFiles

export tikz, savetikz, TikzFigure, TikzOptions, latex_theme, size_pt, RawLaTeX, latextable

include("rawlatex.jl")
include("format.jl")
include("context.jl")
include("project.jl")
include("walk.jl")
include("primitives/lines.jl")
include("primitives/scatter.jl")
include("primitives/text.jl")
include("primitives/poly.jl")
include("primitives/mesh.jl")
include("primitives/image.jl")

"""
    size_pt(width, height; pt_per_unit = 0.75)

Figure size in Makie units for a picture of `width`×`height` TeX points.
For an article's `\\textwidth` (345pt): `Figure(size = size_pt(345, 220))`.
"""
size_pt(width::Real, height::Real; pt_per_unit::Real = 0.75) = (width / pt_per_unit, height / pt_per_unit)

"""
    latex_theme(; fontsize = 10, pt_per_unit = 0.75, latexfonts = true)

A Makie theme for figures destined for LaTeX: text of `fontsize` points once
written with [`savetikz`](@ref) at `pt_per_unit`, and (with
`latexfonts = true`) Computer Modern fonts so that Makie's layout measures
text close to how LaTeX will typeset it.

```julia
with_theme(latex_theme(fontsize = 10)) do
    fig = Figure(size = size_pt(345, 220))
    ...
end
```
"""
function latex_theme(; fontsize::Real = 10, pt_per_unit::Real = 0.75, latexfonts::Bool = true)
    t = Theme(fontsize = fontsize / pt_per_unit)
    return latexfonts ? merge(t, Makie.theme_latexfonts()) : t
end

end
