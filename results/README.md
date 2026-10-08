# Results: Echo Vault (tasks/puzzle-echo-vault)

| Run | Clips used | Score |
|---|---|---:|
| Oracle (reference solution, `--agent oracle` through Harbor) | reference demos | 0.942 |
| Kimi K3 (`moonshotai/kimi-k3`, Kimi Code CLI 2.1.1 via Vercel AI Gateway) | Kimi's own demos (standard Harbor scoring) | 0.644 |
| Kimi K3, same game | full clip set (below) | 0.910 |

Judge: OpenAI `gpt-5.5`. One trial each. Run date 2026-10-08.

## Why two Kimi scores

Standard GameCraft-Bench scoring only sees the demo traces the agent writes.
Kimi's traces tapped `R` with instant `key_press` events, but its game polls
`R` once per physics tick (`scripts/chamber.gd:324`), so most taps were missed
during the real xdotool replay: chamber 1 and chamber 3 were never solved on
camera (D1 = D3 = 0). Its laser trace also stopped the player just past the
beam, so no laser hit was recorded. Kimi had checked its traces with its own
in-game replayer, which does not reproduce this timing.

The full clip set (`kimi-k3/full-clips/traces/`) measures what the game does:

- Kimi's 9 traces, with every instant `key_press` rewritten as `key_down` plus
  `key_up` 4 frames (0.13 s) later. Nothing else changed.
- `05_paradox.json`: extended past the PARADOX screen (press Enter, keep
  recording) so the restart at loop 1 is visible.
- `10_laser_defeat.json`: new; uses Kimi's `laser_setup` scenario, stops the
  player in the beam (48-frame hold) three times, then retries from the
  defeat screen.

## Remaining Kimi losses (full clip set)

- A3 animation 0.62 and A4 menu polish 0.78: averaged over all clips, including
  short screen-only clips.
- M1 movement 0.8, M5 paradox 0.85, V3 device readability 0.9.

## Layout

```
oracle/                       reward.txt, breakdown.json, judge_log.json
kimi-k3/game/                 the game Kimi built (without .godot cache)
kimi-k3/harbor-standard/      Kimi's own traces, scores, and videos
kimi-k3/full-clips/           full clip set traces, scores, and videos
```
