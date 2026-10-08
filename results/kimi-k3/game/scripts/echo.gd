extends Node2D

# A recorded past self. Purely visual: the chamber positions it every tick
# from the recording. Cyan, translucent, numbered, glitchy when disturbed.

const TEX := {
	"idle": "res://assets/robot/robot_blueBody.png",
	"drive1": "res://assets/robot/robot_blueDrive1.png",
	"drive2": "res://assets/robot/robot_blueDrive2.png",
	"air": "res://assets/robot/robot_blueJump.png",
	"hurt": "res://assets/robot/robot_blueHurt.png",
}
const SCALE := 0.44
const HALF := Vector2(15, 24)

var number := 1
var glitch := 0.0  # 0 calm .. 1 freaking out (visual only)

var sprite: Sprite2D
var label: Label
var ring: Node2D
var _tex_cache := {}
var _cur_anim := ""
var _Util = preload("res://scripts/util.gd")

func _ready() -> void:
	z_index = 4
	sprite = Sprite2D.new()
	sprite.scale = Vector2(SCALE, SCALE)
	add_child(sprite)
	for k in TEX:
		_tex_cache[k] = load(TEX[k])
	# number badge
	label = _Util.make_label(str(number), 20, _Util.CYAN)
	label.position = Vector2(-40, -62)
	add_child(label)
	ring = _Ring.new()
	ring.color = _Util.CYAN
	add_child(ring)
	_update_tint()

func set_frame(frame: Array) -> void:
	# frame: [x, y, face, anim]
	global_position = Vector2(frame[0], frame[1])
	var f: int = frame[2]
	sprite.flip_h = f < 0
	var a: String = frame[3]
	if a != _cur_anim:
		_cur_anim = a
		var t: Texture2D = _tex_cache.get(a, _tex_cache["idle"])
		sprite.texture = t
		sprite.position.y = HALF.y - t.get_height() * SCALE * 0.5

func body_rect() -> Rect2:
	return Rect2(global_position - HALF, HALF * 2.0)

func tick_visual(phase: float) -> void:
	# deterministic flicker from loop phase + glitch level
	var base_a := 0.5 + 0.08 * sin(phase * 9.0)
	var a: float = base_a
	if glitch > 0.0:
		a = base_a * (0.35 + 0.65 * absf(sin(phase * 55.0)))
		sprite.position.x = sin(phase * 90.0) * 2.5 * glitch
	else:
		sprite.position.x = 0.0
	sprite.modulate = Color(0.45, 0.95, 1.0, a)
	label.modulate = Color(0.45, 0.95, 1.0, 0.55 + 0.45 * glitch)
	ring.queue_redraw()

func _update_tint() -> void:
	sprite.modulate = Color(0.45, 0.95, 1.0, 0.55)

class _Ring extends Node2D:
	var color := Color.CYAN
	func _draw() -> void:
		draw_arc(Vector2(0, 22), 20.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.5), 2.0)
