extends CanvasLayer

# All full-screen UI: title, chamber card, clear / paradox / defeat / victory
# panels and the pause menu. Built in code; every screen has a keyboard
# primary action so it can be driven without a mouse.

const _Util = preload("res://scripts/util.gd")

var sfx: Node
var current: Control = null
var primary_btn: Button = null

func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

func _clear() -> void:
	if current != null:
		current.queue_free()
		current = null
		primary_btn = null

func hide_all() -> void:
	_clear()

func has_screen() -> bool:
	return current != null

# ---------------------------------------------------------------- helpers

func _base(dim_alpha: float = 0.0) -> Control:
	_clear()
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	if dim_alpha > 0.0:
		var bg := ColorRect.new()
		bg.color = Color(0.01, 0.015, 0.02, dim_alpha)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.add_child(bg)
	add_child(c)
	current = c
	return c

func _panel(c: Control, w: float, h: float, y_off: float = 0.0) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.12, 0.95)
	sb.border_color = Color(0.35, 0.9, 1.0, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	pc.add_theme_stylebox_override("panel", sb)
	pc.position = Vector2((1280 - w) * 0.5, (720 - h) * 0.5 + y_off)
	pc.custom_minimum_size = Vector2(w, h)
	pc.size = Vector2(w, h)
	c.add_child(pc)
	return pc

func _button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 52)
	b.add_theme_font_override("font", _Util.font_main())
	b.add_theme_font_size_override("font_size", 26)
	var col := _Util.CYAN if primary else Color(0.75, 0.82, 0.9)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.14, 0.18, 0.95) if st != "hover" else Color(0.14, 0.22, 0.28, 0.95)
		sb.border_color = _Util.CYAN if (primary or st == "hover") else Color(0.35, 0.42, 0.5)
		if st == "pressed":
			sb.bg_color = Color(0.2, 0.35, 0.42, 0.95)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func(): sfx.play("click", -6.0))
	if primary:
		primary_btn = b
	return b

func _title_label(c: Control, text: String, size: int, y: float, color: Color = Color.WHITE) -> Label:
	var shadow := _Util.make_label(text, size, Color(0.0, 0.25, 0.3), _Util.font_title())
	shadow.position = Vector2(3, y + 3)
	shadow.size = Vector2(1280, size + 16)
	shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(shadow)
	var l := _Util.make_label(text, size, color, _Util.font_title())
	l.position = Vector2(0, y)
	l.size = Vector2(1280, size + 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l)
	return l

func _center_label(c: Control, text: String, size: int, y: float, color: Color = _Util.INK) -> Label:
	var l := _Util.make_label(text, size, color)
	l.position = Vector2(0, y)
	l.size = Vector2(1280, size + 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l)
	return l

func _pop_in(c: Control) -> void:
	c.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.25)

# ------------------------------------------------------------------ title

func show_title(on_start: Callable, on_quit: Callable) -> void:
	var c := _base()
	# background wash
	var bg := ColorRect.new()
	bg.color = _Util.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	var art := _TitleArt.new()
	c.add_child(art)

	_title_label(c, "ECHO VAULT", 104, 96, _Util.CYAN)
	_center_label(c, "A  T I M E - L O O P  H E I S T", 26, 226, Color(0.65, 0.75, 0.85))
	_center_label(c, "Your past selves hold the doors. Don't get in their way.", 22, 262, Color(0.45, 0.55, 0.65))

	var vb := VBoxContainer.new()
	vb.position = Vector2(490, 420)
	vb.custom_minimum_size = Vector2(300, 160)
	vb.add_theme_constant_override("separation", 14)
	c.add_child(vb)
	var b_start := _button("START THE HEIST", true)
	b_start.pressed.connect(on_start)
	vb.add_child(b_start)
	var b_quit := _button("QUIT")
	b_quit.pressed.connect(on_quit)
	vb.add_child(b_quit)

	_center_label(c, "A/D OR ARROWS — MOVE      SPACE — JUMP      R — REWIND LOOP      ESC — PAUSE",
		18, 664, Color(0.4, 0.5, 0.6))
	_pop_in(c)

# ------------------------------------------------------------- chamber card

func show_card(idx: int, total: int, data: Dictionary, on_done: Callable) -> void:
	var c := _base(0.92)
	var art := _CardArt.new()
	c.add_child(art)
	_title_label(c, "CHAMBER %02d / %02d" % [idx + 1, total], 40, 168, _Util.CYAN)
	_center_label(c, data["name"], 64, 236, Color.WHITE)
	_center_label(c, data["sub"], 24, 322, Color(0.6, 0.7, 0.8))
	_center_label(c, data["objective"], 22, 392, _Util.INK)
	_center_label(c, "LOOPS ALLOWED: %d      LOOP LENGTH: %ds" % [data["loops_max"], int(data["loop_time"])],
		20, 448, Color(0.5, 0.62, 0.72))
	_center_label(c, "PRESS ANY KEY", 18, 560, Color(0.4, 0.5, 0.6))
	_pop_in(c)
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_callback(func():
		if is_instance_valid(c) and current == c:
			on_done.call())

# ------------------------------------------------------------------ clear

func show_clear(idx: int, total: int, loops_used: int, loops_max: int, on_next: Callable) -> void:
	var c := _base(0.72)
	_panel(c, 620, 380, 40)
	_title_label(c, "CHAMBER %02d CLEAR" % [idx + 1], 44, 210, _Util.GREEN)
	_center_label(c, "LOOPS USED: %d / %d" % [loops_used, loops_max], 26, 300, _Util.INK)
	# vault progress lamps
	var lamps := _VaultProgress.new()
	lamps.position = Vector2(640 - (total * 56.0) * 0.5, 360)
	lamps.total = total
	lamps.lit = idx + 1
	c.add_child(lamps)
	_center_label(c, "VAULT PROGRESS", 18, 428, Color(0.5, 0.62, 0.72))
	var b := _button("NEXT CHAMBER", true)
	b.position = Vector2(490, 480)
	b.pressed.connect(on_next)
	c.add_child(b)
	_pop_in(c)

# ----------------------------------------------------------------- paradox

func show_paradox(stability: int, on_retry: Callable) -> void:
	var c := _base(0.55)
	var art := _GlitchArt.new()
	c.add_child(art)
	_title_label(c, "P A R A D O X", 96, 210, _Util.RED)
	_center_label(c, "You got in your own way. The timeline tears.", 24, 340, _Util.INK)
	_center_label(c, "STABILITY -1   —   %d REMAINING" % stability, 24, 384, _Util.RED)
	_center_label(c, "CHAMBER RESETS TO LOOP 1", 20, 424, Color(0.7, 0.6, 0.6))
	var b := _button("RESTITCH THE TIMELINE", true)
	b.position = Vector2(490, 500)
	b.pressed.connect(on_retry)
	c.add_child(b)
	_pop_in(c)

func show_loops_out(stability: int, on_retry: Callable) -> void:
	var c := _base(0.55)
	_title_label(c, "LOOPS EXHAUSTED", 64, 220, _Util.RED)
	_center_label(c, "Too many rewinds. The chamber rejects the timeline.", 24, 330, _Util.INK)
	_center_label(c, "STABILITY -1   —   %d REMAINING" % stability, 24, 374, _Util.RED)
	var b := _button("RESTART CHAMBER", true)
	b.position = Vector2(490, 470)
	b.pressed.connect(on_retry)
	c.add_child(b)
	_pop_in(c)

# ------------------------------------------------------------------ defeat

func show_defeat(on_retry: Callable, on_title: Callable) -> void:
	var c := _base(0.8)
	_title_label(c, "TIMELINE COLLAPSED", 60, 200, _Util.RED)
	_center_label(c, "The vault seals itself. Every echo fades.", 24, 300, _Util.INK)
	var vb := VBoxContainer.new()
	vb.position = Vector2(490, 400)
	vb.custom_minimum_size = Vector2(300, 130)
	vb.add_theme_constant_override("separation", 14)
	c.add_child(vb)
	var b_retry := _button("RETRY THE HEIST", true)
	b_retry.pressed.connect(on_retry)
	vb.add_child(b_retry)
	var b_title := _button("BACK TO TITLE")
	b_title.pressed.connect(on_title)
	vb.add_child(b_title)
	_pop_in(c)

# ----------------------------------------------------------------- victory

func show_victory(total_loops: int, on_again: Callable, on_title: Callable) -> void:
	var c := _base()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	var art := _VaultArt.new()
	c.add_child(art)
	_title_label(c, "VAULT BREACHED", 84, 130, _Util.GREEN)
	_center_label(c, "Three chambers. One perfect timeline.", 26, 250, _Util.INK)
	_center_label(c, "TOTAL LOOPS USED: %d" % total_loops, 24, 320, _Util.CYAN)
	var vb := VBoxContainer.new()
	vb.position = Vector2(490, 470)
	vb.custom_minimum_size = Vector2(300, 130)
	vb.add_theme_constant_override("separation", 14)
	c.add_child(vb)
	var b_again := _button("RUN IT AGAIN", true)
	b_again.pressed.connect(on_again)
	vb.add_child(b_again)
	var b_title := _button("BACK TO TITLE")
	b_title.pressed.connect(on_title)
	vb.add_child(b_title)
	_pop_in(c)

# ------------------------------------------------------------------- pause

func show_pause(on_resume: Callable, on_restart: Callable, on_title: Callable) -> void:
	var c := _base(0.65)
	_title_label(c, "PAUSED", 54, 170, _Util.CYAN)
	var vb := VBoxContainer.new()
	vb.position = Vector2(490, 300)
	vb.custom_minimum_size = Vector2(300, 220)
	vb.add_theme_constant_override("separation", 14)
	c.add_child(vb)
	var b_resume := _button("RESUME", true)
	b_resume.pressed.connect(on_resume)
	vb.add_child(b_resume)
	var b_restart := _button("RESTART CHAMBER")
	b_restart.pressed.connect(on_restart)
	vb.add_child(b_restart)
	var b_title := _button("QUIT TO TITLE")
	b_title.pressed.connect(on_title)
	vb.add_child(b_title)
	_pop_in(c)

# ------------------------------------------------------------- decorations

class _TitleArt extends Node2D:
	var _t := 0.0
	var _robot: Sprite2D
	var _ghosts: Array = []
	func _ready() -> void:
		_robot = Sprite2D.new()
		_robot.texture = load("res://assets/robot/robot_blueBody.png")
		_robot.scale = Vector2(0.5, 0.5)
		_robot.position = Vector2(640, 392)
		add_child(_robot)
		for i in range(2):
			var g := Sprite2D.new()
			g.texture = load("res://assets/robot/robot_blueBody.png")
			g.scale = Vector2(0.5, 0.5)
			g.modulate = Color(0.45, 0.95, 1.0, 0.4)
			add_child(g)
			_ghosts.append(g)
	func _process(delta: float) -> void:
		_t += delta
		_robot.position.y = 392 + sin(_t * 1.7) * 4.0
		for i in range(_ghosts.size()):
			var g: Sprite2D = _ghosts[i]
			var dir := -1.0 if i == 0 else 1.0
			g.position = Vector2(640 + dir * (90 + 20 * sin(_t * 1.1 + i)), 392 + sin(_t * 2.1 + i * 2.0) * 6.0)
			g.modulate.a = 0.25 + 0.18 * sin(_t * 3.0 + i * 1.7)
		queue_redraw()
	func _draw() -> void:
		# vault wheel behind the robots
		var c := Vector2(640, 400)
		draw_circle(c, 118, Color(0.09, 0.11, 0.14))
		draw_arc(c, 118, 0, TAU, 64, Color(0.35, 0.9, 1.0, 0.5), 3.0)
		draw_arc(c, 88, 0, TAU, 64, Color(0.3, 0.4, 0.48), 2.0)
		for i in range(6):
			var a := _t * 0.15 + i * TAU / 6.0
			draw_line(c + Vector2.from_angle(a) * 30, c + Vector2.from_angle(a) * 108, Color(0.25, 0.32, 0.38), 6.0)
		draw_circle(c, 26, Color(0.16, 0.2, 0.24))
		draw_arc(c, 26, 0, TAU, 32, Color(0.35, 0.9, 1.0, 0.7), 2.0)
		# floor line
		draw_line(Vector2(320, 434), Vector2(960, 434), Color(0.3, 0.38, 0.45), 3.0)

class _CardArt extends Node2D:
	func _draw() -> void:
		draw_line(Vector2(340, 530), Vector2(940, 530), Color(0.35, 0.9, 1.0, 0.4), 2.0)
		for i in range(9):
			var c := Color(0.85, 0.68, 0.15, 0.6) if i % 2 == 0 else Color(0.12, 0.13, 0.15, 0.6)
			draw_rect(Rect2(360 + i * 64, 538, 64, 8), c)

class _GlitchArt extends Node2D:
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		for i in range(5):
			var y: float = 160 + i * 90 + sin(_t * (3.0 + i)) * 8.0
			var w: float = 300 + 160 * absf(sin(_t * 1.3 + i * 2.2))
			draw_rect(Rect2(640 - w * 0.5, y, w, 3), Color(1.0, 0.25, 0.2, 0.12 + 0.1 * absf(sin(_t * 7.0 + i))))

class _VaultProgress extends Node2D:
	var total := 3
	var lit := 1
	func _draw() -> void:
		for i in range(total):
			var x := i * 56.0
			var on := i < lit
			var col: Color = Color(0.35, 0.9, 1.0) if on else Color(0.16, 0.18, 0.22)
			draw_circle(Vector2(x, 0), 16, Color(col.r, col.g, col.b, 0.25))
			draw_circle(Vector2(x, 0), 10, col)
			if on:
				draw_circle(Vector2(x, 0), 4, Color.WHITE)

class _VaultArt extends Node2D:
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var c := Vector2(640, 400)
		var open: float = minf(1.0, _t * 0.5)
		# glow from inside the vault
		draw_circle(c, 150 + 30 * sin(_t * 2.0), Color(1.0, 0.85, 0.4, 0.06 + 0.10 * open))
		draw_circle(c, 90, Color(1.0, 0.85, 0.4, 0.10 + 0.22 * open))
		# two door halves sliding apart
		var slide: float = 90.0 * open
		for s in [-1.0, 1.0]:
			var cx: float = c.x + s * (44 + slide)
			draw_rect(Rect2(cx - 44, c.y - 100, 88, 200), Color(0.14, 0.17, 0.21))
			draw_rect(Rect2(cx - 44, c.y - 100, 88, 8), Color(0.35, 0.9, 1.0, 0.6))
			for i in range(4):
				draw_circle(Vector2(cx, c.y - 70 + i * 46), 3.0, Color(0.3, 0.35, 0.4))
