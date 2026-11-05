"""
    RawLaTeX(latex; preview = latex)

Text that TikzMakie writes into the picture verbatim, as LaTeX source, while
Makie (its layout, CairoMakie, GLMakie, …) sees only `preview`. Use it for
LaTeX that Makie cannot draw itself, such as a `tabular`:

```julia
tbl = raw"\\begin{tabular}{rr} \\toprule a & b \\\\ \\midrule 1 & 2 \\\\ \\bottomrule \\end{tabular}"
text!(ax, 0.95, 0.95; text = RawLaTeX(tbl; preview = "a  b\\n1  2"),
      space = :relative, align = (:right, :top))
Label(fig[1, 2], RawLaTeX(tbl; preview = "a  b\\n1  2"))
```

`RawLaTeX` is an `AbstractString` that behaves like `preview`, so it works
anywhere Makie takes text. Makie reserves space for the preview, so make the
preview roughly the size of the typeset result. The node keeps its font size,
colour, alignment and rotation; the LaTeX is not escaped and its line breaks
are not treated as line breaks.

[`latextable`](@ref) builds one from a table with PrettyTables.jl.
"""
struct RawLaTeX <: AbstractString
    latex::String
    preview::String
end

RawLaTeX(latex::AbstractString; preview::AbstractString = latex) = RawLaTeX(String(latex), String(preview))

# the AbstractString interface, forwarded to the preview
Base.ncodeunits(s::RawLaTeX) = ncodeunits(s.preview)
Base.codeunit(::RawLaTeX) = UInt8
Base.codeunit(s::RawLaTeX, i::Integer) = codeunit(s.preview, i)
Base.isvalid(s::RawLaTeX, i::Integer) = isvalid(s.preview, i)
Base.iterate(s::RawLaTeX, i::Integer = 1) = iterate(s.preview, i)

function Base.show(io::IO, s::RawLaTeX)
    print(io, "RawLaTeX(", repr(s.latex))
    s.preview == s.latex || print(io, "; preview = ", repr(s.preview))
    return print(io, ")")
end
Base.show(io::IO, ::MIME"text/plain", s::RawLaTeX) = show(io, s)

"""
    latextable(data; booktabs = true, background = nothing, latex = (;), text = (;), kwargs...) -> RawLaTeX

A table for a Makie figure, typeset by LaTeX in TikzMakie's output. Needs
PrettyTables.jl loaded (`using PrettyTables`). `data` is anything
`pretty_table` accepts (a matrix, a vector, a Tables.jl table).

The LaTeX comes from `pretty_table(String, data; backend = :latex, ...)`, and
the [`RawLaTeX`](@ref) preview, which Makie draws and sizes, from the
`:text` backend. Keywords:

- `kwargs...`: passed to both backends (`column_labels`, `formatters`,
  `alignment`, …). `LatexCell`s are shown in the preview without `\$`, `{}`
  and backslashes.
- `latex`, `text`: named tuples of keywords for one backend only.
- `booktabs = true`: `\\toprule`/`\\midrule`/`\\bottomrule` (needs
  `\\usepackage{booktabs}`) unless `latex` sets `table_format`.
- `background`: an xcolor name such as `"white"`, to set the table on an
  opaque `\\colorbox` (useful for insets over data).

```julia
using CairoMakie, TikzMakie, PrettyTables
tbl = latextable([1 0.12; 2 3.4]; column_labels = [LatexCell(L"n"), LatexCell(L"x")])
text!(ax, 0.98, 0.97; text = tbl, space = :relative, align = (:right, :top))
Label(fig[1, 2], tbl; tellheight = false)
savetikz("fig.tex", fig; standalone = true, preamble = "\\\\usepackage{booktabs}")
```

The preview uses the text's font, so its columns only line up in a monospace
font (`font = "DejaVu Sans Mono"` if installed); the size Makie reserves is
approximate either way.
"""
function latextable end

function __init__()
    Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
        if exc.f === latextable
            print(io, "\n`latextable` needs PrettyTables.jl: run `using PrettyTables` first.")
        end
    end
    return
end
