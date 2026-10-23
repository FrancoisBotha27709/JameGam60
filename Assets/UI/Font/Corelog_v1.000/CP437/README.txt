CORELOG CP437 SCREEN TILES
by wookdev

256 slots in a 16 x 16 grid. The base tile is 8 x 16 pixels.
1x sheets: 128 x 256 pixels. 2x sheets: 256 x 512 pixels (16 x 32 tiles).
Four PNGs: opaque white glyphs with transparent or opaque black background,
at each scale. Use nearest-neighbour scaling, no padding and no spacing.
Slot 0 is blank and maps to U+0020 SPACE; U+0000 is omitted from the font.
Slot 32 is also SPACE; slot 255 is U+00A0 NO-BREAK SPACE.
cp437_order.txt records every index, byte value, Unicode value and character.

For tools that can read CP437 tilesheets, such as libtcod, REXPaint and
BearLibTerminal. Select CP437 ordering and the matching tile dimensions in
the consumer. These sheets have NOT been tested inside those tools.
Bitmap comparison and ordering checks do not establish in-app compatibility.

Mapping references (read 2026-10-20):
https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/PC/CP437.TXT
https://www.unicode.org/Public/MAPPINGS/VENDORS/MISC/IBMGRAPH.TXT
The DOS text mapping supplies bytes 32-126 and 128-255. IBM PC video graphics
supply bytes 1-31 and 127. This is screen-glyph order, not control-code text.
