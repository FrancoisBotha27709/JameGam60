CORELOG            version 1.000
by wookdev

An 8x16 monospace pixel font for spacecraft diagnostics, communication logs,
hacking terminals and text-mode roguelikes. Every character advances 8 pixels.
One-pixel strokes, squared counters, a slashed zero, complete box drawing and
block elements, Latin, Greek, Cyrillic and 16 inline HUD icons.

HUD icons occupy U+E000-U+E00F; see mapping.json for names.
CP437 screen-glyph tiles use slot zero as a blank; see CP437/README.txt.

WHAT IS INSIDE
  Engines/     Godot 4, GameMaker, Construct 3 and JSON atlas exports
  CP437/       four 16 x 16 tile PNGs, index map and usage notes
  TTF/         Corelog-Regular.ttf
  WOFF/        same fonts for web pages
  BMFont/      per style and scale (1x, 2x, 4x): .png atlas + .fnt (text) + .xml
               (every char cell is the full 16 px line tall; x offsets as listed)
  GridSheets/  16-column fixed-cell PNG sheets per Unicode block at 1x, 2x, 4x
  glyphs.json  every glyph as 16 pixel rows plus width, advance and x offset
  mapping.json

CHARACTER SET (745 glyphs)
  ASCII                                                95
  Latin-1                                              96
  Latin Ext-A + Romanian + f-hook                      133
  Greek                                                71
  Cyrillic + №                                         99
  Box Drawing                                          128
  Block Elements                                       32
  Arrows, math, shapes and CP437 symbols               75
  HUD icons PUA                                        16
  No CJK (Korean, Japanese, Chinese), Arabic, Hebrew or emoji presentation.
  Greek is monotonic; no polytonic Greek. No combining-mark glyphs or automatic
  normalization: use precomposed NFC text. No kerning pairs, ligatures or other weights.
  Accented lowercase ascenders use compact bodies; 2-row rings are simplified.
  Cedilla, ogonek and comma-below marks are detached to preserve a clear gap.
  Allow extra line spacing for stacked accents; integer 16 px multiples only.
  Engine imports and CP437 consumer applications have not been tested in-app.
  The soft hyphen is visible in bitmap exports. PUA icon meaning follows mapping.json.

METRICS (at 1x = 16 px font size)
  Each glyph sits in an 8x16 cell (every character advances exactly 8 px): rows 0-2 = accent zone, rows 3-12 = cap height (row 12 sits on the baseline), rows 6-12 = x-height, rows 13-15 = descenders. Box drawing and block characters fill the whole cell so they join up.
  TTF: 1600 units per em, 1 pixel = 100 units.

GETTING SHARP PIXELS
  Use sizes that are multiples of 16 px (16, 32, 48, 64 ...), whole-pixel positions,
  anti-aliasing off where your engine allows, and nearest-neighbour scaling.
  BMFont/grid sheets: integer scales only.

  How this was checked: every TTF was rendered with FreeType 2.13.2 glyph by glyph
  at 16, 32 and 64 px with hinting off, default hinting and forced
  auto-hinting, and compared pixel by pixel with the source bitmaps: 6705
  checks, 0 mismatched pixels, no grey pixels, advances exact. Other rasterizers
  and specific engines were NOT tested; engine notes are general pointers.

ENGINE FILES (untested in engines)
  Engines/Godot/       bitmap FontFile (.tres), 1x and 2x; embedded atlas
  Engines/GameMaker/   sprite strips and GML character map, 1x and 2x
  Engines/Construct3/  Sprite Font sheets, character set and spacing, 1x and 2x
  Engines/JSON/        atlas coordinates and exact advances, 1x, 2x and 4x
  Phaser / PixiJS can use the BMFont files. See Engines/README.txt.
  These files were generated from glyphs.json and the BMFont data, read every
  file back from disk, re-rendered each glyph alone and a sample text (a
  pangram plus the whole character set) from it, and compared the pixels with
  glyphs.json: 6705 glyph renders and 9 sample-text renders (627084 pixels), 0
  mismatched pixels, no partial-alpha pixels, advances exact. The BMFont .xml
  files were parsed and match the .fnt files char by char.
  Files were also re-read from the final zip and checked against the bitmaps.
  These files have NOT been opened inside the game engines.

CP437 TILES (untested in consumer tools)
  256 screen-glyph slots; slot zero is blank U+0020, U+0000 is omitted.
  16 x 16 tile layout: 128 x 256 px at 1x; 256 x 512 px at 2x.
  White glyphs with transparent and black backgrounds, four PNGs total.
  For CP437 tilesheet consumers including libtcod, REXPaint and BearLibTerminal.
  NOT tested inside those tools. See CP437/README.txt and cp437_order.txt.
  1,024 tile bitmap checks and 256 ordering checks; zero mismatches.

ENGINE POINTERS (untested)
  Godot 4     import the .ttf: Antialiasing None, Hinting None, Subpixel off;
              or import a BMFont .fnt
  Unity       TextMeshPro font asset in raster (non-SDF) mode, Point filtering
  GameMaker   font asset from the .ttf with anti-aliasing off
  LOVE        love.graphics.newFont("<file>.ttf", 32, "mono")
  Phaser 3    this.load.bitmapFont(key, "...png", "...xml")
  Web/CSS     @font-face with the .woff, font-size in multiples of 16px

BOX AND BLOCK CHECKS
  250,290 tile and seam assertions, zero failures.
  160 box/block glyphs, 7,680 grid cells and 51,200 ordered neighbour pairs.

HOW IT WAS MADE
  Every glyph sits on a strict pixel grid. The TTF, BMFont
  atlases and sheets are generated from those same bitmaps by a script.

LICENSE
  See LICENSE.txt. Short version: use it in commercial and non-commercial
  projects, modify it, no credit needed; do not resell or redistribute the files.

PACKAGE INVENTORY
  Full download: 68 files; 745 mapped glyphs plus .notdef.
