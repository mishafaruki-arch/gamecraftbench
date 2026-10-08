# GameDevBench Final

> Derived from [GameCraft-Bench](https://github.com/FreedomIntelligence/gamecraft-bench)
> ([paper](https://arxiv.org/abs/2606.17861)), Apache-2.0. This is not the
> official GameCraft-Bench repository; see "Changes from upstream" below.

A self-contained GameCraft-Bench-style package with one Harbor task, **Echo Vault**
(`tasks/puzzle-echo-vault`), plus the verifier, judge, and run scripts needed to
generate and grade it.

Echo Vault asks an agent to build a 2D time-loop puzzle platformer in Godot 4:
three chambers where recordings of the player's earlier loops ("echoes") hold
plates and power a lift so the live player can reach the exit.

## Layout

```
tasks/puzzle-echo-vault/     Harbor task
  task.toml                  task config (validates against `harbor task schema`)
  instruction.md             spec given to the agent (GameCraft-Bench format)
  environment/Dockerfile
  tests/test.sh              verifier entrypoint (Harbor reads /logs/verifier/reward.txt)
  tests/rubric.json          hidden rubric: 17 requirements + score formula
  solution/solve.sh          reference ("oracle") solution
  solution/files/            reference game source and 5 demo traces
gamecraft_bench/             local environment, local agents, verifier, judges
scripts/                     run wrappers and asset fetchers
tools/                       screenshot helper mounted at /workspace/tools
```

## Requirements

Linux (the sandbox uses mount namespaces; the verifier uses Xvfb, xdotool, and
ffmpeg), run as root, with Godot 4.6.2 on `PATH`. See the system dependency
list in the upstream GameCraft-Bench README. On macOS, run inside a Linux VM.

```bash
uv venv --python 3.12 .venv && source .venv/bin/activate
uv pip install -e .
cp .env.example .env              # fill in keys
python scripts/fetch_assets.py
python scripts/fetch_oga_assets.py --license CC0
```

## Run

```bash
# Reference solution / do-nothing sanity checks
./scripts/run.sh -p tasks/puzzle-echo-vault --agent oracle
./scripts/run.sh -p tasks/puzzle-echo-vault --agent nop

# Models
./scripts/run_kimi_k3_vercel.sh -p tasks/puzzle-echo-vault          # Kimi K3 via Vercel AI Gateway
./scripts/run_codex_gpt_6_astra.sh --ak reasoning_effort=high -p tasks/puzzle-echo-vault
./scripts/run_codex_gpt_5_6_terra.sh --ak reasoning_effort=high -p tasks/puzzle-echo-vault
```

Results land in `../gamecraft-bench-jobs/<job>/<trial>/verifier/` (`reward.txt`,
`breakdown.json`, `judge_log.json`, demo videos).

Agents run as root with filesystem access. Run from a copy whose parent
directories do not expose the task's `tests/` or `solution/` to the agent.

## Changes from upstream GameCraft-Bench

- `verifier/judges/openai_gpt.py`: sends `max_completion_tokens` (current OpenAI
  models reject `max_tokens`), raises the limit to 16384 to leave room for
  reasoning tokens, and retries empty or unparseable responses up to 3 times
  instead of scoring them 0.
- `local_env.py`: applies Harbor's scoped agent env (`--ae`) in `exec`, so
  agent-only credentials such as the Kimi gateway key reach the agent.
- `scripts/run_kimi_k3_vercel.sh`: new; runs the Kimi Code CLI against
  `moonshotai/kimi-k3` on the Vercel AI Gateway.

## License

Apache-2.0 (see `LICENSE`), as upstream.
