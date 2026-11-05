using Documenter, TikzMakie

include("build_gallery.jl")
build_gallery()

# outside a git checkout (e.g. a copied tree) there is no remote to link to
in_git = isdir(joinpath(@__DIR__, "..", ".git"))
remote_kw = in_git ? (; repo = Remotes.GitHub("EvoArt", "TikzMakie.jl")) : (; remotes = nothing)

makedocs(;
    sitename = "TikzMakie.jl",
    modules = [TikzMakie],
    authors = "Arthur Newbury",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "") == "true",
        canonical = "https://evoart.github.io/TikzMakie.jl",
        edit_link = "main",
        size_threshold = 2^21,
    ),
    pages = [
        "Home" => "index.md",
        "Using it in LaTeX" => "latex.md",
        "Gallery" => "gallery.md",
        "How it works" => "internals.md",
        "API" => "api.md",
    ],
    warnonly = [:missing_docs],
    remote_kw...,
)

in_git && deploydocs(; repo = "github.com/EvoArt/TikzMakie.jl.git", devbranch = "main", push_preview = false)
