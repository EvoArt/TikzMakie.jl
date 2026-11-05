# Text: emitted as LaTeX nodes so the document typesets it.

const MATHY_CHARS = Set("0123456789.,−-+×·eE ")

"Is every leaf string of this rich text made of number-ish characters?"
is_numeric_rich(s::AbstractString) = all(in(MATHY_CHARS), s)
is_numeric_rich(r::Makie.RichText) = all(is_numeric_rich, r.children)

function math_leaf(s::AbstractString)
    s = replace(s, '−' => "-", '×' => "\\times ", '·' => "\\cdot ")
    return s
end

function rich_to_math(r::Makie.RichText)
    inner = join(c isa Makie.RichText ? rich_to_math(c) : math_leaf(c) for c in r.children)
    r.type === :sup && return "^{" * inner * "}"
    r.type === :sub && return "_{" * inner * "}"
    if r.type === :subsup && length(r.children) == 2
        a, b = (c isa Makie.RichText ? rich_to_math(c) : math_leaf(c) for c in r.children)
        return "_{" * a * "}^{" * b * "}"
    end
    return inner
end

function font_wrap(font, s)
    f = lowercase(string(font))
    if occursin("bold", f) && occursin("italic", f)
        return "\\textbf{\\textit{" * s * "}}"
    elseif occursin("bold", f)
        return "\\textbf{" * s * "}"
    elseif occursin("italic", f) || occursin("oblique", f)
        return "\\textit{" * s * "}"
    end
    return s
end

function rich_to_latex(ctx, r::Makie.RichText)
    leaf(c) = c isa Makie.RichText ? rich_to_latex(ctx, c) : latex_escape(c; unicode = ctx.opts.unicode)
    if r.type === :subsup && length(r.children) == 2
        inner = "\\ensuremath{_{\\text{" * leaf(r.children[1]) * "}}^{\\text{" * leaf(r.children[2]) * "}}}"
    elseif r.type === :leftsubsup && length(r.children) == 2
        inner = "\\ensuremath{{}_{\\text{" * leaf(r.children[1]) * "}}^{\\text{" * leaf(r.children[2]) * "}}}"
    else
        inner = join(leaf(c) for c in r.children)
        r.type === :sup && (inner = "\\textsuperscript{" * inner * "}")
        r.type === :sub && (inner = "\\textsubscript{" * inner * "}")
    end
    if haskey(r.attributes, :font)
        inner = font_wrap(r.attributes[:font], inner)
    end
    if haskey(r.attributes, :color)
        c = Makie.to_color(r.attributes[:color])
        inner = "\\textcolor{" * colorname!(ctx, c) * "}{" * inner * "}"
    end
    return inner
end

"""
    text_to_latex(ctx, s) -> String

LaTeX source for one Makie text block. `LaTeXString`s pass through
unchanged; plain strings are escaped; rich text maps to `\\textsuperscript`
etc.; numeric strings become math with `numbers_as_math`.
"""
text_to_latex(ctx, s::LaTeXString) = String(s)

function text_to_latex(ctx, s::AbstractString)
    if ctx.opts.numbers_as_math && isnumberstring(s)
        return number_to_math(s)
    end
    return latex_escape(s; unicode = ctx.opts.unicode)
end

function text_to_latex(ctx, r::Makie.RichText)
    if ctx.opts.numbers_as_math && is_numeric_rich(r) && !isempty(String(r))
        return "\$" * rich_to_math(r) * "\$"
    end
    return rich_to_latex(ctx, r)
end

text_to_latex(ctx, x) = latex_escape(string(x); unicode = ctx.opts.unicode)

"Weight/shape switches for a resolved font (`NativeFont`)."
function font_switches(font)
    style = try
        lowercase(string(font.style_name))
    catch
        lowercase(string(font))
    end
    sw = ""
    occursin("bold", style) && (sw *= "\\bfseries")
    (occursin("italic", style) || occursin("oblique", style)) && (sw *= "\\itshape")
    return sw
end

fontsize_scalar(x::Real) = Float64(x)
fontsize_scalar(x::VecTypes) = Float64(x[2])
fontsize_scalar(x) = 12.0

function justification_name(j, align)
    j = unref(j)
    j === :left && return "left"
    j === :right && return "right"
    j === :center && return "center"
    j isa Real && return j < 0.25 ? "left" : j > 0.75 ? "right" : "center"
    # automatic: follows horizontal alignment
    hv = halign_value(align[1])
    return hv < 0.25 ? "left" : hv > 0.75 ? "right" : "center"
end

per_block(x, i) = per_index(x, i)

function draw_plot!(ctx, scene::Scene, plot::Text)
    texts = getattr(plot, :input_text)
    texts isa AbstractVector || (texts = [texts])
    isempty(texts) && return
    positions = plot_positions(plot)
    length(positions) == length(texts) || (positions = fill(first(positions), length(texts)))
    space = getattr(plot, :space, :data)
    markerspace = getattr(plot, :markerspace, :pixel)
    P = Projector(scene, plot)
    model = getattr(plot, :model_f32c, Mat4d(I))
    to_ms = markerspace === :pixel ? nothing :
        Mat4d(Makie.get_space_to_space_matrix(scene, space, markerspace)) * Mat4d(model)

    aligns = unref(getattr(plot, :align, (:left, :bottom)))
    rotations = getattr(plot, :rotation, 0.0)
    fontsizes = getattr(plot, :fontsize, 12.0)
    offsets = getattr(plot, :offset, Vec3f(0))
    colors = computed_color(plot)
    fonts = getattr(plot, :selected_font, nothing)
    justs = getattr(plot, :justification, Makie.automatic)
    r = clip_rect(ctx)

    for (i, str) in enumerate(texts)
        s = str isa AbstractString || str isa Makie.RichText ? str : string(str)
        String(s) == "" && continue
        p = positions[i]
        isfinitepoint(p) || continue
        o = P(p)
        (isfinitepoint(o) && inrect(o, r)) || continue

        scale = Vec2d(1, 1)
        if to_ms !== nothing
            pm4 = to_ms * Vec4d(p[1], p[2], length(p) > 2 ? p[3] : 0.0, 1.0)
            scale = markerspace_scale(scene, markerspace, Vec3d(pm4[1], pm4[2], pm4[3]) ./ pm4[4])
        end
        off = per_block(offsets, i)
        o = Point2d(o[1] + off[1] * scale[1], o[2] + off[2] * scale[2])

        al = per_block(aligns, i)
        al isa Tuple || al isa VecTypes || (al = (:left, :bottom))
        angle = rotation_angle(per_block(rotations, i))
        fsz = fontsize_scalar(per_block(fontsizes, i)) * scale[2]
        color = per_block(colors, i)
        color isa AbstractVector && (color = first(color))
        isinvisible(color) && continue

        latex = ctx.opts.textfilter(text_to_latex(ctx, s))
        font = fonts === nothing ? nothing : per_block(fonts, i)
        sw = font === nothing ? "" : font_switches(font)

        fontcmd = sw
        if ctx.opts.fontsize === :native
            ptsz = fsz * ctx.opts.pt_per_unit
            fontcmd = "\\fontsize{" * fmt(ptsz, 2) * "}{" * fmt(1.2 * ptsz, 2) * "}\\selectfont" * sw
        end
        a = coloralpha(color)
        multiline = occursin('\n', String(s))
        opts = joinstyles(
            "mknode",
            "anchor=" * tikz_anchor(al),
            colorname!(ctx, color) == "black" ? nothing : "text=" * colorname!(ctx, color),
            a < 0.999 ? "text opacity=" * fmt(a, 3) : nothing,
            abs(angle) > 1.0e-6 ? "rotate=" * fmt(angle * 180 / pi, 2) : nothing,
            # data-space text stretches with the axis aspect, as in Makie
            abs(scale[1] / scale[2] - 1) > 0.01 ? "xscale=" * fmt(scale[1] / scale[2], 3) : nothing,
            multiline ? "align=" * justification_name(per_block(justs, i), al) : nothing,
            isempty(fontcmd) ? nothing : "font=" * fontcmd,
        )
        println(ctx.io, "\\node[", opts, "] at ", coord(ctx, o), " {", latex, "};")
    end
    return
end
