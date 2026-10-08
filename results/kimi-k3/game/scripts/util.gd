extends RefCounted

# Shared constants and small factories. Preloaded by other scripts.

const CYAN := Color(0.35, 0.9, 1.0)
const CYAN_DIM := Color(0.35, 0.9, 1.0, 0.55)
const AMBER := Color(1.0, 0.8, 0.25)
const BLUE := Color(0.4, 0.62, 1.0)
const RED := Color(1.0, 0.28, 0.22)
const GREEN := Color(0.45, 1.0, 0.55)
const BG := Color(0.045, 0.055, 0.075)
const PANEL := Color(0.10, 0.13, 0.17)
const STEEL := Color(0.23, 0.27, 0.32)
const INK := Color(0.85, 0.92, 0.97)

const TILE := 70.0
const ORIGIN := Vector2(10, 10)

static func font_main() -> Font:
	return load("res://assets/fonts/Kenney Future Narrow.ttf")

static func font_title() -> Font:
	return load("res://assets/fonts/Kenney Future.ttf")

static func font_square() -> Font:
	return load("res://assets/fonts/Kenney High Square.ttf")

static func tex_tile(num: String) -> Texture2D:
	return load("res://assets/tiles/platformIndustrial_%s.png" % num)

static func tex_ui(n: String) -> Texture2D:
	return load("res://assets/ui/%s.png" % n)

static func make_label(text: String, size: int, color: Color = INK, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	if font == null:
		font = font_main()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func cell_center(col: int, row: int) -> Vector2:
	return ORIGIN + Vector2(col * TILE + TILE * 0.5, row * TILE + TILE * 0.5)

static func cell_topleft(col: int, row: int) -> Vector2:
	return ORIGIN + Vector2(col * TILE, row * TILE)

# Darken a color for dim states.
static func dim(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)
