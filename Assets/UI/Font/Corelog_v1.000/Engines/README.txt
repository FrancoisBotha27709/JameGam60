CORELOG 1.000 - ENGINE FILES                      by wookdev

Ready-made import files for Godot 4, GameMaker and Construct 3, plus a JSON
atlas for custom engines, for Regular.

UNTESTED IN ENGINES: none of these files has been opened in Godot, GameMaker
or Construct 3 yet. They follow those engines' file formats and settings as
far as I know them, and every image was checked pixel by pixel against the
font's own glyph data (see HOW THIS WAS CHECKED). If something does not
import, the TTF and BMFont files still work the usual way - and please tell
me on the itch page so I can fix it.

1x = the font's native 16 px line, 2x = 32 px (line spacing 16 / 32 px).
Draw at whole-pixel positions with nearest-neighbour filtering.

CHARACTER ORDER (GameMaker frames, Construct 3 cells)
  745 characters per style: frame/cell 0 is the space, then ascending Unicode
  code point.
  Exception: the invisible characters U+00A0 (no-break space), U+00AD (soft
  hyphen) are placed last, so an editor that drops them from a pasted string
  cannot shift the others.
  Full list with code points and advances: Corelog_character_order.txt

GODOT 4 - Godot/
  Corelog-Regular_1x.tres
  Corelog-Regular_2x.tres
  Each .tres is a self-contained bitmap FontFile: the glyph atlas is embedded
  (white on transparent), with the glyph rectangles, advances and offsets of
  the BMFont files. fixed_size = 16 (1x) or 32 (2x); fixed_size_scale_mode =
  Integer Only (a Godot 4.2+ property; 4.0 and 4.1 ignore it). Missing
  characters show as a box (system fallback is off).
  1. Copy the .tres files into your project, e.g. res://fonts/.
  2. Select a Label: Theme Overrides > Fonts > Font = Corelog-Regular_1x.tres,
     Theme Overrides > Font Sizes > Font Size = 16 (or 32, 48 ... for 2x, 3x).
  3. Sharp pixels: CanvasItem > Texture > Filter = Nearest on the Label, or
     Project Settings > Rendering > Textures > Canvas Textures >
     Default Texture Filter = Nearest.
  Scene snippet (.tscn):
    [gd_scene load_steps=2 format=3]

    [ext_resource type="FontFile" path="res://fonts/Corelog-Regular_1x.tres" id="1_font"]

    [node name="Label" type="Label"]
    texture_filter = 1
    theme_override_fonts/font = ExtResource("1_font")
    theme_override_font_sizes/font_size = 16
    text = "Hello"
  Script snippet (.gd, on the Label's parent):
    var font: FontFile = load("res://fonts/Corelog-Regular_1x.tres")
    $Label.add_theme_font_override("font", font)
    $Label.add_theme_font_size_override("font_size", 16)
    $Label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
  Other ways: copy BMFont/Corelog-Regular_1x.fnt and its .png into the project
  (Godot 4 imports .fnt files as fonts), or use the TTF: select it in the
  FileSystem dock, Import tab: Antialiasing = None, Hinting = None, Subpixel
  Positioning = Disabled, click Reimport, and use font sizes 16, 32, 48 ...

GAMEMAKER - GameMaker/
  Corelog-Regular_1x_strip745.png   745 frames of 8 x 16 px
  Corelog-Regular_2x_strip745.png   745 frames of 16 x 32 px
  corelog_font.gml                  character map, advances, two functions per style
  1. Create a Sprite, click Import and choose a _strip745.png file. GameMaker
     splits images whose name ends in _stripN into N frames. Keep the origin
     at Top Left (0, 0). Name it e.g. spr_corelog_regular_1x.
  2. Create a Script asset and paste the whole of corelog_font.gml.
  3. Then either
   a) GameMaker's own sprite font (draw_text, string_width, alignment):
        global.fnt = corelog_regular_font_add(spr_corelog_regular_1x, 1);
        draw_set_font(global.fnt);
        draw_text(x, y, "Hello");
      This is font_add_sprite_ext(sprite, map, true, sep). In proportional mode
      GameMaker measures each frame's visible width itself, so the space and
      glyphs with built-in side space are spaced by GameMaker, not by the font
      (Regular: 741 of 745 characters differ, by my estimate).
   b) Exact spacing, same as the TTF:
        corelog_regular_draw_text(spr_corelog_regular_1x, 1, x, y, "Hello");
      Draws frame by frame with the font's own advances in the current draw
      colour and alpha, handles "\n", returns the line width. With a 2x strip
      pass 2 as the scale.

CONSTRUCT 3 - Construct3/
  Corelog-Regular_1x.png              16 columns of 8 x 16 px cells
  Corelog-Regular_2x.png              16 columns of 16 x 32 px cells
  Corelog_charset.txt                 Character set (copy all of it; starts with a space)
  Corelog-<Style>_<s>x_spacing.json   Spacing data per sheet
  Corelog_properties.json             the property values below, per sheet
  1. Insert a Sprite Font object, open its image (double-click it in the
     Project Bar or layout) and load the PNG.
  2. Properties:
       Regular             1x    2x
       Character width     8     16
       Character height    16    32
       Character spacing   0     0
       Line height         0     0
     Character set: paste Corelog_charset.txt.
     Spacing data: paste the matching _spacing.json ([[width, "chars"], ...]).
  3. Project Properties: Sampling = Nearest, Pixel rounding = On.

JSON ATLAS - JSON/
  Corelog-<Style>_1x/2x/4x.json, one per BMFont atlas (BMFont/*.png):
  "glyphs": { "A": { "codepoint": 65, "x", "y", "w", "h", "advance",
  "xoffset", "yoffset" } } plus font_size, line_height and baseline.
  Draw the rect at (pen + xoffset, line top + yoffset), then pen += advance.

PHASER 3 / PIXIJS - no new files
  The BMFont .xml (and .fnt) files already work:
    Phaser 3: this.load.bitmapFont("corelog", "BMFont/Corelog-Regular_2x.png",
                                   "BMFont/Corelog-Regular_2x.xml");
              this.add.bitmapText(16, 16, "corelog", "Hello", 32);
    PixiJS 8: await Assets.load("BMFont/Corelog-Regular_1x.fnt");
              new BitmapText({ text: "Hello", style: { fontFamily: "Corelog", fontSize: 16 } });
  Pixi takes the font name from face="Corelog" inside the file, which is
  the same in every style and scale file: load one of them per name, or edit
  face= in your copy.

HOW THIS WAS CHECKED
  These files were generated from glyphs.json and the BMFont data, read every
  file back from disk, re-rendered each glyph alone and a sample text (a
  pangram plus the whole character set) from it, and compared the pixels with
  glyphs.json: 6705 glyph renders and 9 sample-text renders (627084 pixels), 0
  mismatched pixels, no partial-alpha pixels, advances exact. The BMFont .xml
  files were parsed and match the .fnt files char by char.
