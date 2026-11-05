# Writes standalone .tex files (TikzMakie) and .png/.pdf files (CairoMakie)
# for each figure in figures.jl, for side-by-side visual comparison.
#
#   julia --project=env TikzMakie/test/gallery.jl [outdir] [names...]

using CairoMakie, TikzMakie, Random
include(joinpath(@__DIR__, "figures.jl"))

outdir = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "out")
only = length(ARGS) >= 2 ? Set(ARGS[2:end]) : nothing
mkpath(outdir)

for (name, make) in FIGURES
    only !== nothing && !(name in only) && continue
    Random.seed!(1)
    fig = make()
    t = @elapsed savetikz(joinpath(outdir, name * ".tex"), fig; standalone = true)
    save(joinpath(outdir, name * "-cairo.png"), fig; px_per_unit = 1)
    sz = filesize(joinpath(outdir, name * ".tex"))
    println(rpad(name, 12), " ", round(t; digits = 2), " s  ", round(sz / 1024; digits = 1), " KiB")
end
