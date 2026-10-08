extends RefCounted

# Interactive devices. All custom-drawn Node2D classes; collision with the
# player uses plain rectangle math driven by the chamber, so every tick is
# deterministic.

const _Util = preload("res://scripts/util.gd")

# ---------------------------------------------------------------- Plate
class Plate extends Node2D:
	var id := "A"
	var color := _Util.AMBER
	var pressed := false
	var press_rect := Rect2()  # world-space zone that counts as "standing on it"
	var letter: Label
	var _blend := 0.0  # animated 0..1

	func setup(p_id: String, p_color: Color, center_x: float, floor_y: float) -> void:
		id = p_id
		color = p_color
		position = Vector2(center_x, floor_y)
		press_rect = Rect2(center_x - 40.0, floor_y - 12.0, 80.0, 14.0)
		letter = _Util.make_label(id, 22, Color(0.08, 0.09, 0.11), _Util.font_square())
		letter.position = Vector2(-7, -22)
		letter.z_index = 6
		add_child(letter)

	func set_pressed(p: bool) -> void:
		pressed = p

	func tick_anim(delta: float) -> void:
		var target := 1.0 if pressed else 0.0
		var nb: float = move_toward(_blend, target, delta * 10.0)
		if nb != _blend:
			_blend = nb
			queue_redraw()
			letter.position.y = -22 + 4.0 * _blend

	func _draw() -> void:
		# base plate bolted to the ground
		draw_rect(Rect2(-34, -6, 68, 6), Color(0.13, 0.15, 0.18))
		draw_rect(Rect2(-34, -6, 68, 2), Color(0.3, 0.33, 0.38))
		# pad sinks when pressed
		var pad_y := -12.0 + 5.0 * _blend
		var pad_col: Color = color if pressed else _Util.dim(color, 0.55)
		draw_rect(Rect2(-28, pad_y, 56, 7), pad_col)
		draw_rect(Rect2(-28, pad_y, 56, 2), pad_col.lightened(0.35))
		# side lamps
		var lamp: Color = color if pressed else Color(0.2, 0.22, 0.25)
		draw_circle(Vector2(-38, -4), 3.5, lamp)
		draw_circle(Vector2(38, -4), 3.5, lamp)

# ----------------------------------------------------------------- Door
class Door extends Node2D:
	var id := "D"
	var color := _Util.AMBER
	var plate_ids: Array = []
	var open_amount := 0.0  # 0 closed .. 1 open
	var powered := false
	var frame_rect := Rect2()  # world rect of the doorway
	var letter: Label
	var body: StaticBody2D
	var shape: CollisionShape2D
	var _glow := 0.0

	const W := 70.0
	const H := 140.0

	func setup(p_id: String, p_color: Color, p_plates: Array, col: int, top_row: int) -> void:
		id = p_id
		color = p_color
		plate_ids = p_plates.duplicate()
		var tl := _Util.cell_topleft(col, top_row)
		position = tl
		frame_rect = Rect2(tl, Vector2(W, H))
		body = StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		shape = CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(W - 8.0, H)
		shape.shape = r
		shape.position = Vector2(W * 0.5, H * 0.5)
		body.add_child(shape)
		add_child(body)
		letter = _Util.make_label("+".join(plate_ids), 20, _Util.INK, _Util.font_square())
		letter.position = Vector2(W * 0.5 - 8.0 * plate_ids.size(), -34)
		add_child(letter)

	func tick(delta: float, all_pressed: bool, blocked: bool) -> void:
		powered = all_pressed
		var target := 1.0 if powered else 0.0
		# never crush someone standing in the doorway
		if target < open_amount and blocked and open_amount < 0.75:
			target = maxf(target, 0.75)
		var prev := open_amount
		open_amount = move_toward(open_amount, target, delta * 3.2)
		if prev != open_amount:
			queue_redraw()
		shape.disabled = open_amount >= 0.6

	func _draw() -> void:
		# recessed doorway glow
		var glow_col := Color(color.r, color.g, color.b, 0.10 + 0.30 * open_amount)
		draw_rect(Rect2(4, 4, W - 8, H - 4), glow_col)
		# sliding panel
		var panel_h: float = (H - 10.0) * (1.0 - open_amount)
		if panel_h > 2.0:
			var pr := Rect2(5, H - 5 - panel_h, W - 10, panel_h)
			draw_rect(pr, Color(0.16, 0.19, 0.23))
			draw_rect(Rect2(pr.position, Vector2(pr.size.x, 4)), _Util.dim(color, 0.8))
			draw_rect(Rect2(pr.position + Vector2(0, pr.size.y - 4), Vector2(pr.size.x, 4)), Color(0.06, 0.07, 0.09))
			# rivets
			for ry in range(int(panel_h) / 26):
				draw_circle(Vector2(12, pr.position.y + 12 + ry * 26), 2.0, Color(0.32, 0.36, 0.42))
				draw_circle(Vector2(W - 12, pr.position.y + 12 + ry * 26), 2.0, Color(0.32, 0.36, 0.42))
		# frame posts with hazard stripes
		_draw_post(Rect2(-6, -6, 10, H + 6))
		_draw_post(Rect2(W - 4, -6, 10, H + 6))
		# lintel
		draw_rect(Rect2(-6, -10, W + 12, 8), Color(0.2, 0.23, 0.27))
		# status lamp
		var lamp: Color = _Util.GREEN if powered else _Util.RED
		draw_circle(Vector2(W * 0.5, -14), 5.0, lamp)
		draw_circle(Vector2(W * 0.5, -14), 2.5, lamp.lightened(0.6))

	func _draw_post(r: Rect2) -> void:
		draw_rect(r, Color(0.2, 0.23, 0.27))
		var n := int(r.size.y / 14.0)
		for i in range(n):
			var c := Color(0.85, 0.68, 0.15) if i % 2 == 0 else Color(0.12, 0.13, 0.15)
			draw_rect(Rect2(r.position + Vector2(1, i * 14), Vector2(r.size.x - 2, 7)), c)

# ----------------------------------------------------------------- Lift
class Lift extends Node2D:
	var color := _Util.BLUE
	var surface_y := 640.0      # current platform top (world)
	var base_y := 640.0
	var top_y := 220.0
	var width := 130.0
	var powered := false
	var dwell := 0.0            # spool-up time before first rise
	var last_delta := 0.0       # movement applied this tick (for carrying)
	var body: StaticBody2D
	var shape: CollisionShape2D
	var _light_phase := 0.0

	const RISE_SPEED := 75.0
	const FALL_SPEED := 55.0
	const DWELL_TIME := 0.8

	func setup(p_color: Color, center_x: float, p_base_y: float, p_top_y: float) -> void:
		color = p_color
		position = Vector2(center_x, 0)
		base_y = p_base_y
		top_y = p_top_y
		surface_y = base_y
		body = StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		shape = CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(width, 16.0)
		shape.shape = r
		body.add_child(shape)
		add_child(body)
		_sync_body()

	func rect_top() -> Rect2:
		return Rect2(position.x - width * 0.5, surface_y - 4.0, width, 20.0)

	func rect_below() -> Rect2:
		return Rect2(position.x - width * 0.5 + 6.0, surface_y + 16.0, width - 12.0, 46.0)

	func reset() -> void:
		surface_y = base_y
		dwell = 0.0
		last_delta = 0.0
		_sync_body()

	func tick(delta: float, p_powered: bool, can_descend: bool) -> void:
		powered = p_powered
		last_delta = 0.0
		if powered:
			dwell += delta
			if dwell >= DWELL_TIME and surface_y > top_y:
				last_delta = -minf(RISE_SPEED * delta, surface_y - top_y)
		else:
			dwell = 0.0
			if surface_y < base_y and can_descend:
				last_delta = minf(FALL_SPEED * delta, base_y - surface_y)
		if last_delta != 0.0:
			surface_y += last_delta
			_sync_body()
		_light_phase += delta

	func _sync_body() -> void:
		body.position = Vector2(0, surface_y + 8.0)
		queue_redraw()

	func _draw() -> void:
		var y := surface_y
		# cables up the shaft
		draw_line(Vector2(-width * 0.5 + 12, 80), Vector2(-width * 0.5 + 12, y), Color(0.16, 0.18, 0.21), 3.0)
		draw_line(Vector2(width * 0.5 - 12, 80), Vector2(width * 0.5 - 12, y), Color(0.16, 0.18, 0.21), 3.0)
		# platform
		draw_rect(Rect2(-width * 0.5, y, width, 14), Color(0.22, 0.25, 0.3))
		draw_rect(Rect2(-width * 0.5, y, width, 3), _Util.dim(color, 1.0 if powered else 0.45))
		draw_rect(Rect2(-width * 0.5 + 6, y + 14, width - 12, 6), Color(0.12, 0.14, 0.17))
		# edge chevrons
		for i in range(6):
			var cx := -width * 0.5 + 10.0 + i * 22.0
			var c := Color(0.85, 0.68, 0.15) if i % 2 == 0 else Color(0.12, 0.13, 0.15)
			draw_rect(Rect2(cx, y + 3.5, 11, 4), c)
		# power lamp
		var lamp: Color = color if powered else Color(0.2, 0.22, 0.25)
		draw_circle(Vector2(0, y + 10), 3.5, lamp)

# ---------------------------------------------------------------- Laser
class Laser extends Node2D:
	var x := 0.0
	var y0 := 80.0
	var y1 := 640.0
	var period := 2.6
	var off_len := 1.0
	var warn_len := 0.3
	var phase_offset := 0.0
	var state := "off"  # off | warn | on
	var _blink := 0.0

	func setup(p_x: float, p_y0: float, p_y1: float, p_period: float, p_off: float, p_warn: float, p_offset: float) -> void:
		x = p_x
		y0 = p_y0
		y1 = p_y1
		period = p_period
		off_len = p_off
		warn_len = p_warn
		phase_offset = p_offset

	func update_clock(loop_t: float) -> void:
		var t: float = fposmod(loop_t + phase_offset, period)
		var new_state := "on"
		if t < off_len:
			new_state = "off"
		elif t < off_len + warn_len:
			new_state = "warn"
		if new_state != state:
			state = new_state
			queue_redraw()

	func beam_rect() -> Rect2:
		return Rect2(x - 9.0, y0, 18.0, y1 - y0)

	func is_deadly() -> bool:
		return state == "on"

	func tick_visual(delta: float) -> void:
		_blink += delta
		queue_redraw()

	func _draw() -> void:
		# floor warning stripe
		for i in range(2):
			var c := Color(0.85, 0.68, 0.15, 0.8) if i % 2 == 0 else Color(0.12, 0.13, 0.15, 0.8)
			draw_rect(Rect2(x - 22 + i * 22, y1 - 6, 22, 6), c)
		# emitter boxes
		draw_rect(Rect2(x - 12, y0 - 12, 24, 16), Color(0.18, 0.21, 0.25))
		draw_rect(Rect2(x - 12, y1 - 4, 24, 16), Color(0.18, 0.21, 0.25))
		var lens := _Util.RED if state != "off" else Color(0.3, 0.32, 0.35)
		draw_circle(Vector2(x, y0 + 2), 4.0, lens)
		draw_circle(Vector2(x, y1 - 2), 4.0, lens)
		if state == "on":
			var flick := 0.85 + 0.15 * sin(_blink * 47.0)
			draw_rect(Rect2(x - 10, y0, 20, y1 - y0), Color(1.0, 0.15, 0.1, 0.28 * flick))
			draw_rect(Rect2(x - 4, y0, 8, y1 - y0), Color(1.0, 0.3, 0.2, 0.75 * flick))
			draw_rect(Rect2(x - 1.5, y0, 3, y1 - y0), Color(1.0, 0.85, 0.8, 0.95 * flick))
		elif state == "warn":
			var a: float = 0.25 + 0.35 * absf(sin(_blink * 18.0))
			draw_rect(Rect2(x - 2, y0, 4, y1 - y0), Color(1.0, 0.3, 0.2, a))
		else:
			# faint dotted guide while safe
			var dy := y0 + 8.0
			while dy < y1 - 8.0:
				draw_rect(Rect2(x - 1.5, dy, 3, 6), Color(1.0, 0.35, 0.25, 0.16))
				dy += 16.0
