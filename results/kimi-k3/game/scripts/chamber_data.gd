extends RefCounted

# Chamber definitions. Terrain is an 18x10 ASCII grid over a 70px tile grid
# whose origin is at (10,10); devices are placed in tile coordinates.
#
# Legend: '#' solid, '.' empty. Everything else is placed from the device
# tables below.

const _Util = preload("res://scripts/util.gd")

static func count() -> int:
	return 3

static func get_chamber(idx: int) -> Dictionary:
	var all := [_chamber1(), _chamber2(), _chamber3()]
	return all[idx]

static func _chamber1() -> Dictionary:
	return {
		"name": "FIRST CONTACT",
		"sub": "One plate. One door. Two of you.",
		"objective": "Hold a plate with an echo, then walk through the door.",
		"loop_time": 15.0,
		"loops_max": 3,
		"grid": [
			"##################",
			"#................#",
			"#................#",
			"#................#",
			"#................#",
			"#................#",
			"#................#",
			"#......==........#",
			"#................#",
			"##################",
		],
		"spawn": Vector2(185, 616),
		"plates": [
			{"id": "A", "color": _Util.AMBER, "pos": Vector2(605, 500)},
		],
		"doors": [
			{"id": "D1", "color": _Util.AMBER, "plates": ["A"], "col": 12, "row": 7, "exit": true},
		],
		"lift": null,
		"lasers": [],
		"exit": Rect2(930, 510, 130, 130),
		"hints": [
			{"text": "A / D — MOVE      SPACE — JUMP", "until": 5.0},
			{"text": "STAND ON THE PLATE, THEN PRESS R TO REWIND", "until": 14.0},
		],
		"hint_loop2": "YOUR ECHO HOLDS THE PLATE — THE DOOR IS OPEN. GO!",
	}

static func _chamber2() -> Dictionary:
	return {
		"name": "THE LONG WAY UP",
		"sub": "The exit is high above the floor.",
		"objective": "An echo must power the lift while you ride it.",
		"loop_time": 20.0,
		"loops_max": 4,
		"grid": [
			"##################",
			"#................#",
			"#................#",
			"#............#####",
			"#................#",
			"#................#",
			"#................#",
			"#..==............#",
			"#................#",
			"##################",
		],
		"spawn": Vector2(185, 616),
		"plates": [
			{"id": "A", "color": _Util.BLUE, "pos": Vector2(325, 500)},
		],
		"doors": [],
		"lift": {"color": _Util.BLUE, "plate": "A", "center_x": 850.0, "base_y": 640.0, "top_y": 220.0},
		"lasers": [],
		"exit": Rect2(995, 90, 200, 130),
		"hints": [
			{"text": "THE LIFT ONLY MOVES WHILE ITS PLATE IS HELD", "until": 6.0},
			{"text": "HOLD THE PLATE IN ONE LOOP — RIDE THE LIFT IN THE NEXT", "until": 13.0},
		],
		"hint_loop2": "YOUR ECHO POWERS THE LIFT — HOP ON!",
	}

static func _chamber3() -> Dictionary:
	return {
		"name": "THE VAULT DOOR",
		"sub": "Two plates. One laser. No margin.",
		"objective": "Two echoes hold both plates while you slip past the laser.",
		"loop_time": 22.0,
		"loops_max": 5,
		"grid": [
			"##################",
			"#................#",
			"#................#",
			"#................#",
			"#................#",
			"#................#",
			"#..........==....#",
			"#..==.....=......#",
			"#................#",
			"##################",
		],
		"spawn": Vector2(185, 616),
		"plates": [
			{"id": "A", "color": _Util.AMBER, "pos": Vector2(290, 500)},
			{"id": "B", "color": _Util.BLUE, "pos": Vector2(850, 430)},
		],
		"doors": [
			{"id": "D1", "color": _Util.GREEN, "plates": ["A", "B"], "col": 15, "row": 7, "exit": true},
		],
		"lift": null,
		"lasers": [
			{"x": 605.0, "y0": 80.0, "y1": 640.0, "period": 2.6, "off": 1.0, "warn": 0.3, "offset": 0.0},
		],
		"exit": Rect2(1140, 510, 70, 130),
		"hints": [
			{"text": "THE VAULT DOOR NEEDS BOTH PLATES HELD AT ONCE", "until": 6.0},
			{"text": "THE LASER CYCLES — WATCH ITS RHYTHM", "until": 12.0},
		],
		"hint_loop2": "ONE PLATE HELD. ONE TO GO.",
		"hint_loop3": "BOTH ECHOES IN PLACE — TIME YOUR RUN!",
	}
