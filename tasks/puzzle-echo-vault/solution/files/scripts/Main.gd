extends Node2D
# Echo Vault — reference solution.
# Fixed-tick simulation (60 Hz) so echoes re-simulate their recorded inputs
# exactly. Each loop starts on the player's first input, which anchors
# replayed demo traces regardless of engine startup time.

const TS := 36
const COLS := 35
const ROWS := 20
const OX := 10.0
const FLOOR_Y := 612.0
const RUN := 220.0
const GRAV := 1700.0
const JUMP := 620.0
const MAXFALL := 900.0
const BW := 26.0
const BH := 40.0
const DT := 1.0 / 60.0
const IN_L := 1
const IN_R := 2
const IN_J := 4
const IN_E := 8
const GATE_TIME := 3.0
const LIFT_SPEED := 2.0 # px per tick
const DIVERGE := 6.0
const REWIND_TIME := 0.9
const INTRO_TIME := 1.8

const T_EMPTY := 0
const T_SOLID := 1
const T_PLAT := 2
const T_CRATE := 3

const ECHO_COLORS := [Color(0.35, 0.92, 1.0), Color(1.0, 0.45, 0.9), Color(1.0, 0.8, 0.3)]
const LINK_COLORS := [Color(0.3, 0.85, 1.0), Color(1.0, 0.6, 0.2), Color(0.75, 0.45, 1.0)]
const NAMES := ["INTAKE", "LIFT SHAFT", "CORE"]
# Layout built for each chamber index (see _build_chamber).
const LAYOUT := [0, 1, 3]
const HINTS := [
	"Hold the plate, then let your echo hold it for you.",
	"The lift only climbs while its plate is held.",
	"Two plates. Two echoes. Mind the laser.",
]

# [sheet, index] pairs. Sheets: tiles (20 cols), ind (16 cols).
const THEMES := [
	{"top": ["ind", 1], "fill": ["ind", 33], "plat": ["ind", 5], "crate": ["tiles", 26],
	 "back": ["ind", 75], "bg_a": Color("#22304a"), "bg_b": Color("#0b1020"), "accent": Color("#4fd8ff")},
	{"top": ["ind", 4], "fill": ["ind", 20], "plat": ["ind", 5], "crate": ["tiles", 26],
	 "back": ["ind", 23], "bg_a": Color("#4a2a1c"), "bg_b": Color("#160b08"), "accent": Color("#ff9a3c")},
	{"top": ["ind", 87], "fill": ["ind", 103], "plat": ["ind", 88], "crate": ["tiles", 26],
	 "back": ["ind", 92], "bg_a": Color("#3a1d4a"), "bg_b": Color("#10061a"), "accent": Color("#d77bff")},
]

var tex := {}
var font_big: FontFile
var font_body: FontFile

# --- run state ---
var state := "title"
var state_t := 0.0
var anim_t := 0.0
var chamber := 0
var stability := 3
var total_loops := 0
var paradox_count := 0
var scenario_mode := false
var banner_t := 0.0
var shake := 0.0
var message := ""

# --- chamber state ---
var grid := PackedByteArray()
var plates := []
var doors := []
var lifts := []
var levers := []
var gates := []
var lasers := []
var decor := []
var spawn := Vector2.ZERO
var exit_rect := Rect2()
var loop_len := 6.0
var max_loops := 2
var loop_num := 1
var loop_tick := 0
var echoes := []
var live := {}
var live_inputs := PackedInt32Array()
var live_pos := PackedVector2Array()
var prev_live_input := 0
var glitch_echo := -1
var chamber_time := 0.0
var cleared := [false, false, false]

# --- input ---
var latched := {}
var clicked := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_assets()
	var args := OS.get_cmdline_user_args()
	if "--selftest" in args:
		_selftest()
		get_tree().quit()
		return
	var idx := args.find("--scenario")
	if idx >= 0 and idx + 1 < args.size():
		_start_scenario(args[idx + 1])


func _load_assets() -> void:
	for n in ["tiles", "ind", "chars"]:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/%s.png" % n))
		tex[n] = ImageTexture.create_from_image(img)
	font_big = FontFile.new()
	font_big.load_dynamic_font(ProjectSettings.globalize_path("res://assets/KenneyFuture.ttf"))
	font_body = FontFile.new()
	font_body.load_dynamic_font(ProjectSettings.globalize_path("res://assets/KenneyFutureNarrow.ttf"))


# ===================================================================== chambers

func _cell(c: int, r: int) -> int:
	if c < 0 or c >= COLS or r < 0 or r >= ROWS:
		return T_SOLID
	return grid[r * COLS + c]


func _fill(c0: int, c1: int, r0: int, r1: int, t: int) -> void:
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			grid[r * COLS + c] = t


func _build_chamber(i: int) -> void:
	grid = PackedByteArray()
	grid.resize(COLS * ROWS)
	_fill(0, COLS - 1, 0, 1, T_SOLID)
	_fill(0, 0, 0, ROWS - 1, T_SOLID)
	_fill(COLS - 1, COLS - 1, 0, ROWS - 1, T_SOLID)
	_fill(0, COLS - 1, 17, ROWS - 1, T_SOLID)
	plates = []
	doors = []
	lifts = []
	levers = []
	gates = []
	lasers = []
	decor = []
	exit_rect = Rect2(1116, 540, 36, 72)
	match LAYOUT[i]:
		0:
			loop_len = 6.0
			max_loops = 2
			spawn = Vector2(77, FLOOR_Y - BH)
			_fill(22, 22, 2, 12, T_SOLID)
			_fill(16, 16, 16, 16, T_CRATE)
			_fill(5, 8, 12, 12, T_PLAT)
			plates.append({"rect": Rect2(360, 600, 54, 12), "link": 0})
			doors.append({"rect": Rect2(792, 468, 36, 144), "plates": [0], "link": 0})
			decor = [["ind", 42, 12, 16], ["ind", 64, 6, 11], ["ind", 73, 27, 16], ["ind", 9, 33, 16],
				["ind", 10, 32, 16], ["ind", 107, 3, 2], ["ind", 91, 3, 3], ["ind", 75, 3, 4]]
		1:
			loop_len = 9.0
			max_loops = 2
			spawn = Vector2(473, FLOOR_Y - BH)
			_fill(24, 33, 6, 16, T_SOLID)
			_fill(21, 23, 17, 17, T_EMPTY)
			exit_rect = Rect2(1116, 144, 36, 72)
			plates.append({"rect": Rect2(144, 600, 54, 12), "link": 1})
			lifts.append({"x": 756.0, "w": 108.0, "bottom": 612.0, "topy": 216.0, "y": 612.0, "plate": 0, "link": 1})
			decor = [["ind", 41, 8, 16], ["ind", 42, 18, 16], ["ind", 65, 27, 5], ["ind", 9, 30, 5],
				["ind", 57, 2, 16], ["ind", 74, 15, 16], ["ind", 58, 15, 15]]
		2:
			loop_len = 8.0
			max_loops = 2
			spawn = Vector2(473, FLOOR_Y - BH)
			_fill(25, 25, 2, 14, T_SOLID)
			_fill(5, 9, 11, 11, T_PLAT)
			_fill(12, 16, 8, 8, T_PLAT)
			levers.append({"x": 90.0, "base": FLOOR_Y, "gate": 0, "on_t": 0.0, "link": 2})
			gates.append({"rect": Rect2(900, 540, 36, 72), "timer": 0.0, "open": 0.0, "link": 2})
			decor = [["ind", 42, 20, 16], ["ind", 64, 7, 10], ["ind", 64, 14, 7], ["ind", 73, 29, 16],
				["ind", 10, 33, 16], ["ind", 57, 22, 16]]
		3:
			loop_len = 7.0
			max_loops = 3
			spawn = Vector2(293, FLOOR_Y - BH)
			_fill(29, 29, 2, 12, T_SOLID)
			_fill(11, 13, 9, 9, T_PLAT)
			_fill(19, 22, 9, 9, T_PLAT)
			plates.append({"rect": Rect2(108, 600, 54, 12), "link": 0})
			plates.append({"rect": Rect2(756, 600, 54, 12), "link": 1})
			doors.append({"rect": Rect2(1044, 468, 36, 144), "plates": [0, 1], "link": 2})
			lasers.append({"x": 594.0, "y0": 72.0, "y1": 612.0, "period": 2.0, "on": 1.0})
			decor = [["ind", 42, 14, 16], ["ind", 42, 18, 16], ["ind", 41, 25, 16], ["ind", 9, 32, 16],
				["ind", 65, 6, 8], ["ind", 65, 26, 8]]
		4:
			loop_len = 10.0
			max_loops = 3
			spawn = Vector2(149, FLOOR_Y - BH)
			_fill(11, 13, 17, 17, T_EMPTY)
			_fill(14, 23, 7, 7, T_PLAT)
			_fill(27, 27, 2, 14, T_SOLID)
			plates.append({"rect": Rect2(54, 600, 54, 12), "link": 0})
			lifts.append({"x": 396.0, "w": 108.0, "bottom": 612.0, "topy": 252.0, "y": 612.0, "plate": 0, "link": 0})
			levers.append({"x": 774.0, "base": 252.0, "gate": 0, "on_t": 0.0, "link": 2})
			gates.append({"rect": Rect2(972, 540, 36, 72), "timer": 0.0, "open": 0.0, "link": 2})
			decor = [["ind", 42, 9, 16], ["ind", 64, 16, 6], ["ind", 64, 22, 6], ["ind", 41, 20, 16],
				["ind", 73, 30, 16], ["ind", 57, 24, 16], ["ind", 58, 24, 15]]
	for d in doors:
		d["open"] = 0.0
	for p in plates:
		p["pressed"] = false
		p["press_t"] = 0.0


func _reset_devices() -> void:
	for d in doors:
		d["open"] = 0.0
	for l in lifts:
		l["y"] = l["bottom"]
	for g in gates:
		g["timer"] = 0.0
		g["open"] = 0.0
	for lv in levers:
		lv["on_t"] = 0.0
	for p in plates:
		p["pressed"] = false


func _new_body(color_idx: int) -> Dictionary:
	return {"pos": spawn, "vel": Vector2.ZERO, "floor": true, "face": 1, "color": color_idx,
		"walk": 0.0, "moving": false, "trail": []}


func _enter_chamber(i: int, show_intro: bool) -> void:
	chamber = i
	_build_chamber(i)
	echoes = []
	loop_num = 1
	chamber_time = 0.0
	_reset_loop()
	if show_intro:
		_set_state("intro")
	else:
		banner_t = 2.2
		_set_state("ready")


func _reset_loop() -> void:
	_reset_devices()
	loop_tick = 0
	live = _new_body(-1)
	live_inputs = PackedInt32Array()
	live_pos = PackedVector2Array()
	prev_live_input = 0
	glitch_echo = -1
	for e in echoes:
		e["body"] = _new_body(e["color"])
		e["prev"] = 0


func _commit_loop() -> void:
	echoes.append({"inputs": live_inputs.duplicate(), "pos": live_pos.duplicate(),
		"color": echoes.size() % ECHO_COLORS.size(), "prev": 0})
	loop_num += 1
	total_loops += 1
	_reset_loop()


func _start_run() -> void:
	stability = 3
	total_loops = 0
	paradox_count = 0
	cleared = [false, false, false]
	_enter_chamber(0, true)


func _start_scenario(id: String) -> void:
	scenario_mode = true
	stability = 3
	match id:
		"chamber_1": _enter_chamber(0, false)
		"chamber_2": _enter_chamber(1, false)
		"chamber_3": _enter_chamber(2, false)
		"chamber_3_unstable":
			stability = 2
			_enter_chamber(2, false)
		"title_flow", "":
			pass
	if chamber > 0:
		for k in chamber:
			cleared[k] = true


func _set_state(s: String) -> void:
	state = s
	state_t = 0.0


# ===================================================================== physics

func _brect(b: Dictionary) -> Rect2:
	return Rect2(b["pos"], Vector2(BW, BH))


func _overlaps(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x - 0.001 and a.end.x > b.position.x + 0.001 \
		and a.position.y < b.end.y - 0.001 and a.end.y > b.position.y + 0.001


func _solids_near(body: Rect2, is_echo: bool) -> Array:
	var out := []
	var r := body.grow(16)
	var c0 := int(floor(r.position.x / TS)) - 1
	var c1 := int(floor(r.end.x / TS)) + 1
	var r0 := int(floor(r.position.y / TS)) - 1
	var r1 := int(floor(r.end.y / TS)) + 1
	for row in range(r0, r1 + 1):
		for col in range(c0, c1 + 1):
			if _cell(col, row) != T_EMPTY:
				out.append(Rect2(col * TS, row * TS, TS, TS))
	for d in doors:
		var h: float = d["rect"].size.y * (1.0 - d["open"])
		if h > 0.5:
			out.append(Rect2(d["rect"].position, Vector2(d["rect"].size.x, h)))
	for g in gates:
		var gh: float = g["rect"].size.y * (1.0 - g["open"])
		if gh > 0.5:
			out.append(Rect2(g["rect"].position, Vector2(g["rect"].size.x, gh)))
	for l in lifts:
		out.append(Rect2(l["x"], l["y"], l["w"], TS))
	if is_echo:
		out.append(_brect(live))
	# Solids already overlapping the body (e.g. an echo and the live player
	# sharing the spawn point) are ignored rather than resolved.
	var filtered := []
	for s in out:
		if not _overlaps(body, s):
			filtered.append(s)
	return filtered


func _step_body(b: Dictionary, input: int, prev: int, is_echo: bool) -> void:
	var vx := 0.0
	if input & IN_L:
		vx -= RUN
	if input & IN_R:
		vx += RUN
	var vel: Vector2 = b["vel"]
	vel.x = vx
	if (input & IN_J) and not (prev & IN_J) and b["floor"]:
		vel.y = -JUMP
	vel.y = min(vel.y + GRAV * DT, MAXFALL)
	var solids := _solids_near(_brect(b), is_echo)
	var pos: Vector2 = b["pos"]
	# horizontal
	pos.x += vel.x * DT
	var r := Rect2(pos, Vector2(BW, BH))
	for s in solids:
		if _overlaps(r, s):
			if vel.x > 0:
				pos.x = s.position.x - BW
			elif vel.x < 0:
				pos.x = s.end.x
			r = Rect2(pos, Vector2(BW, BH))
	# vertical
	b["floor"] = false
	pos.y += vel.y * DT
	r = Rect2(pos, Vector2(BW, BH))
	for s in solids:
		if _overlaps(r, s):
			if vel.y > 0:
				pos.y = s.position.y - BH
				b["floor"] = true
			elif vel.y < 0:
				pos.y = s.end.y
			vel.y = 0.0
			r = Rect2(pos, Vector2(BW, BH))
	b["pos"] = pos
	b["vel"] = vel
	if vx != 0.0:
		b["face"] = 1 if vx > 0 else -1
	b["moving"] = vx != 0.0
	if (input & IN_E) and not (prev & IN_E):
		_try_lever(b)


func _try_lever(b: Dictionary) -> void:
	var cx: float = b["pos"].x + BW * 0.5
	var bottom: float = b["pos"].y + BH
	for lv in levers:
		if abs(cx - lv["x"]) < 44.0 and abs(bottom - lv["base"]) < 10.0:
			lv["on_t"] = GATE_TIME
			gates[lv["gate"]]["timer"] = GATE_TIME


func _on_plate(b: Dictionary, p: Dictionary) -> bool:
	var r := _brect(b)
	var pr: Rect2 = p["rect"]
	return abs(r.end.y - pr.end.y) < 3.0 and r.end.x > pr.position.x + 2 and r.position.x < pr.end.x - 2


func _bodies() -> Array:
	var out := []
	for e in echoes:
		out.append(e["body"])
	out.append(live)
	return out


func _update_devices() -> void:
	var bodies := _bodies()
	for p in plates:
		var pressed := false
		for b in bodies:
			if _on_plate(b, p):
				pressed = true
		p["pressed"] = pressed
	for d in doors:
		var want := true
		for pi in d["plates"]:
			if not plates[pi]["pressed"]:
				want = false
		d["open"] = move_toward(d["open"], 1.0 if want else 0.0, 3.0 * DT)
	for g in gates:
		g["timer"] = max(0.0, g["timer"] - DT)
		g["open"] = move_toward(g["open"], 1.0 if g["timer"] > 0.0 else 0.0, 6.0 * DT)
	for lv in levers:
		lv["on_t"] = max(0.0, lv["on_t"] - DT)
	for l in lifts:
		if not plates[l["plate"]]["pressed"]:
			continue
		var ny: float = max(l["topy"], l["y"] - LIFT_SPEED)
		var dy: float = ny - l["y"]
		if dy == 0.0:
			continue
		for b in bodies:
			var r := _brect(b)
			if abs(r.end.y - l["y"]) < 1.5 and r.end.x > l["x"] and r.position.x < l["x"] + l["w"]:
				b["pos"] = b["pos"] + Vector2(0, dy)
		l["y"] = ny


func _laser_on(z: Dictionary, t: float) -> bool:
	return fmod(t, z["period"]) < z["on"]


func _sim_tick(input: int) -> void:
	_update_devices()
	for i in echoes.size():
		var e: Dictionary = echoes[i]
		var t := loop_tick
		if t < e["inputs"].size():
			var inp: int = e["inputs"][t]
			_step_body(e["body"], inp, e["prev"], true)
			e["prev"] = inp
			if e["body"]["pos"].distance_to(e["pos"][t]) > DIVERGE and glitch_echo < 0:
				glitch_echo = i
		else:
			e["body"]["moving"] = false
	_step_body(live, input, prev_live_input, false)
	prev_live_input = input
	live_inputs.append(input)
	live_pos.append(live["pos"])
	loop_tick += 1
	chamber_time += DT


# ===================================================================== loop

func _physics_process(_delta: float) -> void:
	var input := _read_input()
	var enter := _pressed(KEY_ENTER) or _pressed(KEY_KP_ENTER) or _pressed(KEY_SPACE) or clicked
	match state:
		"title":
			if enter:
				_start_run()
		"intro":
			if state_t >= INTRO_TIME:
				_set_state("ready")
		"ready":
			if input != 0:
				_set_state("play")
				_play_tick(input)
		"play":
			_play_tick(input)
		"rewind":
			if state_t >= REWIND_TIME:
				_commit_loop()
				_set_state("ready")
		"shock":
			if state_t >= 0.8:
				stability -= 1
				if stability <= 0:
					_set_state("defeat")
				else:
					_reset_loop()
					_set_state("ready")
		"pglitch":
			if state_t >= 0.8:
				stability -= 1
				paradox_count += 1
				_set_state("paradox")
		"paradox":
			if state_t >= 2.6:
				if stability <= 0:
					_set_state("defeat")
				else:
					echoes = []
					loop_num = 1
					_reset_loop()
					_set_state("ready")
		"outofloops":
			if state_t >= 1.6:
				echoes = []
				loop_num = 1
				_reset_loop()
				_set_state("ready")
		"clear":
			if enter or state_t >= 4.5:
				if chamber >= NAMES.size() - 1:
					_set_state("victory")
				else:
					_enter_chamber(chamber + 1, true)
		"victory":
			if enter and state_t > 1.0:
				_set_state("title")
		"defeat":
			if enter and state_t > 0.6:
				_start_run()
	state_t += DT
	latched.clear()
	clicked = false


func _play_tick(input: int) -> void:
	if _pressed(KEY_R) and loop_tick > 0:
		_end_loop()
		return
	_sim_tick(input)
	if glitch_echo >= 0:
		shake = 0.5
		_set_state("pglitch")
		return
	var lr := _brect(live)
	for z in lasers:
		if _laser_on(z, loop_tick * DT):
			if _overlaps(lr, Rect2(z["x"] - 5, z["y0"], 10, z["y1"] - z["y0"])):
				shake = 0.4
				_set_state("shock")
				return
	if _overlaps(lr, exit_rect):
		cleared[chamber] = true
		total_loops += 1
		_set_state("clear")
		return
	if loop_tick >= int(loop_len * 60.0):
		_end_loop()


func _end_loop() -> void:
	if loop_num >= max_loops:
		_set_state("outofloops")
	else:
		_set_state("rewind")


func _read_input() -> int:
	var m := 0
	if _held(KEY_A) or _held(KEY_LEFT):
		m |= IN_L
	if _held(KEY_D) or _held(KEY_RIGHT):
		m |= IN_R
	if _held(KEY_W) or _held(KEY_UP) or (_held(KEY_SPACE) and state in ["ready", "play"]):
		m |= IN_J
	if _held(KEY_E):
		m |= IN_E
	return m


func _held(k: int) -> bool:
	return Input.is_key_pressed(k) or latched.has(k)


func _pressed(k: int) -> bool:
	return latched.has(k)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		latched[event.keycode] = true
	elif event is InputEventMouseButton and event.pressed:
		clicked = true


func _process(delta: float) -> void:
	anim_t += delta
	banner_t = max(0.0, banner_t - delta)
	shake = max(0.0, shake - delta)
	for b in _bodies():
		if b.is_empty():
			continue
		if b["moving"]:
			b["walk"] += delta
		var tr: Array = b["trail"]
		tr.push_front(b["pos"])
		if tr.size() > 8:
			tr.pop_back()
	queue_redraw()


# ===================================================================== drawing

func _tile(sheet: String, idx: int, pos: Vector2, scale := 2.0, mod := Color.WHITE) -> void:
	var cols := 20 if sheet == "tiles" else 16
	var src := Rect2((idx % cols) * 18, (idx / cols) * 18, 18, 18)
	draw_texture_rect_region(tex[sheet], Rect2(pos, Vector2(18, 18) * scale), src, mod)


func _ttile(pair: Array, pos: Vector2, mod := Color.WHITE) -> void:
	_tile(pair[0], pair[1], pos, 2.0, mod)


func _char(idx: int, pos: Vector2, face: int, mod := Color.WHITE, stretch := Vector2.ONE) -> void:
	var src := Rect2((idx % 9) * 24, (idx / 9) * 24, 24, 24)
	var size := Vector2(48, 48) * stretch
	var origin := pos + Vector2(BW * 0.5, BH + 2)
	draw_set_transform(origin, 0.0, Vector2(face, 1))
	draw_texture_rect_region(tex["chars"], Rect2(Vector2(-size.x * 0.5, -size.y), size), src, mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _text(s: String, pos: Vector2, size: int, col: Color, big := true, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f: FontFile = font_big if big else font_body
	draw_string(f, pos + Vector2(2, 2), s, align, width, size, Color(0, 0, 0, col.a * 0.6))
	draw_string(f, pos, s, align, width, size, col)


func _ctext(s: String, y: float, size: int, col: Color, big := true) -> void:
	_text(s, Vector2(0, y), size, col, big, HORIZONTAL_ALIGNMENT_CENTER, 1280.0)


func _panel(r: Rect2, accent: Color, fill := Color(0.03, 0.05, 0.09, 0.88)) -> void:
	draw_rect(r, fill)
	draw_rect(r, Color(accent, 0.55), false, 2.0)
	var k := 14.0
	for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if c.x == r.position.x else -1.0
		var sy := 1.0 if c.y == r.position.y else -1.0
		draw_line(c, c + Vector2(k * sx, 0), accent, 4.0)
		draw_line(c, c + Vector2(0, k * sy), accent, 4.0)


func _draw() -> void:
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(sin(anim_t * 90.0), cos(anim_t * 70.0)) * 8.0 * shake
	draw_set_transform(off, 0.0, Vector2.ONE)
	if state == "title":
		_draw_title()
		return
	_draw_world()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hud()
	match state:
		"intro": _draw_intro()
		"ready": _draw_ready()
		"rewind": _draw_rewind()
		"shock": _draw_shock()
		"pglitch": _draw_pglitch()
		"paradox": _draw_paradox()
		"outofloops": _draw_outofloops()
		"clear": _draw_clear()
		"victory": _draw_victory()
		"defeat": _draw_defeat()
	if banner_t > 0.0 and state in ["ready", "play"]:
		var a: float = clamp(banner_t, 0.0, 1.0)
		var th: Dictionary = THEMES[chamber]
		_panel(Rect2(400, 96, 480, 64), th["accent"], Color(0.03, 0.05, 0.09, 0.85 * a))
		_text("CHAMBER %d  —  %s" % [chamber + 1, NAMES[chamber]], Vector2(400, 138), 26, Color(1, 1, 1, a), true, HORIZONTAL_ALIGNMENT_CENTER, 480)


func _draw_background(th: Dictionary) -> void:
	var a: Color = th["bg_a"]
	var b: Color = th["bg_b"]
	for i in 12:
		draw_rect(Rect2(0, i * 60, 1280, 60), a.lerp(b, i / 11.0))
	for r in range(2, 17, 2):
		for c in range(1, 34, 3):
			_ttile(th["back"], Vector2(OX + c * TS, r * TS), Color(1, 1, 1, 0.13))
	# slow light sweep
	var sx := fmod(anim_t * 120.0, 1600.0) - 160.0
	draw_rect(Rect2(sx, 72, 90, 540), Color(th["accent"], 0.04))


func _draw_world() -> void:
	var th: Dictionary = THEMES[chamber]
	_draw_background(th)
	var o := Vector2(OX, 0)
	# terrain
	for r in ROWS:
		for c in COLS:
			var t := _cell(c, r)
			if t == T_EMPTY:
				continue
			var p := o + Vector2(c * TS, r * TS)
			if t == T_PLAT:
				_ttile(th["plat"], p)
			elif t == T_CRATE:
				_ttile(th["crate"], p)
			elif _cell(c, r - 1) == T_EMPTY:
				_ttile(th["top"], p)
			else:
				_ttile(th["fill"], p, Color(0.8, 0.8, 0.85))
	for d in decor:
		_tile(d[0], d[1], o + Vector2(d[2] * TS, d[3] * TS))
	_draw_wires(o)
	_draw_devices(o)
	# exit door
	_tile("tiles", 130, o + exit_rect.position)
	_tile("tiles", 150, o + exit_rect.position + Vector2(0, 36))
	var glow := 0.5 + 0.5 * sin(anim_t * 4.0)
	draw_rect(Rect2(o + exit_rect.position - Vector2(6, 6), exit_rect.size + Vector2(12, 12)), Color(0.4, 1.0, 0.5, 0.18 + 0.12 * glow), false, 3.0)
	_text("EXIT", o + exit_rect.position + Vector2(-8, -12), 16, Color(0.5, 1.0, 0.6), true)
	# spawn pad
	_tile("ind", 85, o + Vector2(spawn.x - 5, FLOOR_Y - 14), 2.0, Color(1, 1, 1, 0.9))
	# echoes then live
	for i in echoes.size():
		_draw_echo(i, o)
	if state != "defeat" or state_t < 0.2:
		_draw_live(o)


func _link_col(i: int, on: bool) -> Color:
	var c: Color = LINK_COLORS[i]
	return c if on else c.darkened(0.6)


func _draw_wires(o: Vector2) -> void:
	for d in doors:
		for pi in d["plates"]:
			var p: Dictionary = plates[pi]
			var a: Vector2 = o + p["rect"].get_center() + Vector2(0, 8)
			var bpt: Vector2 = o + Vector2(d["rect"].get_center().x, FLOOR_Y + 8)
			_wire(a, bpt, _link_col(p["link"], p["pressed"]))
	for l in lifts:
		var lp: Dictionary = plates[l["plate"]]
		_wire(o + lp["rect"].get_center() + Vector2(0, 8), o + Vector2(l["x"] + l["w"] * 0.5, FLOOR_Y + 8), _link_col(lp["link"], lp["pressed"]))
	for lv in levers:
		var g: Dictionary = gates[lv["gate"]]
		var gp: Vector2 = o + Vector2(g["rect"].get_center().x, g["rect"].position.y - 30)
		var lvp: Vector2 = o + Vector2(lv["x"], lv["base"] - 40)
		var on: bool = g["timer"] > 0.0
		var col := _link_col(lv["link"], on)
		var mid := Vector2(lvp.x, 84)
		draw_line(lvp, mid, col, 3.0)
		draw_line(mid, Vector2(gp.x, 84), col, 3.0)
		draw_line(Vector2(gp.x, 84), gp, col, 3.0)


func _wire(a: Vector2, b: Vector2, col: Color) -> void:
	draw_line(a, Vector2(a.x, b.y), col, 3.0)
	draw_line(Vector2(a.x, b.y), b, col, 3.0)
	var t := fmod(anim_t * 0.8, 1.0)
	if col.v > 0.5:
		draw_circle(Vector2(a.x, b.y).lerp(b, t), 4.0, Color(1, 1, 1, 0.9))


func _draw_devices(o: Vector2) -> void:
	for p in plates:
		var pr: Rect2 = p["rect"]
		var pressed: bool = p["pressed"]
		var lc: Color = LINK_COLORS[p["link"]]
		var dy := 6.0 if pressed else 0.0
		draw_rect(Rect2(o + pr.position + Vector2(-4, 4), Vector2(pr.size.x + 8, 8)), Color(0.25, 0.27, 0.32))
		draw_rect(Rect2(o + pr.position + Vector2(-4, 4), Vector2(pr.size.x + 8, 3)), lc if pressed else lc.darkened(0.55))
		_tile("tiles", 148, o + Vector2(pr.position.x - 9, pr.end.y - 30 + dy), 2.0, lc.lerp(Color.WHITE, 0.5) if pressed else Color(0.8, 0.8, 0.8))
		_tile("tiles", 148, o + Vector2(pr.position.x + 27, pr.end.y - 30 + dy), 2.0, lc.lerp(Color.WHITE, 0.5) if pressed else Color(0.8, 0.8, 0.8))
		if pressed:
			draw_rect(Rect2(o + pr.position + Vector2(-6, -10), pr.size + Vector2(12, 12)), Color(lc, 0.25))
	for d in doors:
		var dr: Rect2 = d["rect"]
		var openv: float = d["open"]
		var shift: float = dr.size.y * openv
		var n := int(dr.size.y / TS)
		for k in n:
			var y: float = dr.position.y + k * TS - shift
			if y >= dr.position.y - 1.0:
				_tile("ind", 43 if k % 2 == 0 else 27, o + Vector2(dr.position.x, y))
		var lamp := Color(0.3, 1.0, 0.45) if openv > 0.9 else Color(1.0, 0.25, 0.2)
		draw_circle(o + Vector2(dr.get_center().x, dr.position.y - 16), 8.0, lamp)
		draw_circle(o + Vector2(dr.get_center().x, dr.position.y - 16), 13.0, Color(lamp, 0.25))
		draw_rect(Rect2(o + dr.position - Vector2(2, 2), dr.size + Vector2(4, 4)), Color(LINK_COLORS[d["link"]], 0.5), false, 2.0)
	for l in lifts:
		var ly: float = l["y"]
		for k in int(l["w"] / TS):
			_tile("ind", [100, 101, 102][k % 3], o + Vector2(l["x"] + k * TS, ly))
		# chains
		var cx: float = l["x"] + l["w"] * 0.5
		var cy := 72.0
		while cy < ly - 30:
			_tile("ind", 23, o + Vector2(cx - 18, cy), 2.0, Color(1, 1, 1, 0.85))
			cy += 36.0
		var lp: Dictionary = plates[l["plate"]]
		var lc: Color = LINK_COLORS[l["link"]]
		var active: bool = lp["pressed"] and ly > l["topy"]
		draw_rect(Rect2(o + Vector2(l["x"], ly - 4), Vector2(l["w"], 4)), Color(lc, 0.9 if active else 0.3))
		if active:
			for s in 3:
				var yy := ly + 40 + fmod(anim_t * 120.0 + s * 30, 90.0)
				draw_line(o + Vector2(l["x"] + 10, yy), o + Vector2(l["x"] + l["w"] - 10, yy), Color(lc, 0.3), 2.0)
	for lv in levers:
		var on: bool = lv["on_t"] > 0.0
		_tile("tiles", 66 if on else 64, o + Vector2(lv["x"] - 18, lv["base"] - 36))
		draw_circle(o + Vector2(lv["x"], lv["base"] - 46), 6.0, LINK_COLORS[lv["link"]] if on else Color(0.35, 0.3, 0.4))
		_text("E", o + Vector2(lv["x"] - 6, lv["base"] - 58), 14, Color(1, 1, 1, 0.7), true)
	for g in gates:
		var gr: Rect2 = g["rect"]
		var gopen: float = g["open"]
		var gshift: float = gr.size.y * gopen
		for k in int(gr.size.y / TS):
			var y: float = gr.position.y + k * TS - gshift
			if y >= gr.position.y - 1.0:
				_tile("ind", 54, o + Vector2(gr.position.x, y), 2.0, LINK_COLORS[g["link"]].lerp(Color.WHITE, 0.4))
		# countdown bar
		var frac: float = g["timer"] / GATE_TIME
		var bar := Rect2(o + Vector2(gr.position.x - 22, gr.position.y - 28), Vector2(80, 10))
		draw_rect(bar, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), LINK_COLORS[g["link"]])
		draw_rect(bar, Color(1, 1, 1, 0.5), false, 1.0)
		if g["timer"] > 0.0:
			_text("%.1f" % g["timer"], bar.position + Vector2(16, -6), 16, Color.WHITE, true)
	for z in lasers:
		var t := loop_tick * DT
		var on := _laser_on(z, t)
		var warn: bool = not on and fmod(t, z["period"]) > z["period"] - 0.25
		_tile("ind", 64, o + Vector2(z["x"] - 18, z["y0"]))
		_tile("ind", 64, o + Vector2(z["x"] - 18, z["y1"] - 30), 2.0, Color(1, 1, 1, 0.8))
		if on:
			var flick := 0.8 + 0.2 * sin(anim_t * 60.0)
			draw_rect(Rect2(o + Vector2(z["x"] - 9, z["y0"] + 30), Vector2(18, z["y1"] - z["y0"] - 56)), Color(1.0, 0.1, 0.15, 0.25 * flick))
			draw_rect(Rect2(o + Vector2(z["x"] - 3, z["y0"] + 30), Vector2(6, z["y1"] - z["y0"] - 56)), Color(1.0, 0.6, 0.6, flick))
		elif warn:
			draw_rect(Rect2(o + Vector2(z["x"] - 1, z["y0"] + 30), Vector2(2, z["y1"] - z["y0"] - 56)), Color(1.0, 0.3, 0.3, 0.5))


func _body_frame(b: Dictionary, base: int) -> Array:
	# returns [frame, stretch]
	if not b["floor"]:
		return [base + 1, Vector2(0.9, 1.12)]
	if b["moving"]:
		return [base + (int(b["walk"] * 9.0) % 2), Vector2(1.0, 1.0 + 0.04 * sin(b["walk"] * 28.0))]
	return [base, Vector2(1.0 + 0.02 * sin(anim_t * 3.0), 1.0 - 0.02 * sin(anim_t * 3.0))]


func _draw_live(o: Vector2) -> void:
	if live.is_empty():
		return
	var fr := _body_frame(live, 6)
	var mod := Color.WHITE
	if state == "shock":
		mod = Color(1, 1, 1) if int(state_t * 20) % 2 == 0 else Color(1.0, 0.3, 0.3)
		for k in 4:
			var a: Vector2 = o + live["pos"] + Vector2(randf() * 30 - 2, randf() * 40)
			draw_line(a, a + Vector2(randf() * 24 - 12, randf() * 24 - 12), Color(1, 0.9, 0.4), 2.0)
	_char(fr[0], o + live["pos"], live["face"], mod, fr[1])


func _draw_echo(i: int, o: Vector2) -> void:
	var e: Dictionary = echoes[i]
	var b: Dictionary = e["body"]
	var col: Color = ECHO_COLORS[e["color"]]
	var tr: Array = b["trail"]
	for k in range(tr.size() - 1, 0, -2):
		_char(2, o + tr[k], b["face"], Color(col, 0.12 * (1.0 - k / 8.0)))
	var fr := _body_frame(b, 2)
	var pos: Vector2 = o + b["pos"]
	if state == "pglitch" and i == glitch_echo:
		var j := Vector2(randf() * 10 - 5, randf() * 6 - 3)
		_char(fr[0], pos + j + Vector2(-6, 0), b["face"], Color(1, 0.1, 0.1, 0.7), fr[1])
		_char(fr[0], pos - j + Vector2(6, 0), b["face"], Color(0.1, 0.4, 1, 0.7), fr[1])
		for s in 5:
			var yy := pos.y + randf() * 48 - 8
			draw_rect(Rect2(pos.x - 20 + randf() * 10, yy, 70, 3), Color(1, 1, 1, 0.8))
	else:
		var pulse := 0.62 + 0.08 * sin(anim_t * 5.0 + i)
		_char(fr[0], pos, b["face"], Color(col.lerp(Color.WHITE, 0.25), pulse), fr[1])
	# number badge, stacked upwards when bodies overlap so every echo stays identifiable
	var stack := 0
	var br := _brect(b)
	if _overlaps(br, _brect(live)):
		stack += 1
	for k in i:
		if _overlaps(br, _brect(echoes[k]["body"])):
			stack += 1
	var badge := pos + Vector2(BW * 0.5, -22 - stack * 26)
	draw_circle(badge, 11.0, Color(0, 0, 0, 0.7))
	draw_arc(badge, 11.0, 0, TAU, 20, col, 2.0)
	_text(str(i + 1), badge + Vector2(-5, 7), 15, col, true)
	if loop_tick >= e["inputs"].size() and state in ["play", "ready"] and loop_tick > 0:
		_text("HOLD", pos + Vector2(-6, -36), 12, Color(col, 0.8), true)


func _draw_hud() -> void:
	var th: Dictionary = THEMES[chamber]
	var acc: Color = th["accent"]
	_panel(Rect2(14, 8, 1252, 56), acc)
	_text("C%d" % (chamber + 1), Vector2(30, 46), 26, acc, true)
	_text(NAMES[chamber], Vector2(82, 46), 24, Color.WHITE, true)
	# loop timer
	var total := loop_len
	var left: float = max(0.0, total - loop_tick * DT)
	var bar := Rect2(400, 24, 360, 22)
	draw_rect(bar, Color(0, 0, 0, 0.6))
	var frac := left / total
	var bc := acc if frac > 0.25 else Color(1, 0.35, 0.3)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), bc)
	for k in range(1, int(total)):
		var x := bar.position.x + bar.size.x * (k / total)
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.5), 1.0)
	draw_rect(bar, Color(1, 1, 1, 0.6), false, 2.0)
	_text("%.1fs" % left, Vector2(772, 44), 20, Color.WHITE, true)
	_text("LOOP %d/%d" % [loop_num, max_loops], Vector2(860, 44), 20, Color.WHITE, true)
	_text("ECHOES %d" % echoes.size(), Vector2(1010, 44), 20, ECHO_COLORS[0], true)
	for k in 3:
		_tile("tiles", 44 if k < stability else 46, Vector2(1150 + k * 34, 18), 1.6)


func _dim(a := 0.55) -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, a))


func _draw_intro() -> void:
	var th: Dictionary = THEMES[chamber]
	var t: float = clamp(state_t / 0.35, 0.0, 1.0)
	_dim(0.6 * t)
	var x := lerpf(-700.0, 290.0, ease(t, -2.0))
	_panel(Rect2(x, 250, 700, 210), th["accent"])
	_text("CHAMBER %d" % (chamber + 1), Vector2(x + 40, 310), 30, th["accent"], true)
	_text(NAMES[chamber], Vector2(x + 40, 375), 54, Color.WHITE, true)
	_text(HINTS[chamber], Vector2(x + 40, 425), 22, Color(0.85, 0.9, 1.0), false)


func _draw_ready() -> void:
	if banner_t > 0.0:
		return
	var a := 0.6 + 0.4 * sin(anim_t * 5.0)
	_ctext("MOVE TO START LOOP %d" % loop_num, 120, 22, Color(1, 1, 1, a), true)


func _draw_rewind() -> void:
	var t: float = clamp(state_t / REWIND_TIME, 0.0, 1.0)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.1, 0.7, 1.0, 0.22))
	for k in 24:
		var y := fmod(k * 30.0 + state_t * 900.0, 720.0)
		draw_rect(Rect2(0, y, 1280, 2), Color(0.6, 0.95, 1.0, 0.25))
	var o := Vector2(OX, 0)
	var n := live_pos.size()
	if n > 0:
		var idx := int((1.0 - t) * (n - 1))
		for g in 6:
			var gi := clampi(idx + g * 6, 0, n - 1)
			_char(6, o + live_pos[gi], -1, Color(0.6, 0.95, 1.0, 0.5 - g * 0.07))
		for i in echoes.size():
			var ep: PackedVector2Array = echoes[i]["pos"]
			if ep.size() > 0:
				var ei := clampi(int((1.0 - t) * (min(n, ep.size()) - 1)), 0, ep.size() - 1)
				_char(2, o + ep[ei], -1, Color(ECHO_COLORS[echoes[i]["color"]], 0.45))
	_panel(Rect2(470, 300, 340, 90), Color(0.5, 0.95, 1.0))
	_ctext("◄◄  REWIND", 345, 34, Color(0.75, 0.97, 1.0), true)
	_ctext("Loop %d becomes Echo %d" % [loop_num, echoes.size() + 1], 376, 20, Color(1, 1, 1, 0.85), false)


func _draw_shock() -> void:
	var a := 0.35 * (1.0 - state_t / 0.8)
	draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 0.85, 0.6, a))
	_panel(Rect2(440, 290, 400, 90), Color(1, 0.4, 0.3))
	_ctext("LASER HIT", 332, 34, Color(1, 0.5, 0.4), true)
	_ctext("Stability -1  ·  loop restarts", 362, 20, Color.WHITE, false)


func _draw_pglitch() -> void:
	var a := 0.15 + 0.15 * sin(anim_t * 40.0)
	draw_rect(Rect2(0, 0, 1280, 720), Color(1, 0, 0.1, a))
	for k in 6:
		draw_rect(Rect2(0, randf() * 720, 1280, randf() * 10), Color(1, 1, 1, 0.15))


func _draw_paradox() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.12, 0.0, 0.03, 0.82))
	for k in 18:
		var y := fmod(k * 41.0 + state_t * 300.0, 720.0)
		draw_rect(Rect2(0, y, 1280, 2), Color(1, 0.2, 0.3, 0.12))
	_panel(Rect2(290, 190, 700, 330), Color(1, 0.25, 0.35), Color(0.08, 0.0, 0.03, 0.95))
	var jx := sin(anim_t * 50.0) * 3.0
	_text("PARADOX", Vector2(jx - 4, 290), 84, Color(0.2, 0.6, 1, 0.6), true, HORIZONTAL_ALIGNMENT_CENTER, 1280)
	_text("PARADOX", Vector2(-jx + 4, 290), 84, Color(1, 0.2, 0.2, 0.6), true, HORIZONTAL_ALIGNMENT_CENTER, 1280)
	_ctext("PARADOX", 290, 84, Color.WHITE, true)
	_ctext("Echo %d could not follow its own path." % (glitch_echo + 1), 345, 24, Color(1, 0.8, 0.8), false)
	_ctext("Stability  -1", 395, 28, Color(1, 0.45, 0.4), true)
	for k in 3:
		_tile("tiles", 44 if k < stability else 46, Vector2(575 + k * 46, 412), 2.2)
	_ctext("Timeline restarting at loop 1 ...", 490, 20, Color(1, 1, 1, 0.7), false)


func _draw_outofloops() -> void:
	_dim(0.5)
	_panel(Rect2(440, 290, 400, 90), Color(1, 0.8, 0.3))
	_ctext("OUT OF LOOPS", 332, 32, Color(1, 0.85, 0.4), true)
	_ctext("Chamber resets to loop 1", 362, 20, Color.WHITE, false)


func _draw_progress(y: float, acc: Color) -> void:
	var n := NAMES.size()
	var step := 260.0
	var x0 := 640.0 - step * (n - 1) * 0.5
	draw_line(Vector2(x0, y), Vector2(x0 + step * (n - 1), y), Color(1, 1, 1, 0.25), 6.0)
	for k in n:
		var c := Vector2(x0 + step * k, y)
		var done: bool = cleared[k]
		var is_next: bool = (not done) and (k == 0 or cleared[k - 1])
		if done and k < n - 1 and cleared[k + 1]:
			draw_line(c, c + Vector2(step, 0), acc, 6.0)
		var r := 22.0 + (4.0 * sin(anim_t * 6.0) if is_next else 0.0)
		draw_circle(c, r + 6, Color(0, 0, 0, 0.6))
		draw_circle(c, r, acc if done else (Color(1, 1, 1, 0.85) if is_next else Color(0.3, 0.3, 0.35)))
		_text(str(k + 1), c + Vector2(-8, 9), 24, Color(0.05, 0.05, 0.1), true)
		_text(NAMES[k], Vector2(c.x - 70, y + 52), 14, Color(1, 1, 1, 0.9 if done or is_next else 0.45), true, HORIZONTAL_ALIGNMENT_CENTER, 140)


func _draw_clear() -> void:
	var th: Dictionary = THEMES[chamber]
	var acc: Color = th["accent"]
	var t: float = clamp(state_t / 0.4, 0.0, 1.0)
	_dim(0.7 * t)
	_panel(Rect2(200, 120, 880, 480), acc)
	_ctext("CHAMBER CLEARED", 200, 52, acc, true)
	_ctext("%d  ·  %s" % [chamber + 1, NAMES[chamber]], 245, 26, Color.WHITE, true)
	_ctext("Loops used  %d / %d        Time  %.1fs        Echoes  %d" % [loop_num, max_loops, chamber_time, echoes.size()], 300, 24, Color(0.9, 0.95, 1), false)
	_ctext("VAULT PROGRESS", 360, 18, Color(1, 1, 1, 0.6), true)
	_draw_progress(410, acc)
	if chamber < NAMES.size() - 1:
		_ctext("NEXT:  CHAMBER %d  —  %s" % [chamber + 2, NAMES[chamber + 1]], 530, 22, Color.WHITE, true)
	else:
		_ctext("THE CORE IS OPEN", 530, 22, Color.WHITE, true)
	_ctext("[ENTER]  CONTINUE", 570, 18, Color(1, 1, 1, 0.5 + 0.4 * sin(anim_t * 5.0)), true)


func _draw_victory() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.04, 0.08, 0.85))
	for k in 40:
		var a := k * 0.157 + anim_t * 0.3
		var c := Vector2(640, 330)
		draw_line(c + Vector2(cos(a), sin(a)) * 180, c + Vector2(cos(a), sin(a)) * 700, Color(1, 0.85, 0.4, 0.05), 8.0)
	_panel(Rect2(240, 110, 800, 500), Color(1, 0.85, 0.4))
	_ctext("VAULT OPEN", 210, 76, Color(1, 0.88, 0.45), true)
	_ctext("Three chambers. One engineer. Many of you.", 258, 24, Color.WHITE, false)
	for i in 3:
		_char([6, 2, 2][i], Vector2(560 + i * 60, 290), 1, Color.WHITE if i == 0 else Color(ECHO_COLORS[i - 1], 0.7), Vector2(1.3, 1.3))
	_ctext("Total loops  %d        Paradoxes  %d        Stability  %d/3" % [total_loops, paradox_count, stability], 420, 24, Color(0.9, 0.95, 1), false)
	_draw_progress(480, Color(1, 0.85, 0.4))
	_ctext("[ENTER]  PLAY AGAIN", 585, 20, Color(1, 1, 1, 0.5 + 0.4 * sin(anim_t * 5.0)), true)


func _draw_defeat() -> void:
	var t: float = clamp(state_t / 0.5, 0.0, 1.0)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.1, 0.0, 0.0, 0.85 * t))
	for k in 30:
		var y := fmod(k * 24.0 + anim_t * 40.0, 720.0)
		draw_rect(Rect2(0, y, 1280, 1), Color(1, 0.3, 0.2, 0.08))
	_panel(Rect2(290, 170, 700, 380), Color(1, 0.3, 0.25), Color(0.08, 0.01, 0.01, 0.95))
	_ctext("TIMELINE", 260, 60, Color(1, 0.4, 0.3), true)
	_ctext("COLLAPSED", 325, 60, Color(1, 0.4, 0.3), true)
	_ctext("Stability reached zero in chamber %d — %s." % [chamber + 1, NAMES[chamber]], 380, 22, Color.WHITE, false)
	for k in 3:
		_tile("tiles", 46, Vector2(575 + k * 46, 400), 2.2)
	var btn := Rect2(520, 470, 240, 54)
	draw_rect(btn, Color(1, 0.35, 0.25, 0.85 + 0.15 * sin(anim_t * 5.0)))
	draw_rect(btn, Color.WHITE, false, 2.0)
	_text("RETRY  [ENTER]", Vector2(520, 506), 24, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, 240)


func _draw_title() -> void:
	var th: Dictionary = THEMES[0]
	_draw_background(th)
	for c in COLS:
		_ttile(th["top"], Vector2(OX + c * TS, 612))
		_ttile(th["fill"], Vector2(OX + c * TS, 648), Color(0.8, 0.8, 0.85))
		_ttile(th["fill"], Vector2(OX + c * TS, 684), Color(0.8, 0.8, 0.85))
	for d in [["ind", 64, 4, 16], ["ind", 42, 9, 16], ["ind", 73, 26, 16], ["ind", 9, 30, 16], ["ind", 10, 31, 16]]:
		_tile(d[0], d[1], Vector2(OX + d[2] * TS, d[3] * TS))
	# a walking engineer and two echoes trailing behind
	for i in 3:
		var x := fmod(anim_t * 140.0 - i * 110.0, 1500.0) - 120.0
		var y := 572.0 - maxf(0.0, sin(anim_t * 3.0 - i * 0.8)) * 60.0
		var fake := {"floor": y >= 571.0, "moving": true, "walk": anim_t + i}
		var fr := _body_frame(fake, 6 if i == 0 else 2)
		_char(fr[0], Vector2(x, y), 1, Color.WHITE if i == 0 else Color(ECHO_COLORS[i - 1], 0.6), fr[1])
	for k in 3:
		var a := 0.35 - k * 0.1
		_text("ECHO VAULT", Vector2(-k * 14.0 - 6.0 * sin(anim_t * 2.0), 250), 110, Color(0.35, 0.92, 1.0, a), true, HORIZONTAL_ALIGNMENT_CENTER, 1280)
	_ctext("ECHO VAULT", 250, 110, Color.WHITE, true)
	_ctext("A time-loop heist through five sealed chambers", 300, 26, Color(0.75, 0.92, 1.0), false)
	_panel(Rect2(440, 360, 400, 70), Color(0.35, 0.92, 1.0))
	_ctext("PRESS ENTER TO START", 405, 26, Color(1, 1, 1, 0.6 + 0.4 * sin(anim_t * 4.0)), true)
	_ctext("A / D  move     W  jump     E  lever     R  end loop early", 480, 20, Color(1, 1, 1, 0.7), false)


# ===================================================================== solutions / selftest

# Each loop is a list of [ticks, input-mask] segments (60 ticks = 1 s).
const SOLUTIONS := [
	[[[1, IN_E], [30, 0], [80, IN_R], [20, 0]],
	 [[115, IN_R], [8, IN_R | IN_J], [220, IN_R]]],
	[[[1, IN_E], [84, 0], [85, IN_L], [20, 0]],
	 [[88, IN_R], [282, 0], [100, IN_R]]],
	[[[47, IN_L], [20, 0]],
	 [[130, IN_R], [20, 0]],
	 [[300, IN_R]]],
]


func _expand(script: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for seg in script:
		for k in seg[0]:
			out.append(seg[1])
	return out


func _selftest() -> void:
	for ci in NAMES.size():
		_enter_chamber(ci, false)
		var loops: Array = SOLUTIONS[ci]
		var result := "running"
		for li in loops.size():
			state = "play"
			for mask in _expand(loops[li]):
				_play_tick(mask)
				if state != "play":
					break
			if state == "play" and li < loops.size() - 1:
				_commit_loop()
				continue
			if state == "clear":
				result = "CLEAR in loop %d at %.2fs" % [loop_num, loop_tick * DT]
			else:
				result = "FAILED state=%s loop=%d tick=%d live=%s glitch=%d" % [state, loop_num, loop_tick, str(live["pos"]), glitch_echo]
			break
		print("chamber %d %s: %s" % [ci + 1, NAMES[ci], result])
	# paradox check: block echo in chamber 1
	_enter_chamber(0, false)
	state = "play"
	for mask in _expand([[1, IN_E], [60, 0], [80, IN_R], [20, 0]]):
		_play_tick(mask)
	_commit_loop()
	state = "play"
	for mask in _expand([[40, IN_R], [120, 0]]):
		_play_tick(mask)
		if state != "play":
			break
	print("paradox test: state=%s at tick %d (glitch echo %d)" % [state, loop_tick, glitch_echo])
	# laser check: chamber 4 walking into the beam while on
	_enter_chamber(2, false)
	state = "play"
	for mask in _expand([[1, IN_E], [60, 0], [120, IN_R]]):
		_play_tick(mask)
		if state != "play":
			break
	print("laser test: state=%s at tick %d" % [state, loop_tick])
