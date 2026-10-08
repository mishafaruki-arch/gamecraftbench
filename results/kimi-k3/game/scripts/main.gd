extends Node

# Echo Vault — game orchestrator. Owns the state machine, screens, HUD,
# rewind effect, scenario setup (--scenario) and trace replay (--trace).

const _Util = preload("res://scripts/util.gd")
const _ChamberData = preload("res://scripts/chamber_data.gd")
const _Chamber = preload("res://scripts/chamber.gd")
const _Hud = preload("res://scripts/hud.gd")
const _Screens = preload("res://scripts/screens.gd")
const _Audio = preload("res://scripts/audio.gd")
const _TracePlayer = preload("res://scripts/trace_player.gd")

var state := "boot"  # title | card | play | rewind | clear | paradox | loops_out | defeat | victory
var paused := false

var sfx: Node
var hud: CanvasLayer
var screens: CanvasLayer
var chamber = null

var chamber_idx := 0
var stability := 3
var total_loops := 0
var scenario := ""
var record_out := ""

var rewind_layer: CanvasLayer
var rewind_rect: ColorRect
var rewind_mat: ShaderMaterial
var flash_rect: ColorRect
var fade_rect: ColorRect
var shake_t := 0.0

func _ready() -> void:
	Engine.max_fps = 60
	_setup_input()
	_parse_args()
	_debug_pos = "--debug-pos" in OS.get_cmdline_user_args()
	sfx = _Audio.new()
	add_child(sfx)
	hud = _Hud.new()
	hud.build()
	hud.visible = false
	add_child(hud)
	screens = _Screens.new()
	screens.sfx = sfx
	add_child(screens)
	_build_overlays()
	if scenario == "":
		show_title()
	else:
		_start_scenario(scenario)
	# trace player last so the game is fully built
	var trace_file := _arg_value("trace")
	if trace_file != "":
		var tp = _TracePlayer.new()
		tp.trace_path = trace_file
		add_child(tp)

# ------------------------------------------------------------------- setup

func _setup_input() -> void:
	_add_action("ev_left", [KEY_A, KEY_LEFT])
	_add_action("ev_right", [KEY_D, KEY_RIGHT])
	_add_action("ev_jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_action("ev_rewind", [KEY_R])
	_add_action("ev_pause", [KEY_ESCAPE, KEY_P])

func _add_action(n: String, keys: Array) -> void:
	if not InputMap.has_action(n):
		InputMap.add_action(n)
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		InputMap.action_add_event(n, ev)

func _parse_args() -> void:
	scenario = _arg_value("scenario")
	record_out = _arg_value("record-out")
	# convenience: a trace file may name its own scenario
	var trace_file := _arg_value("trace")
	if scenario == "" and trace_file != "":
		var f := FileAccess.open(trace_file, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("scenario"):
				scenario = String(parsed["scenario"])

func _arg_value(key: String) -> String:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--" + key and i + 1 < args.size():
			return args[i + 1]
		if args[i].begins_with("--" + key + "="):
			return args[i].substr(key.length() + 3)
	return ""

func _build_overlays() -> void:
	# rewind sweep
	rewind_layer = CanvasLayer.new()
	rewind_layer.layer = 15
	rewind_layer.visible = false
	add_child(rewind_layer)
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float progress = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float sweep = (1.0 - progress) * 1.25 - 0.125;
	float band = smoothstep(0.12, 0.0, abs(uv.x - sweep));
	uv.x += band * 0.025 * sin(uv.y * 90.0 + progress * 30.0);
	vec4 c = texture(screen_tex, uv);
	c.rgb = mix(c.rgb, vec3(0.25, 0.85, 1.0), band * 0.6);
	float sl = 0.05 * (0.5 + 0.5 * sin(uv.y * 720.0)) * band;
	c.rgb += vec3(sl * 0.2, sl * 0.5, sl * 0.6);
	COLOR = c;
}
"""
	rewind_mat = ShaderMaterial.new()
	rewind_mat.shader = sh
	rewind_rect = ColorRect.new()
	rewind_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rewind_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rewind_rect.material = rewind_mat
	rewind_layer.add_child(rewind_rect)
	# red flash for laser / paradox
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 16
	add_child(flash_layer)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 0.15, 0.1, 0)
	flash_layer.add_child(flash_rect)
	# fade to black
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 30
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color(0, 0, 0, 0)
	fade_layer.add_child(fade_rect)

# ------------------------------------------------------------------- title

func show_title() -> void:
	state = "title"
	paused = false
	get_tree().paused = false
	hud.visible = false
	_remove_chamber()
	sfx.stop_ambience()
	screens.show_title(
		func(): _fade_to(func(): start_run()),
		func(): get_tree().quit())

func start_run() -> void:
	stability = 3
	total_loops = 0
	chamber_idx = 0
	_enter_chamber(true)

func _enter_chamber(with_card: bool) -> void:
	_build_chamber(chamber_idx)
	sfx.start_ambience()
	hud.visible = true
	hud.set_chamber_title(chamber_idx, chamber.data["name"])
	hud.set_stability(stability)
	if with_card:
		state = "card"
		screens.show_card(chamber_idx, _ChamberData.count(), chamber.data,
			func(): _begin_play(1))
	else:
		_begin_play(1)

func _build_chamber(idx: int) -> void:
	_remove_chamber()
	chamber = _Chamber.new()
	add_child(chamber)
	chamber.setup(_ChamberData.get_chamber(idx), sfx)
	chamber.connect("sig_cleared", _on_cleared)
	chamber.connect("sig_paradox", _on_paradox)
	chamber.connect("sig_laser_death", _on_laser_death)
	chamber.connect("sig_rewind_requested", _on_rewind)

func _remove_chamber() -> void:
	if chamber != null:
		chamber.queue_free()
		chamber = null

func _begin_play(loop_n: int) -> void:
	screens.hide_all()
	state = "play"
	chamber.begin_loop(loop_n)

# ------------------------------------------------------------- transitions

func _on_cleared() -> void:
	total_loops += chamber.loop_idx
	sfx.play("clear", -4.0)
	if chamber_idx >= _ChamberData.count() - 1:
		state = "victory"
		sfx.play("victory", -4.0)
		screens.show_victory(total_loops,
			func(): _fade_to(func(): start_run()),
			func(): _fade_to(func(): show_title()))
	else:
		state = "clear"
		sfx.play("jingle_clear", -8.0)
		screens.show_clear(chamber_idx, _ChamberData.count(), chamber.loop_idx,
			chamber.data["loops_max"],
			func():
				chamber_idx += 1
				_enter_chamber(true))

func _on_paradox() -> void:
	state = "paradox"
	stability -= 1
	hud.set_stability(stability)
	sfx.play("paradox", -2.0)
	sfx.play("error", -6.0)
	_flash(Color(1, 0.15, 0.1, 0.45))
	_shake(0.5)
	if stability <= 0:
		_to_defeat()
	else:
		screens.show_paradox(stability, func(): _retry_chamber())

func _on_laser_death() -> void:
	state = "laser"
	stability -= 1
	hud.set_stability(stability)
	sfx.play("laser_hit", -4.0)
	_flash(Color(1, 0.2, 0.1, 0.5))
	_shake(0.35)
	if stability <= 0:
		_to_defeat()
		return
	chamber.discard_recording()
	# brief beat so the hurt pose reads, then rewind into the same loop
	var tw := create_tween()
	tw.tween_interval(0.55)
	tw.tween_callback(func(): _play_rewind(0.8, func(): chamber.begin_loop(chamber.loop_idx), func(): state = "play"))

func _on_rewind(_auto: bool) -> void:
	state = "rewind"
	chamber.finish_recording()
	_dump_recordings()
	sfx.play("rewind", -6.0)
	if chamber.loop_idx >= chamber.data["loops_max"]:
		# no loops left: the timeline fails
		stability -= 1
		hud.set_stability(stability)
		sfx.play("loops_out", -4.0)
		if stability <= 0:
			_play_rewind(0.8, func(): pass, func(): _to_defeat())
		else:
			_play_rewind(0.8, func(): pass, func():
				state = "loops_out"
				screens.show_loops_out(stability, func(): _retry_chamber()))
		return
	var next_loop: int = chamber.loop_idx + 1
	_play_rewind(1.05, func(): chamber.begin_loop(next_loop), func(): state = "play")

func _retry_chamber() -> void:
	screens.hide_all()
	chamber.restart_all()
	state = "play"

func _to_defeat() -> void:
	state = "defeat"
	sfx.play("paradox", 0.0, 0.7)
	screens.show_defeat(
		func(): _fade_to(func(): start_run()),
		func(): _fade_to(func(): show_title()))

func _play_rewind(dur: float, mid: Callable, end: Callable) -> void:
	rewind_layer.visible = true
	rewind_mat.set_shader_parameter("progress", 0.0)
	var tw := create_tween()
	tw.tween_method(func(v): rewind_mat.set_shader_parameter("progress", v), 0.0, 1.0, dur * 0.55)
	tw.tween_callback(func(): mid.call())
	tw.tween_method(func(v): rewind_mat.set_shader_parameter("progress", v), 1.0, 0.0, dur * 0.25)
	tw.tween_callback(func():
		rewind_layer.visible = false
		end.call())

func _flash(c: Color) -> void:
	flash_rect.color = c
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.45)

func _shake(dur: float) -> void:
	shake_t = dur

func _fade_to(what: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.3)
	tw.tween_callback(func(): what.call())
	tw.tween_property(fade_rect, "color:a", 0.0, 0.3)

# --------------------------------------------------------------- scenarios

func _start_scenario(id: String) -> void:
	stability = 3
	total_loops = 0
	var idx := 0
	var prebaked: Array = []
	var time_override := -1.0
	match id:
		"chamber1":
			idx = 0
		"chamber2":
			idx = 1
		"chamber2_quick":
			idx = 1
			time_override = 6.0
		"chamber3", "laser_setup":
			idx = 2
		"chamber3_prep1":
			idx = 2
			prebaked = [_load_recording("res://assets/recordings/ch3_a.json")]
		"chamber3_prepped", "near_victory":
			idx = 2
			prebaked = [
				_load_recording("res://assets/recordings/ch3_a.json"),
				_load_recording("res://assets/recordings/ch3_b.json"),
			]
		"paradox_setup":
			idx = 0
			prebaked = [_idle_recording(Vector2(460, 616), 150)]
		"defeat_setup":
			idx = 0
			stability = 1
			prebaked = [_idle_recording(Vector2(460, 616), 150)]
		_:
			push_warning("unknown scenario '%s', starting normally" % id)
			show_title()
			return
	chamber_idx = idx
	var data := _ChamberData.get_chamber(idx).duplicate(true)
	if time_override > 0.0:
		data["loop_time"] = time_override
	_build_chamber(idx)
	chamber.data = data
	chamber.loop_ticks = int(round(data["loop_time"] * 60.0))
	for rec in prebaked:
		if rec.size() > 0:
			chamber.recordings.append(rec)
	sfx.start_ambience()
	hud.visible = true
	hud.set_chamber_title(chamber_idx, chamber.data["name"])
	hud.set_stability(stability)
	_begin_play(1)

func _load_recording(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("missing prebaked recording: " + path)
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("frames"):
		return []
	var out: Array = []
	for fr in parsed["frames"]:
		out.append([float(fr[0]), float(fr[1]), int(fr[2]), String(fr[3])])
	return out

func _idle_recording(pos: Vector2, ticks: int) -> Array:
	var out: Array = []
	for i in range(ticks):
		out.append([pos.x, pos.y, 1, "idle"])
	return out

func _dump_recordings() -> void:
	if record_out == "" or chamber == null:
		return
	var framesets: Array = []
	for rec in chamber.recordings:
		framesets.append(rec)
	var payload := {"recordings": framesets}
	var f := FileAccess.open(record_out, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload))
		f.close()

# ------------------------------------------------------------------ inputs

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if state == "play" and not paused:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
				_pause()
		elif state == "card":
			_begin_play(1)
		elif paused and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P):
			_resume()
		elif screens.primary_btn != null and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE):
			screens.primary_btn.emit_signal("pressed")

func _pause() -> void:
	paused = true
	get_tree().paused = true
	chamber.process_mode = Node.PROCESS_MODE_DISABLED
	screens.show_pause(
		func(): _resume(),
		func():
			_resume()
			chamber.restart_all(),
		func():
			_resume()
			_fade_to(func(): show_title()))
	screens.current.process_mode = Node.PROCESS_MODE_ALWAYS

func _resume() -> void:
	paused = false
	get_tree().paused = false
	if chamber != null:
		chamber.process_mode = Node.PROCESS_MODE_INHERIT
	screens.hide_all()

# ------------------------------------------------------------------- frame

func _process(delta: float) -> void:
	if shake_t > 0.0:
		shake_t -= delta
		if chamber != null:
			chamber.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 7.0 * minf(1.0, shake_t * 3.0)
			if shake_t <= 0.0:
				chamber.position = Vector2.ZERO
	if state == "play" and chamber != null and hud.visible:
		hud.tick(chamber.get_state())
	if _debug_pos and chamber != null:
		_dbg_ticks += 1
		if _dbg_ticks % 15 == 0:
			var p: Vector2 = chamber.player.global_position
			print("[dbg] tick=%d state=%s loop=%d ltick=%d pos=(%d,%d)" % [_dbg_ticks, state, chamber.loop_idx, chamber.tick_idx, p.x, p.y])

func _physics_process(_delta: float) -> void:
	if _debug_pos:
		_phys_ticks += 1
		if _phys_ticks % 15 == 0 and chamber != null:
			var p: Vector2 = chamber.player.global_position
			print("[pdbg] ptick=%d state=%s loop=%d ltick=%d pos=(%d,%d)" % [_phys_ticks, state, chamber.loop_idx, chamber.tick_idx, p.x, p.y])

var _dbg_ticks := 0
var _phys_ticks := 0
var _debug_pos := false
