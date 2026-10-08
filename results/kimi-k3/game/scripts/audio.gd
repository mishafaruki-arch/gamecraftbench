extends Node

# Tiny sound manager: a round-robin pool of players plus a looping ambience.

var _players: Array = []
var _idx := 0
var _streams := {}
var _ambience: AudioStreamPlayer

func _init() -> void:
	_streams = {
		"click": load("res://assets/audio/click.ogg"),
		"door_open": load("res://assets/audio/door_open.ogg"),
		"door_close": load("res://assets/audio/door_close.ogg"),
		"echo_spawn": load("res://assets/audio/echo_spawn.ogg"),
		"paradox": load("res://assets/audio/paradox.ogg"),
		"laser_hit": load("res://assets/audio/laser_hit.ogg"),
		"land": load("res://assets/audio/land.ogg"),
		"beep": load("res://assets/audio/beep.ogg"),
		"rewind": load("res://assets/audio/rewind.ogg"),
		"jump": load("res://assets/audio/jump.ogg"),
		"loops_out": load("res://assets/audio/loops_out.ogg"),
		"clear": load("res://assets/audio/clear.ogg"),
		"error": load("res://assets/audio/error.ogg"),
		"timer_warn": load("res://assets/audio/timer_warn.ogg"),
		"plate_on": load("res://assets/audio/plate_on.ogg"),
		"plate_off": load("res://assets/audio/plate_off.ogg"),
		"victory": load("res://assets/audio/victory.ogg"),
		"jingle_clear": load("res://assets/audio/jingle_clear.ogg"),
	}
	for i in range(10):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_ambience = AudioStreamPlayer.new()
	var amb: AudioStreamOggVorbis = load("res://assets/audio/ambience.ogg")
	if amb != null:
		amb.loop = true
	_ambience.stream = amb
	_ambience.volume_db = -20.0
	add_child(_ambience)

func play(n: String, vol: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(n) or _streams[n] == null:
		return
	var p: AudioStreamPlayer = _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stop()
	p.stream = _streams[n]
	p.volume_db = vol
	p.pitch_scale = pitch
	p.play()

func start_ambience() -> void:
	if not _ambience.playing:
		_ambience.play()

func stop_ambience() -> void:
	_ambience.stop()
