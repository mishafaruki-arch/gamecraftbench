extends Node

# Debug/demo trace player. Active only when the game is launched with
#   -- --trace <file.json>
# Replays synthetic input events on the physics clock (60 Hz): an event with
# "frame": N fires once the loop time passes N/30 seconds. The evaluator's
# own replay drives the real Input singleton the same way.

var trace_path := ""
var _events: Array = []
var _idx := 0
var _tick := 0
var _pending_release: Array = []  # {time, kind, data}

const KEYMAP := {
	"SPACE": KEY_SPACE, "ENTER": KEY_ENTER, "ESCAPE": KEY_ESCAPE, "TAB": KEY_TAB,
	"BACKSPACE": KEY_BACKSPACE, "DELETE": KEY_DELETE, "SHIFT": KEY_SHIFT,
	"CTRL": KEY_CTRL, "ALT": KEY_ALT,
	"UP": KEY_UP, "DOWN": KEY_DOWN, "LEFT": KEY_LEFT, "RIGHT": KEY_RIGHT,
}

func _ready() -> void:
	var f := FileAccess.open(trace_path, FileAccess.READ)
	if f == null:
		push_error("trace_player: cannot open " + trace_path)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_events = parsed.get("events", [])
	_events.sort_custom(func(a, b): return int(a.get("frame", 0)) < int(b.get("frame", 0)))
	print("[trace] loaded %d events from %s" % [_events.size(), trace_path])

func _physics_process(_delta: float) -> void:
	var t: float = _tick / 60.0
	_tick += 1
	# scheduled releases
	var still: Array = []
	for r in _pending_release:
		if t >= r["time"]:
			_fire_release(r)
		else:
			still.append(r)
	_pending_release = still
	while _idx < _events.size():
		var ev: Dictionary = _events[_idx]
		if int(ev.get("frame", 0)) / 30.0 > t:
			break
		_fire(ev)
		_idx += 1

func _keycode(code: String) -> int:
	if KEYMAP.has(code):
		return KEYMAP[code]
	if code.length() == 1:
		var c := code.unicode_at(0)
		if c >= 65 and c <= 90:
			return KEY_A + (c - 65)
		if c >= 48 and c <= 57:
			return KEY_0 + (c - 48)
		if c >= 97 and c <= 122:
			return KEY_A + (c - 97)
	push_warning("trace_player: unknown keycode " + code)
	return KEY_NONE

func _press_key(code: String) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = _keycode(code)
	ev.physical_keycode = ev.keycode
	Input.parse_input_event(ev)

func _release_key(code: String) -> void:
	var ev := InputEventKey.new()
	ev.pressed = false
	ev.keycode = _keycode(code)
	ev.physical_keycode = ev.keycode
	Input.parse_input_event(ev)

func _mouse_button(button: String, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT if button == "right" else MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)

func _mouse_move(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)

func _fire(ev: Dictionary) -> void:
	var t: float = _tick / 60.0
	match String(ev.get("type", "")):
		"key_press":
			var code := String(ev.get("keycode", ""))
			_press_key(code)
			_pending_release.append({"time": t + 0.07, "kind": "key", "code": code})
		"key_down":
			_press_key(String(ev.get("keycode", "")))
		"key_up":
			_release_key(String(ev.get("keycode", "")))
		"mouse_click":
			var pos := Vector2(float(ev.get("x", 0)), float(ev.get("y", 0)))
			var button := String(ev.get("button", "left"))
			_mouse_button(button, pos, true)
			_pending_release.append({"time": t + 0.07, "kind": "mouse", "button": button, "pos": pos})
		"mouse_down":
			_mouse_button(String(ev.get("button", "left")), Vector2(float(ev.get("x", 0)), float(ev.get("y", 0))), true)
		"mouse_up":
			_mouse_button(String(ev.get("button", "left")), Vector2(float(ev.get("x", 0)), float(ev.get("y", 0))), false)
		"mouse_move":
			_mouse_move(Vector2(float(ev.get("x", 0)), float(ev.get("y", 0))))
		"wait":
			pass

func _fire_release(r: Dictionary) -> void:
	if r["kind"] == "key":
		_release_key(r["code"])
	else:
		_mouse_button(r["button"], r["pos"], false)
