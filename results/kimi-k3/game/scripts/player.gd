extends CharacterBody2D

# The present-self robot. Physics is driven manually by the chamber
# (do_physics) so the whole chamber ticks in one deterministic order.

const SPEED := 265.0
const ACCEL := 2400.0
const FRICTION := 3000.0
const AIR_FRICTION := 700.0
const GRAV_UP := 1500.0
const GRAV_DOWN := 2200.0
const JUMP_VEL := 700.0
const JUMP_CUT := 0.45
const COYOTE := 0.10
const BUFFER := 0.12
const MAX_FALL := 920.0
const HALF := Vector2(15, 24)  # collision half-extents

const TEX := {
	"idle": "res://assets/robot/robot_blueBody.png",
	"drive1": "res://assets/robot/robot_blueDrive1.png",
	"drive2": "res://assets/robot/robot_blueDrive2.png",
	"air": "res://assets/robot/robot_blueJump.png",
	"hurt": "res://assets/robot/robot_blueHurt.png",
}
const SCALE := 0.44

var face := 1
var anim := "idle"
var active := false
var coyote_t := 0.0
var buffer_t := 0.0
var hurt_t := 0.0
var _jump_prev := false
var drive_phase := 0

var sprite: Sprite2D
var _tex_cache := {}
var _sfx = null

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = HALF * 2.0
	shape.shape = rect
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.scale = Vector2(SCALE, SCALE)
	add_child(sprite)
	for k in TEX:
		_tex_cache[k] = load(TEX[k])
	_apply_anim()

func body_rect() -> Rect2:
	return Rect2(global_position - HALF, HALF * 2.0)

func reset_at(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	face = 1
	anim = "idle"
	coyote_t = 0.0
	buffer_t = 0.0
	hurt_t = 0.0
	_apply_anim()

func do_physics(delta: float) -> void:
	if hurt_t > 0.0:
		hurt_t -= delta
	# gravity
	var g := GRAV_UP if velocity.y < 0.0 else GRAV_DOWN
	velocity.y = minf(velocity.y + g * delta, MAX_FALL)

	var dir := 0.0
	if active:
		dir = Input.get_axis("ev_left", "ev_right")
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * SPEED, ACCEL * delta)
		face = 1 if dir > 0.0 else -1
	else:
		var fric := FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	coyote_t -= delta
	buffer_t -= delta
	# edge detection on level state: deterministic under injected input
	var jump_now := active and Input.is_action_pressed("ev_jump")
	if jump_now and not _jump_prev:
		buffer_t = BUFFER
	if is_on_floor():
		coyote_t = COYOTE
	if active and buffer_t > 0.0 and coyote_t > 0.0 and hurt_t <= 0.0:
		velocity.y = -JUMP_VEL
		coyote_t = 0.0
		buffer_t = 0.0
		if _sfx:
			_sfx.play("jump", -14.0, 1.35)
	if _jump_prev and not jump_now and velocity.y < 0.0:
		velocity.y *= JUMP_CUT
	_jump_prev = jump_now

	var on_floor_before := is_on_floor()
	move_and_slide()
	if is_on_floor() and not on_floor_before and velocity.y >= 0.0:
		if _sfx:
			_sfx.play("land", -22.0, 1.6)

	# animation select
	var new_anim := anim
	if hurt_t > 0.0:
		new_anim = "hurt"
	elif not is_on_floor():
		new_anim = "air"
	elif absf(velocity.x) > 25.0:
		drive_phase = (drive_phase + 1) % 16
		new_anim = "drive1" if drive_phase < 8 else "drive2"
	else:
		new_anim = "idle"
		drive_phase = 0
	if new_anim != anim:
		anim = new_anim
		_apply_anim()
	if anim == "drive1" or anim == "drive2":
		_apply_anim()
	sprite.flip_h = face < 0

func _apply_anim() -> void:
	var t: Texture2D = _tex_cache.get(anim, _tex_cache["idle"])
	sprite.texture = t
	# anchor bottom of art to bottom of collision box
	sprite.position.y = HALF.y - t.get_height() * SCALE * 0.5

func play_hurt() -> void:
	hurt_t = 0.4
	anim = "hurt"
	_apply_anim()
