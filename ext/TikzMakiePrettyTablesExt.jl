module TikzMakiePrettyTablesExt

# `latextable`: a PrettyTables table as RawLaTeX, with the LaTeX backend's
# output for TikZ and the text backend's output as Makie's preview.

using TikzMakie
using TikzMakie: RawLaTeX
using PrettyTables

"LaTeX source shown as plain text: no `\$`, braces or backslashes."
plain_latex(s) = replace(String(s), r"[${}]" => "", r"\\(?=[A-Za-z])" => "", "\\" => "")

"Replace `LatexCell`s (in labels or a data array) by their plain-text form."
plain_cells(x::PrettyTables.LatexCell) = plain_latex(string(x.data))
plain_cells(x::AbstractArray) = map(plain_cells, x)
plain_cells(x) = x

function TikzMakie.latextable(
        data; booktabs::Bool = true, background = nothing,
        latex::NamedTuple = (;), text::NamedTuple = (;), kwargs...
    )
    lkw = booktabs && !haskey(latex, :table_format) ?
        merge((; table_format = PrettyTables.latex_table_format__booktabs), latex) : latex
    src = pretty_table(String, data; backend = :latex, merge(NamedTuple(kwargs), lkw)...)
    src = String(rstrip(src))
    background === nothing || (src = "\\colorbox{" * string(background) * "}{" * src * "}")

    tkw = haskey(text, :table_format) ? text :
        merge((; table_format = TextTableFormat(borders = text_table_borders__compact)), text)
    pkw = map(plain_cells, NamedTuple(kwargs))
    preview = pretty_table(String, plain_cells(data); backend = :text, merge(pkw, tkw)...)
    preview = strip(preview, '\n')
    return RawLaTeX(src; preview = preview)
end

end
