extends Node2D

# One vault chamber: terrain, devices, the live player, echo replays, and the
# loop clock. Everything gameplay-related ticks from _physics_process in a
# fixed manual order so replays are perfectly deterministic.

signal sig_cleared
signal sig_paradox
signal sig_laser_death
signal sig_rewind_requested(auto: bool)

const _Util = preload("res://scripts/util.gd")
const _Devices = preload("res://scripts/devices.gd")
const _Player = preload("res://scripts/player.gd")
const _Echo = preload("res://scripts/echo.gd")

const PARADOX_GRACE_TICKS := 18
const PARADOX_MIN_PEN := 6.0
const GLITCH_DIST := 70.0

var data: Dictionary
var sfx: Node

var mode := "idle"  # idle | play | frozen
var loop_idx := 1
var tick_idx := 0
var loop_ticks := 1200
var recordings: Array = []
var current_rec: Array = []

var player: CharacterBody2D
var echoes: Array = []
var plates: Array = []
var doors: Array = []
var lift = null
var lasers: Array = []
var exit_rect := Rect2()
var exit_door = null
var spawn := Vector2(185, 640)
var hint_text := ""

var _player_prev := Vector2.ZERO
var _plate_states := {}
var _last_warn_sec := -1
var _rew_prev := false
var _wires: Node2D
var _rng := RandomNumberGenerator.new()

func setup(p_data: Dictionary, p_sfx: Node) -> void:
	data = p_data
	sfx = p_sfx
	_rng.seed = 20261008
	spawn = data["spawn"]
	exit_rect = data["exit"]
	loop_ticks = int(round(data["loop_time"] * 60.0))
	_build_terrain()
	_build_decor()
	_build_devices()
	_build_spawn_marker()
	player = _Player.new()
	player._sfx = sfx
	add_child(player)
	player.reset_at(spawn)

# ------------------------------------------------------------------ build

func _build_terrain() -> void:
	var grid: Array = data["grid"]
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var tiles := Node2D.new()
	tiles.z_index = -2
	add_child(tiles)
	for row in range(grid.size()):
		var line: String = grid[row]
		for col in range(line.length()):
			var tl := _Util.cell_topleft(col, row)
			if line[col] == "#" or line[col] == "=":
				var shape := CollisionShape2D.new()
				var r := RectangleShape2D.new()
				r.size = Vector2(_Util.TILE, _Util.TILE)
				shape.shape = r
				shape.position = tl + Vector2(35, 35)
				if line[col] == "=":
					shape.one_way_collision = true
				body.add_child(shape)
				var s := Sprite2D.new()
				if line[col] == "=":
					s.texture = _Util.tex_tile("016")
				else:
					var below_open: bool = row + 1 < grid.size() and String(grid[row + 1])[col] == "."
					s.texture = _Util.tex_tile("015" if below_open else ("067" if (col + row) % 2 == 0 else "094"))
				s.position = tl + Vector2(35, 35)
				tiles.add_child(s)
			else:
				# dark wall panels behind the play space
				var s := Sprite2D.new()
				var pick := "090"
				var h: int = (col * 7 + row * 13) % 6
				if h == 1:
					pick = "034"
				elif h == 2:
					pick = "085"
				s.texture = _Util.tex_tile(pick)
				s.modulate = Color(0.30, 0.33, 0.40, 1.0)
				s.position = tl + Vector2(35, 35)
				s.z_index = -8
				tiles.add_child(s)

func _build_decor() -> void:
	var decor := Node2D.new()
	decor.z_index = -4
	add_child(decor)
	# ceiling cables
	for col in range(2, 16, 3):
		var s := Sprite2D.new()
		s.texture = _Util.tex_tile("012" if col % 2 == 0 else "010")
		s.position = _Util.cell_center(col, 0) + Vector2(0, 44)
		s.modulate = Color(0.7, 0.75, 0.85)
		decor.add_child(s)
	# wall lamps at a few fixed spots
	for cell in [Vector2i(4, 2), Vector2i(13, 2)]:
		var lamp := Sprite2D.new()
		lamp.texture = _Util.tex_tile("084")
		lamp.position = _Util.cell_center(cell.x, cell.y)
		decor.add_child(lamp)
		var glow := _GlowDot.new()
		glow.position = lamp.position + Vector2(0, 18)
		glow.color = Color(1.0, 0.85, 0.5, 0.10)
		glow.radius = 46.0
		decor.add_child(glow)

func _build_spawn_marker() -> void:
	var m := Node2D.new()
	m.position = Vector2(spawn.x, spawn.y)
	m.z_index = -1
	add_child(m)
	# entry conduit: pure decoration drawn inline
	var d := _EntryMarker.new()
	m.add_child(d)

func _build_devices() -> void:
	# plates
	for pd in data["plates"]:
		var p = _Devices.Plate.new()
		p.setup(pd["id"], pd["color"], pd["pos"].x, pd["pos"].y)
		add_child(p)
		plates.append(p)
		_plate_states[p.id] = false
	# doors
	for dd in data["doors"]:
		var door = _Devices.Door.new()
		door.setup(dd["id"], dd["color"], dd["plates"], dd["col"], dd["row"])
		add_child(door)
		doors.append(door)
		if dd.get("exit", false):
			exit_door = door
	# lift
	if data["lift"] != null:
		var ld: Dictionary = data["lift"]
		lift = _Devices.Lift.new()
		lift.setup(ld["color"], ld["center_x"], ld["base_y"], ld["top_y"])
		add_child(lift)
	# lasers
	for ld in data["lasers"]:
		var l = _Devices.Laser.new()
		l.setup(ld["x"], ld["y0"], ld["y1"], ld["period"], ld["off"], ld["warn"], ld["offset"])
		add_child(l)
		lasers.append(l)
	# wires from every plate to its device
	_wires = _Wires.new()
	add_child(_wires)
	_wires.z_index = -6
	for p in plates:
		var target := Vector2.ZERO
		var found := false
		for door in doors:
			if p.id in door.plate_ids:
				target = door.position + Vector2(35, 10)
				found = true
		if lift != null and data["lift"]["plate"] == p.id:
			target = Vector2(lift.position.x, lift.top_y + 6)
			found = true
		if found:
			_wires.add_route(p.position + Vector2(0, 6), target, p.color)
	# exit field decoration for door-less exits
	if exit_door == null:
		var f := _ExitField.new()
		f.rect = exit_rect
		add_child(f)

# ------------------------------------------------------------------ loops

func begin_loop(n: int) -> void:
	loop_idx = n
	tick_idx = 0
	current_rec = []
	hint_text = ""
	_last_warn_sec = -1
	player.reset_at(spawn)
	player.active = true
	_player_prev = spawn
	if lift != null:
		lift.reset()
	for l in lasers:
		l.update_clock(0.0)
		l.state = "off"
		l.queue_redraw()
	for d in doors:
		d.open_amount = 0.0
		d.shape.disabled = false
		d.queue_redraw()
	for k in _plate_states:
		_plate_states[k] = false
	for p in plates:
		p.set_pressed(false)
		p._blend = 0.0
		p.queue_redraw()
	_rebuild_echoes()
	mode = "play"

func _rebuild_echoes() -> void:
	for e in echoes:
		e.queue_free()
	echoes.clear()
	for i in range(recordings.size()):
		var e = _Echo.new()
		e.number = i + 1
		add_child(e)
		var rec: Array = recordings[i]
		e.set_frame(rec[0])
		echoes.append(e)
	if recordings.size() > 0:
		sfx.play("echo_spawn", -8.0)

func finish_recording() -> void:
	if current_rec.size() > 0:
		recordings.append(current_rec)

func discard_recording() -> void:
	current_rec = []

func restart_all() -> void:
	recordings.clear()
	current_rec = []
	begin_loop(1)

func freeze() -> void:
	mode = "frozen"
	player.active = false

func unfreeze() -> void:
	if mode == "frozen":
		mode = "play"
		player.active = true

# ------------------------------------------------------------------- tick

func _physics_process(delta: float) -> void:
	if mode != "play":
		return
	var t_now: float = tick_idx / 60.0

	# 1) plate states from current geometry (end of previous tick)
	_update_plate_states()
	# 2) doors
	for d in doors:
		var all := true
		for pid in d.plate_ids:
			if not _plate_states.get(pid, false):
				all = false
		d.tick(delta, all, player.body_rect().intersects(d.frame_rect.grow(2.0)))
	# 3) lift: move, then carry the player
	if lift != null:
		var powered: bool = _plate_states.get(data["lift"]["plate"], false)
		var can_descend: bool = not player.body_rect().intersects(lift.rect_below())
		lift.tick(delta, powered, can_descend)
		if lift.last_delta != 0.0 and _is_riding_lift():
			player.global_position.y += lift.last_delta
	# 4) player physics
	player.do_physics(delta)
	# 5) record
	current_rec.append([player.global_position.x, player.global_position.y, player.face, player.anim])
	# 6) echoes replay
	var phase: float = t_now
	for e in echoes:
		var rec: Array = recordings[e.number - 1]
		var fi: int = mini(tick_idx, rec.size() - 1)
		var old_pos: Vector2 = e.global_position
		e.set_frame(rec[fi])
		e.set_meta("prev", old_pos)
	# 7) immediate plate feedback + animation
	_update_plate_states()
	for p in plates:
		p.set_pressed(_plate_states[p.id])
		p.tick_anim(delta)
	# 8) laser clock + hit
	var loop_t: float = tick_idx / 60.0
	for l in lasers:
		l.update_clock(loop_t)
		l.tick_visual(delta)
		if l.is_deadly() and player.body_rect().grow(-3.0).intersects(l.beam_rect()):
			_on_laser_death()
			return
	# 9) paradox
	if _check_paradox():
		return
	# 10) exit
	if _check_exit():
		return
	# 11) timer
	tick_idx += 1
	var remain: float = (loop_ticks - tick_idx) / 60.0
	var whole := int(ceil(remain))
	if whole <= 5 and whole != _last_warn_sec and whole >= 1:
		_last_warn_sec = whole
		sfx.play("timer_warn", -12.0, 1.4)
	if tick_idx >= loop_ticks:
		_request_rewind(true)
		return
	# 12) manual rewind (edge on level state)
	var rew := Input.is_action_pressed("ev_rewind")
	if rew and not _rew_prev:
		_rew_prev = rew
		_request_rewind(false)
		return
	_rew_prev = rew
	_update_hint()

func _request_rewind(auto: bool) -> void:
	freeze()
	emit_signal("sig_rewind_requested", auto)

func _update_plate_states() -> void:
	var bodies: Array = [player.body_rect()]
	for e in echoes:
		bodies.append(e.body_rect())
	for p in plates:
		var on := false
		for b in bodies:
			if b.intersects(p.press_rect):
				on = true
				break
		_plate_states[p.id] = on

func _is_riding_lift() -> bool:
	if lift == null:
		return false
	var feet := Rect2(player.global_position + Vector2(-14, 22), Vector2(28, 6))
	return feet.intersects(Rect2(lift.position.x - lift.width * 0.5, lift.surface_y - 4.0, lift.width, 8.0)) and player.velocity.y >= -20.0

func _check_paradox() -> bool:
	if tick_idx < PARADOX_GRACE_TICKS:
		_update_glitch()
		return false
	var rp: Rect2 = player.body_rect().grow(-4.0)
	var p_vel: Vector2 = player.global_position - _player_prev
	_player_prev = player.global_position
	for e in echoes:
		var re: Rect2 = e.body_rect().grow(-4.0)
		if not rp.intersects(re):
			continue
		var inter: Rect2 = rp.intersection(re)
		if inter.size.x < PARADOX_MIN_PEN or inter.size.y < PARADOX_MIN_PEN:
			continue
		var ce := re.get_center()
		var cp := rp.get_center()
		var e_vel: Vector2 = e.global_position - e.get_meta("prev", e.global_position)
		var echo_into := e_vel.dot(cp - ce) > 0.6
		var player_into := p_vel.dot(ce - cp) > 0.6
		if echo_into or player_into:
			_on_paradox(e)
			return true
	_update_glitch()
	return false

func _update_glitch() -> void:
	var cp: Vector2 = player.global_position
	for e in echoes:
		var d: float = (e.global_position - cp).length()
		e.glitch = clampf(1.0 - (d - 34.0) / GLITCH_DIST, 0.0, 1.0)
		e.tick_visual(tick_idx / 60.0)

func _on_paradox(echo) -> void:
	freeze()
	echo.glitch = 1.0
	echo.tick_visual(tick_idx / 60.0)
	player.play_hurt()
	emit_signal("sig_paradox")

func _on_laser_death() -> void:
	freeze()
	player.play_hurt()
	emit_signal("sig_laser_death")

func _check_exit() -> bool:
	var passable := true
	if exit_door != null:
		passable = exit_door.open_amount > 0.7
	if passable and player.body_rect().intersects(exit_rect):
		freeze()
		emit_signal("sig_cleared")
		return true
	return false

func _update_hint() -> void:
	var t: float = tick_idx / 60.0
	hint_text = ""
	if loop_idx == 1:
		for h in data["hints"]:
			if t < h["until"]:
				hint_text = h["text"]
	elif loop_idx == 2:
		hint_text = data.get("hint_loop2", "")
	else:
		hint_text = data.get("hint_loop3", "")

# ------------------------------------------------------------------ state

func time_left() -> float:
	return maxf(0.0, (loop_ticks - tick_idx) / 60.0)

func get_state() -> Dictionary:
	return {
		"loop": loop_idx,
		"loops_max": data["loops_max"],
		"time_left": time_left(),
		"loop_time": data["loop_time"],
		"echoes": recordings.size(),
		"hint": hint_text,
	}

# ------------------------------------------------------------ draw helpers

class _GlowDot extends Node2D:
	var color := Color(1, 1, 1, 0.1)
	var radius := 40.0
	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius * 0.5, Color(color.r, color.g, color.b, color.a * 1.6))

class _EntryMarker extends Node2D:
	func _draw() -> void:
		# dark entry conduit behind the spawn point
		draw_rect(Rect2(-34, -140, 68, 140), Color(0.05, 0.06, 0.08))
		draw_rect(Rect2(-38, -140, 6, 140), Color(0.2, 0.23, 0.27))
		draw_rect(Rect2(32, -140, 6, 140), Color(0.2, 0.23, 0.27))
		draw_rect(Rect2(-38, -146, 76, 8), Color(0.2, 0.23, 0.27))
		for i in range(4):
			var c := Color(0.85, 0.68, 0.15) if i % 2 == 0 else Color(0.12, 0.13, 0.15)
			draw_rect(Rect2(-36 + i * 19, -146, 19, 4), c)

class _Wires extends Node2D:
	var routes: Array = []
	func add_route(a: Vector2, b: Vector2, color: Color) -> void:
		routes.append({"a": a, "b": b, "color": color})
		queue_redraw()
	func _draw() -> void:
		for r in routes:
			var a: Vector2 = r["a"]
			var b: Vector2 = r["b"]
			var mid_y := 628.0
			var pts := PackedVector2Array()
			pts.append(a)
			pts.append(Vector2(a.x, mid_y))
			pts.append(Vector2(b.x, mid_y))
			pts.append(b)
			var glow: Color = Color(r["color"].r, r["color"].g, r["color"].b, 0.18)
			draw_polyline(pts, glow, 9.0)
			draw_polyline(pts, r["color"], 3.0)

class _ExitField extends Node2D:
	var rect := Rect2()
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		# posts
		draw_rect(Rect2(rect.position.x - 8, rect.position.y - 10, 8, rect.size.y + 10), Color(0.2, 0.23, 0.27))
		draw_rect(Rect2(rect.end.x, rect.position.y - 10, 8, rect.size.y + 10), Color(0.2, 0.23, 0.27))
		# shimmering field
		for i in range(8):
			var yy: float = rect.position.y + fposmod(_t * 40.0 + i * 17.0, rect.size.y)
			draw_rect(Rect2(rect.position.x, yy, rect.size.x, 2.5), Color(0.35, 0.9, 1.0, 0.35))
		draw_rect(rect, Color(0.35, 0.9, 1.0, 0.08))
