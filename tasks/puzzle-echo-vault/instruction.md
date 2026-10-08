# Echo Vault

Build **Echo Vault**, a 2D time-loop puzzle platformer in Godot 4 at
`/workspace/game/`. The player breaks into a sealed vault by cooperating with
recordings of themselves: every short loop they play is replayed as a ghostly
echo in the next loop, so past selves can hold plates and power lifts while the
present self slips through.

This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

The game is a planning puzzle built on cooperation across time. The vault has
three side-view platforming chambers with pressure plates, doors, a lift, and a
laser hazard. An attempt lasts one short loop on a visible timer. When the loop
ends — or the player ends it early — time rewinds, the player returns to the
chamber entrance, and their previous attempt keeps happening alongside them as
an echo that repeats exactly what they did, at exactly the same times. The
tension comes from choreography: one loop holds a plate, the next rides the
lift that plate powers, the last walks through the door that two echoes are
holding open. If the present self gets in an echo's way so that it can no
longer follow its recorded path, the timeline breaks in a paradox. The tone is
industrial sci-fi: steel girders, warning stripes, indicator lamps, humming
machinery, and cyan time-distortion effects.

## What the Player Experiences

A title screen sets the vault-heist tone with the game name, industrial art,
and a hint of ghostly echoes. Each chamber opens with a card showing its
number and name. In play, the HUD shows the chamber, the loop timer, the
current loop out of the loops allowed, the number of echoes, and the player's
remaining stability.

The player runs and jumps through the chamber with snappy, readable movement.
Pressure plates press while anyone stands on them, doors open while their
plates are held, and the lift travels only while its plate is pressed. Wires
or matching colors show which plate drives which device. When a loop ends, a
rewind effect sweeps time backwards, and the finished attempt reappears as a
translucent, numbered echo that retraces its path while the player tries
again. Echoes that run out of recording stay frozen where they ended, still
holding their plate.

The first chamber teaches the idea with a single plate and door: one loop
holds the plate, the next walks through. The second chamber puts the exit high
above, so an echo must hold the lift's plate while the player rides up. The
third and final chamber has an exit door that needs two plates held at the
same time, far apart, with a laser hazard on the way, so two echoes must work
together; clearing it opens the vault for a victory screen.

Blocking an echo's path makes it glitch and triggers a styled PARADOX screen:
the player loses stability and the chamber restarts at its first loop.
Touching the laser also costs stability and restarts the current loop. When
stability runs out, a defeat screen announces the timeline collapsing and
offers a retry. Clearing a chamber shows the loops used and the vault's
progress toward the final chamber.

## Assets

2D assets are mounted read-only at:

- `/workspace/assets/library/` — Kenney CC0 packs (sprites, tiles, UI, fonts).
- `/workspace/assets/library-oga/` — OpenGameArt entries; respect each
  subdir's `LICENSE.txt`.

Browse the library and choose packs.
Copy what you need into your project's `assets/` folder.

## Project layout

```
/workspace/game/
  project.godot
  Main.tscn
  demo_outputs/    <- your input traces (1-10 files)
  scripts/  scenes/  assets/
```

The build must launch cleanly with:

```
godot --headless --path /workspace/game --quit-after 5
```

A reference for Godot CLI flags is at `/workspace/tools/godot_command_line.md`.
**Engine flags like `--headless` and `--quit-after N` must come BEFORE `--`** —
anything after `--` is forwarded to the project as user args and silently
ignored by the engine. Correct shape:
`godot --headless --quit-after 5 --path . -- --scenario near_victory`.

A screenshot helper is available at `/workspace/tools/screenshot.sh`. Use it to actually see what your UI / battlefield /
result screens look like.

```
/workspace/tools/screenshot.sh --path /workspace/game \
      -- --out /workspace/frame.png --frames 60
```

To screenshot a specific scenario, append `--scenario <id>` after `--`. The
helper consumes only `--out` / `--frames` / `--scene`; remaining args stay in
`OS.get_cmdline_user_args()` for your game code to read. Example:

```
/workspace/tools/screenshot.sh --path /workspace/game \
      -- --out /workspace/battle_debug.png --frames 120 --scenario battle
```

## Demos

Ship **1-10 input-trace files** under `/workspace/game/demo_outputs/`, one per
demo, each named `*.json`. The evaluator launches a fresh game per trace,
replays your trace as synthetic mouse and keyboard input at 1280x720, and
records the screen. Only the first 10 traces by filename are evaluated;
recordings longer than 20 s are sampled from a random 20 s window.

### Scenarios

Normal play should start from the title screen and demonstrate the task's
core gameplay loop.
Demo playback must be deterministic. For demos that need a specific state
(a specific level, combat state, upgrade screen, result state, or late-game
setup), define named scenarios your game loads when launched with:

```
godot --path /workspace/game -- --scenario <id>
```

When `--scenario <id>` is present the game must skip menus, set up the named
state deterministically (seed any RNG), and begin accepting input immediately.

### Trace file format

```json
{
  "scenario": "title_flow",
  "duration_frames": 360,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 300, "y": 360},
    {"frame": 90,  "type": "key_press",   "keycode": "1"},
    {"frame": 180, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 300, "type": "wait"}
  ]
}
```

- `scenario` — optional; omit for a normal game launch from the title screen.
- `duration_frames` — total frames to record at 30 fps; cap at **600 (20 s)**.
- `events` — time-ordered inputs. Coordinates are pixels in the 1280x720
  viewport. Supported types:
  - `mouse_click`: `{frame, type, button: "left"|"right", x, y}`
  - `mouse_down` / `mouse_up`: `{frame, type, button: "left"|"right", x, y}` —
    use these for drag interactions: emit `mouse_down` at the start point,
    one or more `mouse_move` events along the way, and `mouse_up` at the end.
    A `mouse_click` is a `mouse_down` + `mouse_up` at the same point in tight
    succession.
  - `mouse_move`: `{frame, type, x, y}`
  - `key_press` / `key_down` / `key_up`: `{frame, type, keycode}` — keycodes:
    `A`-`Z`, `0`-`9`, `ESCAPE`, `ENTER`, `SPACE`, `TAB`, `BACKSPACE`,
    `DELETE`, `SHIFT`, `CTRL`, `ALT`, `UP`, `DOWN`, `LEFT`, `RIGHT`.
  - `wait`: `{frame, type}` — anchor frame, no input.

Replay must be deterministic: same trace, fresh launch, same outcome every time.
