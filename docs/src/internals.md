# How it works

TikzMakie walks the figure's scene tree the way CairoMakie does, but writes
TikZ instead of making Cairo calls:

1. Settle the layout (`Makie.update_state_before_display!`).
2. Fill scene backgrounds.
3. Collect the primitive plots (lines, scatter, text, meshes, images, …).
   `Poly` and `Band` are kept whole so they become clean vector paths rather
   than triangle meshes, and `Text` is kept whole so it becomes LaTeX nodes.
4. Sort by depth, and open a `\clip` scope for each scene viewport.
5. Project every position through Makie's own camera matrices to figure
   coordinates (Makie units, y up, the same orientation as TikZ), and write
   TikZ.

Text is read from the plot *before* Makie lays out glyphs: the original
string, its alignment (mapped to a TikZ anchor), rotation, size, colour and
font weight. Makie aligns text by the font's ascender/descender, so every
node gets a `\vphantom{(}` strut to mimic that.

Geometry far outside the figure is clipped in Julia (Liang–Barsky for lines,
Sutherland–Hodgman for fills), because TikZ cannot handle huge coordinates.
Dense lines are simplified with Ramer–Douglas–Peucker at a tolerance far
below visibility.

## Limitations

- Text width: LaTeX typesets the text after Makie has laid out the figure.
  With [`latex_theme`](@ref) the widths agree closely; with very different
  fonts, long labels may not fit the space Makie reserved.
- 3D meshes are flat-shaded and intersecting triangles are not split. Use
  `rasterize`.
- Pattern fills become grey; character markers lose their outline.
- Uses Makie internals (the 0.24 compute graph), so each Makie minor release
  may need an update.
