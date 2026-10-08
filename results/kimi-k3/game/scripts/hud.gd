extends CanvasLayer

# In-play HUD: chamber name, loop timer bar, loop counter, echo count,
# stability pips, and the contextual hint line.

const _Util = preload("res://scripts/util.gd")

var chamber_label: Label
var time_label: Label
var loop_label: Label
var echo_label: Label
var hint_label: Label
var timer_fill: TextureRect
var timer_back: TextureRect
var pips: Node2D
var stability := 3
var _timer_w := 300.0
var _last_frac := 1.0

var _tex_green: Texture2D
var _tex_yellow: Texture2D
var _tex_red: Texture2D

func _init() -> void:
	layer = 10
	_tex_green = _Util.tex_ui("bar_green")
	_tex_yellow = _Util.tex_ui("bar_yellow")
	_tex_red = _Util.tex_ui("bar_red")

func build() -> void:
	# top strip
	var strip := ColorRect.new()
	strip.color = Color(0.03, 0.04, 0.05, 0.85)
	strip.position = Vector2(0, 0)
	strip.size = Vector2(1280, 44)
	add_child(strip)
	var line := ColorRect.new()
	line.color = Color(0.35, 0.9, 1.0, 0.35)
	line.position = Vector2(0, 44)
	line.size = Vector2(1280, 2)
	add_child(line)

	chamber_label = _Util.make_label("CHAMBER 01", 22, _Util.INK)
	chamber_label.position = Vector2(18, 9)
	add_child(chamber_label)

	# timer, centered
	timer_back = TextureRect.new()
	timer_back.texture = _Util.tex_ui("bar_back")
	timer_back.position = Vector2(490, 12)
	timer_back.size = Vector2(_timer_w, 20)
	timer_back.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(timer_back)
	timer_fill = TextureRect.new()
	timer_fill.texture = _tex_green
	timer_fill.position = Vector2(490, 12)
	timer_fill.size = Vector2(_timer_w, 20)
	timer_fill.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(timer_fill)
	time_label = _Util.make_label("15.0", 20, Color(0.08, 0.09, 0.11), _Util.font_square())
	time_label.position = Vector2(490 + _timer_w * 0.5 - 24, 12)
	add_child(time_label)

	loop_label = _Util.make_label("LOOP 1/3", 22, _Util.CYAN)
	loop_label.position = Vector2(830, 9)
	add_child(loop_label)
	echo_label = _Util.make_label("ECHOES 0", 22, _Util.CYAN_DIM)
	echo_label.position = Vector2(950, 9)
	add_child(echo_label)

	var stab_label := _Util.make_label("STABILITY", 18, Color(0.55, 0.6, 0.66))
	stab_label.position = Vector2(1070, 12)
	add_child(stab_label)
	pips = _Pips.new()
	pips.position = Vector2(1178, 22)
	add_child(pips)

	# hint line near the bottom
	hint_label = _Util.make_label("", 22, Color(0.75, 0.85, 0.92))
	hint_label.position = Vector2(0, 668)
	hint_label.size = Vector2(1280, 30)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint_label)

func set_chamber_title(idx: int, name: String) -> void:
	chamber_label.text = "CHAMBER %02d · %s" % [idx + 1, name]

func set_stability(v: int) -> void:
	stability = v
	pips.stability = v
	pips.queue_redraw()

func tick(st: Dictionary) -> void:
	var frac: float = st["time_left"] / st["loop_time"]
	frac = clampf(frac, 0.0, 1.0)
	if absf(frac - _last_frac) > 0.001:
		_last_frac = frac
		timer_fill.size.x = maxf(2.0, _timer_w * frac)
		timer_fill.texture = _tex_green if frac > 0.5 else (_tex_yellow if frac > 0.25 else _tex_red)
	time_label.text = "%.1f" % st["time_left"]
	loop_label.text = "LOOP %d/%d" % [st["loop"], st["loops_max"]]
	echo_label.text = "ECHOES %d" % st["echoes"]
	hint_label.text = st["hint"]

class _Pips extends Node2D:
	var stability := 3
	func _draw() -> void:
		for i in range(3):
			var x := i * 28.0
			var pts := PackedVector2Array([
				Vector2(x, -9), Vector2(x + 10, 0), Vector2(x, 9), Vector2(x - 10, 0)])
			if i < stability:
				draw_colored_polygon(pts, Color(0.35, 0.9, 1.0))
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.7, 1.0, 1.0), 1.5)
			else:
				draw_colored_polygon(pts, Color(0.16, 0.18, 0.22))
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.9, 0.3, 0.25), 1.5)
