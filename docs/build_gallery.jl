# Builds docs/src/gallery.md from the scripts in docs/gallery/.
#
# For each script: run it, write the TikZ (`<name>.tex`, what a user would
# \input), compile a standalone wrapper with pdfLaTeX, convert the PDF to SVG
# for the web page, and save a CairoMakie PNG of the same figure for
# comparison. Needs `pdflatex` and `pdftocairo` (poppler) on PATH; without them
# (allowed only outside CI) the TikZ column shows a note instead.

using CairoMakie, TikzMakie, LaTeXStrings

const GALLERY_DIR = joinpath(@__DIR__, "gallery")
const ASSET_DIR = joinpath(@__DIR__, "src", "assets", "gallery")

const WRAPPER = raw"""
\documentclass[tikz]{standalone}
\usepackage[T1]{fontenc}
\usepackage{lmodern}
\usepackage{amsmath}
\usepackage{graphicx}
\begin{document}
\input{%NAME%.tex}
\end{document}
"""

function run_script(path)
    m = Module(Symbol(splitext(basename(path))[1]))
    Core.eval(m, :(using CairoMakie, TikzMakie, LaTeXStrings))
    return Base.include(m, path)
end

"Title and description from the script's leading `#` comment lines."
function header(code)
    lines = split(code, '\n')
    comments = String[]
    for l in lines
        startswith(l, "#") || break
        push!(comments, strip(lstrip(l, '#')))
    end
    title = isempty(comments) ? "Example" : comments[1]
    desc = join(comments[2:end], " ")
    body = join(lines[(length(comments) + 1):end], '\n')
    return title, desc, strip(body)
end

function compile(name)
    pdflatex = Sys.which("pdflatex")
    pdftocairo = Sys.which("pdftocairo")
    if pdflatex === nothing || pdftocairo === nothing
        get(ENV, "CI", "") == "true" && error("pdflatex and pdftocairo are required to build the gallery on CI")
        @warn "pdflatex/pdftocairo not found; gallery will not show compiled TikZ"
        return false
    end
    write(joinpath(ASSET_DIR, "$name-standalone.tex"), replace(WRAPPER, "%NAME%" => name))
    cd(ASSET_DIR) do
        run(pipeline(`$pdflatex -interaction=nonstopmode -halt-on-error $name-standalone.tex`; stdout = devnull))
        run(`$pdftocairo -svg $name-standalone.pdf $name.svg`)
        for ext in (".aux", ".log")
            rm("$name-standalone$ext"; force = true)
        end
    end
    return true
end

function build_gallery()
    rm(ASSET_DIR; recursive = true, force = true)
    mkpath(ASSET_DIR)
    io = IOBuffer()
    println(io, """
    # Gallery

    Each figure below is the output of `savetikz` compiled with pdfLaTeX
    (left), next to CairoMakie's rendering of the same figure (right). Text
    in the TikZ version is typeset by LaTeX, here in Latin Modern. In your
    document it will use your fonts. Every example starts with
    `using CairoMakie, TikzMakie, LaTeXStrings` and ends with
    `savetikz("name.tex", fig)`; the `.tex` links are exactly what that writes.
    """)
    for file in sort(filter(endswith(".jl"), readdir(GALLERY_DIR)))
        name = splitext(file)[1]
        code = read(joinpath(GALLERY_DIR, file), String)
        title, desc, body = header(code)
        @info "gallery: $name"
        fig = run_script(joinpath(GALLERY_DIR, file))
        savetikz(joinpath(ASSET_DIR, "$name.tex"), fig)
        save(joinpath(ASSET_DIR, "$name-cairo.png"), fig; px_per_unit = 2)
        compiled = compile(name)
        tikz_cell = compiled ? "![TikZ output](assets/gallery/$name.svg)" : "*(pdfLaTeX not available)*"
        println(io, "## ", title, "\n")
        isempty(desc) || println(io, desc, "\n")
        println(io, "```julia\n", body, "\n```\n")
        println(io, "| TikzMakie → pdfLaTeX | CairoMakie |")
        println(io, "|:---:|:---:|")
        println(io, "| ", tikz_cell, " | ![CairoMakie output](assets/gallery/$name-cairo.png) |\n")
        links = ["[`$name.tex`](assets/gallery/$name.tex)"]
        compiled && push!(links, "[PDF](assets/gallery/$name-standalone.pdf)")
        println(io, "Download: ", join(links, " · "), "\n")
    end
    write(joinpath(@__DIR__, "src", "gallery.md"), take!(io))
    return
end
