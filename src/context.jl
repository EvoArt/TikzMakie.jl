"""
Options controlling TikZ output. Every field can be passed as a keyword to
[`tikz`](@ref) and [`savetikz`](@ref).

- `pt_per_unit = 0.75`: size of one Makie unit in TeX points. 0.75 matches
  CairoMakie's PDF output, so a 600×450 figure becomes 450pt×337.5pt.
- `digits = 2`: decimals written for coordinates (in Makie units).
- `fontsize = :native`: `:native` sets each text node's size from Makie
  (`\\fontsize`), so the text fills the space Makie's layout reserved;
  `:inherit` leaves the document's font size alone.
- `numbers_as_math = true`: typeset purely numeric strings (tick labels) in
  math mode, `\$-1.5\$`.
- `unicode = true`: replace common Unicode symbols (−, °, Greek, …) with LaTeX
  commands for pdfLaTeX. Set `false` for LuaLaTeX/XeLaTeX with a Unicode font.
- `textfilter = identity`: function applied to the final LaTeX string of every
  text node, for custom substitutions.
- `background = false`: draw the figure's background colour. `false` leaves the
  picture transparent (axis backgrounds are still drawn).
- `standalone = false`: wrap the picture in a compilable `standalone` document.
- `image_prefix = ""`: prepended to image file names in `\\includegraphics`,
  e.g. `"figures/"` when the `.tex` is `\\input` from a parent directory.
- `image_basename = "tikzmakie"`: stem of image file names (set automatically
  by `savetikz`).
- `max_upsample = 2048`: non-interpolated images (heatmaps) are upsampled with
  nearest-neighbour to at most this many pixels per side, so PDF viewers
  cannot blur them.
- `color_prefix = "mkc"`: prefix for `\\definecolor` names.
- `clip_padding = 0.25`: geometry further than this fraction of the figure
  size outside the figure is cut in Julia (TikZ cannot handle huge
  coordinates).
- `simplify = 0.05`: lines are simplified (Ramer–Douglas–Peucker) with this
  tolerance in Makie units (0.05 units ≈ 0.04pt, far below visibility).
  Dense lines shrink a lot. `0` disables.
- `rasterize_scale = 4`: pixels per Makie unit for plots with
  `rasterize = true` (≈ 380 dpi at the default `pt_per_unit`). An integer
  `rasterize = n ≥ 2` on the plot uses `n` instead (Makie stores `true` as 1).
  Needs CairoMakie loaded.
- `strut = true`: give every text node at least the height and depth of a
  parenthesis, as Makie aligns text by font ascender/descender rather than
  by the glyphs' ink. Keeps e.g. an `x` axis label at the same distance from
  the tick labels as in Makie.
"""
Base.@kwdef struct TikzOptions
    pt_per_unit::Float64 = 0.75
    digits::Int = 2
    fontsize::Symbol = :native
    numbers_as_math::Bool = true
    unicode::Bool = true
    textfilter::Any = identity
    background::Bool = false
    standalone::Bool = false
    image_prefix::String = ""
    image_basename::String = "tikzmakie"
    max_upsample::Int = 2048
    color_prefix::String = "mkc"
    clip_padding::Float64 = 0.25
    simplify::Float64 = 0.05
    rasterize_scale::Float64 = 4.0
    strut::Bool = true
end

mutable struct TikzContext
    opts::TikzOptions
    io::IOBuffer
    colors::Dict{NTuple{3, Int}, String}
    color_defs::Vector{String}
    images::Vector{Pair{String, Matrix{RGBA{N0f8}}}}
    size::Vec2d
    warned::Set{Any}
end

TikzContext(opts::TikzOptions, size) = TikzContext(
    opts, IOBuffer(), Dict{NTuple{3, Int}, String}(), String[],
    Pair{String, Matrix{RGBA{N0f8}}}[], Vec2d(size), Set{Any}()
)

function warn_once(ctx, key, msg)
    key in ctx.warned && return
    push!(ctx.warned, key)
    @warn msg
    return
end

"""
    TikzFigure

Result of [`tikz`](@ref): the TikZ code (`String(t)` or `t.code`) plus any
raster images (`t.images`, `filename => pixels`) that the code references.
Save both with [`savetikz`](@ref).
"""
struct TikzFigure
    code::String
    images::Vector{Pair{String, Matrix{RGBA{N0f8}}}}
end

Base.String(t::TikzFigure) = t.code
Base.string(t::TikzFigure) = t.code
Base.print(io::IO, t::TikzFigure) = print(io, t.code)
Base.show(io::IO, ::MIME"text/plain", t::TikzFigure) = print(io, t.code)
function Base.show(io::IO, t::TikzFigure)
    n = count(==('\n'), t.code)
    return print(io, "TikzFigure(", n, " lines, ", length(t.images), " images)")
end
