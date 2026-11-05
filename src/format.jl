# Number formatting, colours, LaTeX escaping, anchors.

const _FMT_CACHE = Dict{Int, Printf.Format}()

"""
    fmt(x, digits = 3)

Format a number for TikZ: fixed point with `digits` decimals, trailing zeros
trimmed, never scientific notation, `-0` normalised to `0`.
"""
function fmt(x::Real, digits::Int = 3)
    isfinite(x) || throw(ArgumentError("TikzMakie: refusing to write non-finite number $x"))
    f = get!(() -> Printf.Format("%.$(digits)f"), _FMT_CACHE, digits)
    s = Printf.format(f, Float64(x))
    if occursin('.', s)
        s = rstrip(rstrip(s, '0'), '.')
    end
    return (s == "-0" || isempty(s)) ? "0" : String(s)
end

fmt(ctx, x::Real) = fmt(x, ctx.opts.digits)
coord(ctx, p) = string('(', fmt(ctx, p[1]), ',', fmt(ctx, p[2]), ')')
"absolute length in pt from figure units"
pt(ctx, x::Real) = string(fmt(ctx, x * ctx.opts.pt_per_unit), "pt")

# ---------------------------------------------------------------------------
# Colours

to_rgba(c::Colorant) = RGBA{Float64}(c)
to_rgba(c) = RGBA{Float64}(Makie.to_color(c))

const NAMED_COLORS = Dict{NTuple{3, Int}, String}(
    (0, 0, 0) => "black",
    (255, 255, 255) => "white",
)

"""
    colorname!(ctx, c) -> String

Name for the RGB part of `c` (alpha ignored), declared once per picture with
`\\definecolor`.
"""
function colorname!(ctx, c)
    rgba = to_rgba(c)
    key = (
        round(Int, 255 * clamp(red(rgba), 0, 1)),
        round(Int, 255 * clamp(green(rgba), 0, 1)),
        round(Int, 255 * clamp(blue(rgba), 0, 1)),
    )
    haskey(NAMED_COLORS, key) && return NAMED_COLORS[key]
    return get!(ctx.colors, key) do
        name = string(ctx.opts.color_prefix, length(ctx.colors) + 1)
        push!(ctx.color_defs, "\\definecolor{$name}{RGB}{$(key[1]),$(key[2]),$(key[3])}")
        name
    end
end

coloralpha(c) = Float64(alpha(to_rgba(c)))
isinvisible(c) = coloralpha(c) <= 1.0e-3

"`fill=...` style string for colour `c`, or `nothing` if fully transparent."
function fill_style(ctx, c)
    isinvisible(c) && return nothing
    a = coloralpha(c)
    s = "fill=" * colorname!(ctx, c)
    a < 0.999 && (s *= ", fill opacity=" * fmt(a, 3))
    return s
end

"`draw=..., line width=...` style string, or `nothing` if invisible."
function draw_style(ctx, c, linewidth)
    (isinvisible(c) || !(linewidth > 0)) && return nothing
    a = coloralpha(c)
    s = "draw=" * colorname!(ctx, c) * ", line width=" * pt(ctx, linewidth)
    a < 0.999 && (s *= ", draw opacity=" * fmt(a, 3))
    return s
end

joinstyles(parts...) = join(filter(!isnothing, collect(parts)), ", ")

# ---------------------------------------------------------------------------
# LaTeX escaping

const UNICODE_TO_LATEX = Dict{Char, String}(
    '−' => "\\ensuremath{-}",   # Makie tick labels use the Unicode minus
    '°' => "\\ensuremath{^\\circ}",
    '×' => "\\ensuremath{\\times}",
    '·' => "\\ensuremath{\\cdot}",
    '±' => "\\ensuremath{\\pm}",
    '≤' => "\\ensuremath{\\leq}",
    '≥' => "\\ensuremath{\\geq}",
    '≈' => "\\ensuremath{\\approx}",
    '≠' => "\\ensuremath{\\neq}",
    '→' => "\\ensuremath{\\rightarrow}",
    '←' => "\\ensuremath{\\leftarrow}",
    '∞' => "\\ensuremath{\\infty}",
    '…' => "\\ldots{}",
    'µ' => "\\ensuremath{\\mu}",
    '²' => "\\textsuperscript{2}",
    '³' => "\\textsuperscript{3}",
    '¹' => "\\textsuperscript{1}",
    '⁰' => "\\textsuperscript{0}",
    ' ' => "~",
    ' ' => "\\,",
    ' ' => "\\,",
)

const GREEK = Dict{Char, String}(
    'α' => "alpha", 'β' => "beta", 'γ' => "gamma", 'δ' => "delta", 'ε' => "varepsilon",
    'ζ' => "zeta", 'η' => "eta", 'θ' => "theta", 'ι' => "iota", 'κ' => "kappa",
    'λ' => "lambda", 'μ' => "mu", 'ν' => "nu", 'ξ' => "xi", 'π' => "pi", 'ρ' => "rho",
    'σ' => "sigma", 'τ' => "tau", 'υ' => "upsilon", 'φ' => "varphi", 'χ' => "chi",
    'ψ' => "psi", 'ω' => "omega", 'Γ' => "Gamma", 'Δ' => "Delta", 'Θ' => "Theta",
    'Λ' => "Lambda", 'Ξ' => "Xi", 'Π' => "Pi", 'Σ' => "Sigma", 'Υ' => "Upsilon",
    'Φ' => "Phi", 'Ψ' => "Psi", 'Ω' => "Omega", 'ϵ' => "epsilon", 'ϕ' => "phi",
)

"""
    latex_escape(s; unicode = true)

Escape LaTeX special characters in a plain string. With `unicode = true`,
common non-ASCII symbols (minus sign, Greek letters, °, ×, …) are replaced by
LaTeX commands so the output compiles with pdfLaTeX.
"""
function latex_escape(s::AbstractString; unicode::Bool = true)
    io = IOBuffer()
    for ch in s
        if ch == '\\'
            print(io, "\\textbackslash{}")
        elseif ch in ('#', '$', '%', '&', '_', '{', '}')
            print(io, '\\', ch)
        elseif ch == '~'
            print(io, "\\textasciitilde{}")
        elseif ch == '^'
            print(io, "\\textasciicircum{}")
        elseif ch == '\n'
            print(io, "\\\\")
        elseif unicode && haskey(UNICODE_TO_LATEX, ch)
            print(io, UNICODE_TO_LATEX[ch])
        elseif unicode && haskey(GREEK, ch)
            print(io, "\\ensuremath{\\", GREEK[ch], "}")
        else
            print(io, ch)
        end
    end
    return String(take!(io))
end

# literal U+2212 (not \x{2212}: Julia compiles regexes with ALT_BSUX)
const NUMBER_RE = r"^\s*[-−+]?(\d+\.?\d*|\.\d+)([eE][-−+]?\d+)?\s*$"

"True if `s` looks like a number (as Makie formats tick labels)."
isnumberstring(s::AbstractString) = occursin(NUMBER_RE, s)

"Typeset a numeric string in math mode, `1.5e-3` → `1.5\\times10^{-3}`."
function number_to_math(s::AbstractString)
    s = replace(strip(s), '−' => '-')
    m = match(r"^([-+]?[\d.]+)[eE]([-−+]?\d+)$", s)
    if m !== nothing
        exp = lstrip(replace(m.captures[2], "+" => ""), '0')
        exp = isempty(exp) ? "0" : (startswith(exp, "-") ? "-" * lstrip(exp[2:end], '0') : exp)
        return "\$" * m.captures[1] * "\\times 10^{" * exp * "}\$"
    end
    return "\$" * s * "\$"
end

# ---------------------------------------------------------------------------
# Anchors

function halign_value(h)
    h === :left && return 0.0
    h === :center && return 0.5
    h === :right && return 1.0
    h isa Real && return Float64(h)
    return 0.5
end

"""
    tikz_anchor(align) -> String

Map a Makie text `align` tuple to the nearest TikZ node anchor.
"""
function tikz_anchor(align)
    h, v = align[1], align[2]
    hv = halign_value(h)
    hs = hv < 0.25 ? "west" : hv > 0.75 ? "east" : ""
    vs = if v === :baseline
        "base"
    elseif v === :bottom
        "south"
    elseif v === :top
        "north"
    elseif v === :center
        ""
    elseif v isa Real
        v < 0.25 ? "south" : v > 0.75 ? "north" : ""
    else
        ""
    end
    if vs == "" && hs == ""
        return "center"
    elseif vs == ""
        return hs
    elseif hs == ""
        return vs
    else
        return vs * " " * hs
    end
end
