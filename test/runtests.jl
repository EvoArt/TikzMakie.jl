using Test
using TikzMakie
using TikzMakie: fmt, latex_escape, isnumberstring, number_to_math, tikz_anchor, clip_segment, split_polyline
using CairoMakie   # loads the rasterisation extension; TikzMakie itself needs no backend
using Makie, LaTeXStrings, Random, Dates
using GeometryBasics: Point2d

include(joinpath(@__DIR__, "figures.jl"))

"Checks every generated picture must pass."
function check_wellformed(code::AbstractString)
    @test !occursin("NaN", code)
    @test !occursin("Inf", code)
    @test count("\\begin{tikzpicture}", code) == 1
    @test count("\\end{tikzpicture}", code) == 1
    @test count("\\begin{scope}", code) == count("\\end{scope}", code)
    # every coordinate within TikZ's comfortable range
    for m in eachmatch(r"\((-?[\d.]+),(-?[\d.]+)\)", code)
        x, y = parse(Float64, m.captures[1]), parse(Float64, m.captures[2])
        @test abs(x) < 16000 && abs(y) < 16000
    end
    return
end

@testset "TikzMakie" begin
    @testset "formatting" begin
        @test fmt(1.0) == "1"
        @test fmt(1.23456) == "1.23"
        @test fmt(1.23456, 3) == "1.235"
        @test fmt(-0.0001) == "0"
        @test fmt(1.0e7) == "10000000"
        @test fmt(0.5, 3) == "0.5"
        @test_throws ArgumentError fmt(NaN)
    end

    @testset "escaping" begin
        @test latex_escape("50% & #1_x {y} ~ ^ \$") == "50\\% \\& \\#1\\_x \\{y\\} \\textasciitilde{} \\textasciicircum{} \\\$"
        @test latex_escape("a\\b") == "a\\textbackslash{}b"
        @test latex_escape("−1") == "\\ensuremath{-}1"
        @test latex_escape("α = 3°") == "\\ensuremath{\\alpha} = 3\\ensuremath{^\\circ}"
        @test latex_escape("α"; unicode = false) == "α"
        @test latex_escape("two\nlines") == "two\\\\lines"
    end

    @testset "numbers" begin
        @test isnumberstring("1.5")
        @test isnumberstring("−1.5")      # Unicode minus, as in Makie tick labels
        @test isnumberstring("-2")
        @test isnumberstring("1e-3")
        @test !isnumberstring("1.5 m")
        @test !isnumberstring("")
        @test number_to_math("−1.5") == "\$-1.5\$"
        @test number_to_math("1.5e-03") == "\$1.5\\times 10^{-3}\$"
        @test number_to_math("2e+10") == "\$2\\times 10^{10}\$"
    end

    @testset "anchors" begin
        @test tikz_anchor((:left, :bottom)) == "south west"
        @test tikz_anchor((:center, :center)) == "center"
        @test tikz_anchor((:right, :top)) == "north east"
        @test tikz_anchor((:center, :baseline)) == "base"
        @test tikz_anchor((:left, :baseline)) == "base west"
        @test tikz_anchor((0.5, 1.0)) == "north"
        @test tikz_anchor((1, 0.5)) == "east"
    end

    @testset "clipping" begin
        r = (0.0, 0.0, 10.0, 10.0)
        ok, a, b = clip_segment(Point2d(-5, 5), Point2d(5, 5), r)
        @test ok && a ≈ Point2d(0, 5) && b ≈ Point2d(5, 5)
        ok, _, _ = clip_segment(Point2d(-5, -5), Point2d(-1, -1), r)
        @test !ok
        runs = split_polyline([Point2d(1, 1), Point2d(2, 2), Point2d(NaN, NaN), Point2d(3, 3), Point2d(4, 4)], r)
        @test length(runs) == 2
        # leaving and re-entering splits the run
        runs = split_polyline([Point2d(1, 5), Point2d(20, 5), Point2d(5, 6)], r)
        @test length(runs) == 2
        @test all(p -> 0 <= p[1] <= 10, reduce(vcat, runs))
        # entirely outside
        @test isempty(split_polyline([Point2d(20, 20), Point2d(30, 30)], r))
    end

    @testset "figure: $name" for (name, make) in FIGURES
        Random.seed!(1)
        fig = make()
        t = tikz(fig)
        check_wellformed(t.code)
        @test occursin("\\node", t.code)
    end

    @testset "text content" begin
        t = tikz(fig_latex()).code
        @test occursin("\\frac{\\sin(\\alpha)}{\\alpha}", t)            # LaTeXString passed raw
        @test occursin("50\\% \\& \\#1\\_x \\{test\\}", t)               # plain string escaped
        @test occursin("\\textsuperscript{2}", t)                      # rich text
        t = tikz(fig_lines()).code
        @test occursin("{\$-1.0\$}", t)                                 # numeric tick labels in math
        @test occursin("\\bfseries", t)                                # bold title
        @test !occursin("{\$-1.0\$}", tikz(fig_lines(); numbers_as_math = false).code)
        @test !occursin("\\fontsize", tikz(fig_lines(); fontsize = :inherit).code)
        t = tikz(fig_logaxis()).code
        @test occursin("10^{-2}", t)                                   # log ticks as math
    end

    @testset "node styles" begin
        # images must not get the text strut (it would shift them up), and
        # char markers keep their own font size when the common one is hoisted
        t = tikz(fig_heatmap()).code
        @test occursin("\\node[mkimg, anchor=south west]", t)
        @test !occursin("\\node[mknode, anchor=south west] at", t[findfirst("includegraphics", t)[1] - 80:findfirst("includegraphics", t)[1]])
        t = tikz(fig_scatter()).code
        charlines = filter(l -> startswith(l, "\\node[mkimg") && endswith(l, "{A};"), split(t, '\n'))
        @test length(charlines) == 5
        @test all(l -> occursin("\\fontsize", l), charlines)
        @test occursin("mknode/.style={inner sep=0pt, outer sep=0pt, execute at begin node={\\vphantom{(}}, font=", t)
    end

    @testset "displaystyle" begin
        fig = Figure()
        Axis(fig[1, 1]; xlabel = L"\frac{a}{b}", ylabel = L"cost $\sum_i x_i$ (\$)")
        t = tikz(fig; displaystyle = true).code
        @test occursin("{\$\\displaystyle \\frac{a}{b}\$}", t)
        @test occursin("cost \$\\displaystyle \\sum_i x_i\$ (\\\$)", t)   # escaped \$ untouched
        @test !occursin("displaystyle", tikz(fig).code)
    end

    @testset "other inputs" begin
        # FigureAxisPlot, as returned by lines(...)
        fap = lines(1:10, rand(10); axis = (; title = "fap"))
        t = tikz(fap).code
        check_wellformed(t)
        @test occursin("{fap}", t)
        # Dates on an axis (dim converts)

        fig = Figure()
        ax = Axis(fig[1, 1])
        lines!(ax, DateTime(2024, 1, 1):Day(1):DateTime(2024, 3, 1), rand(61))
        t = tikz(fig).code
        check_wellformed(t)
        @test occursin("2024", t)
        # word-wrapped label
        fig = Figure(size = (300, 300))
        Label(fig[1, 1], "a long label that has to wrap across several lines"; word_wrap = true)
        t = tikz(fig).code
        check_wellformed(t)
        @test occursin("wrap", t)
        @test occursin("text width=", t)
    end

    @testset "options" begin
        fig = fig_lines()
        @test occursin("x=0.5pt", tikz(fig; pt_per_unit = 0.5).code)
        @test occursin("\\documentclass", tikz(fig; standalone = true).code)
        @test !occursin("\\documentclass", tikz(fig).code)
        @test occursin("SINE", tikz(fig; textfilter = s -> s == "sin" ? "SINE" : s).code)
        @test occursin("mkc1", tikz(fig).code)
        @test occursin("col1", tikz(fig; color_prefix = "col").code)
    end

    @testset "visibility" begin
        fig = Figure()
        ax = Axis(fig[1, 1])
        lines!(ax, 1:3, 1:3; color = :red)
        lines!(ax, 1:3, 3:-1:1; color = :green, visible = false)
        t = tikz(fig).code
        @test occursin("RGB}{255,0,0}", t)
        @test !occursin("RGB}{0,128,0}", t)
    end

    @testset "does not add colour nodes to the figure" begin
        # A backend (e.g. CairoMakie) registers `computed_color` itself, from
        # plot-type-specific inputs; if we registered it first, saving the
        # same figure with CairoMakie afterwards would fail.
        fig = fig_bars_band()
        Makie.update_state_before_display!(fig)
        plots = Makie.collect_atomic_plots(fig.scene)
        before = [haskey(p.attributes, :computed_color) for p in plots]
        tikz(fig)
        @test before == [haskey(p.attributes, :computed_color) for p in plots]
        mesh_plot = first(p for p in plots if p isa Mesh)
        @test_nowarn Makie.compute_colors!(mesh_plot.attributes, :color)
    end

    @testset "scene input" begin
        scene = Scene(size = (200, 200), camera = campixel!)
        lines!(scene, Point2f[(10, 10), (190, 190)]; color = :black)
        text!(scene, 100, 100; text = "hello", align = (:center, :center))
        t = tikz(scene).code
        check_wellformed(t)
        @test occursin("{hello}", t)
        @test occursin("(10,10) -- (190,190)", t)
    end

    @testset "savetikz writes images" begin
        dir = mktempdir()
        path = savetikz(joinpath(dir, "hm.tex"), fig_heatmap())
        @test isfile(path)
        code = read(path, String)
        @test occursin("\\includegraphics", code)
        @test occursin("{hm-1.png}", code)
        @test isfile(joinpath(dir, "hm-1.png"))
        savetikz(joinpath(dir, "hm2.tex"), fig_heatmap(); image_prefix = "figs/")
        @test occursin("{figs/hm2-1.png}", read(joinpath(dir, "hm2.tex"), String))
    end

    @testset "theme helpers" begin
        @test size_pt(345, 200) == (460.0, 200 / 0.75)
        th = latex_theme(fontsize = 9)
        @test th.fontsize[] ≈ 12
    end

    @testset "line simplification" begin
        straight = [Point2d(i, 2i) for i in 0:100]
        @test length(TikzMakie.simplify_polyline(straight, 0.01)) == 2
        @test length(TikzMakie.simplify_polyline(straight, 0)) == 101
        zig = [Point2d(i, isodd(i) ? 1 : 0) for i in 0:10]
        @test length(TikzMakie.simplify_polyline(zig, 0.5)) == 11
        fig = Figure()
        xs = range(0, 10, length = 20_000)
        lines(fig[1, 1], xs, sin.(xs))
        n_simplified = count("--", tikz(fig).code)
        n_full = count("--", tikz(fig; simplify = 0).code)
        @test n_simplified < n_full / 10
    end

    @testset "per-vertex colours merge into runs" begin
        fig = Figure()
        xs = range(0, 1, length = 2000)
        lines(fig[1, 1], xs, xs; color = fill(0.5, 2000), colorrange = (0, 1))
        # constant colour values: one \draw for the data line, not 1999
        @test count("line cap=round", tikz(fig).code) == 1
    end

    @testset "rasterize (CairoMakie extension)" begin
        fig = Figure(size = (400, 300))
        ax = Axis(fig[1, 1])
        scatter!(ax, rand(500), rand(500); rasterize = true)
        lines!(ax, 0:1, 0:1; color = :red)
        t = tikz(fig)
        @test length(t.images) == 1
        @test occursin("\\includegraphics", t.code)
        @test !occursin("circle[", t.code)                # the scatter is not drawn as vectors
        @test occursin("RGB}{255,0,0}", t.code)           # the line still is
        name, img = t.images[1]
        scene_w = Makie.widths(Makie.viewport(ax.scene)[])[1]
        @test size(img, 2) == round(Int, 4 * scene_w)     # rasterize_scale = 4
        @test any(c -> Makie.alpha(c) > 0, img)
        @test any(c -> Makie.alpha(c) == 0, img)                # transparent background
        t2 = tikz(fig; rasterize_scale = 2)
        @test size(t2.images[1][2], 2) == round(Int, 2 * scene_w)
    end

    @testset "more plot types" begin
        include(joinpath(@__DIR__, "stress.jl"))
        @testset "$name" for (name, make) in STRESS
            Random.seed!(2)
            fig = make()
            t = @test_nowarn tikz(fig)
            check_wellformed(t.code)
        end
    end

    pdflatex = Sys.which("pdflatex")
    if pdflatex !== nothing && get(ENV, "TIKZMAKIE_SKIP_LATEX", "") == ""
        @testset "compiles with pdflatex: $name" for (name, make) in FIGURES
            dir = mktempdir()
            Random.seed!(1)
            savetikz(joinpath(dir, "$name.tex"), make(); standalone = true)
            ok = success(Cmd(`$pdflatex -interaction=nonstopmode -halt-on-error $name.tex`; dir))
            @test ok
        end
    else
        @info "pdflatex not found (or TIKZMAKIE_SKIP_LATEX set); skipping compile tests"
    end
end
