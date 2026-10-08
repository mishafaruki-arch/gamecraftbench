#!/bin/bash
# Run Harbor with the Kimi Code CLI + Kimi K3 via the Vercel AI Gateway
# (OpenAI-compatible endpoint).
#
# Usage:
#   ./scripts/run_kimi_k3_vercel.sh -p tasks/puzzle-echo-vault
#
# Requires VERCEL_AI_GATEWAY_API_KEY (model) and OPENAI_API_KEY (judge) in .env.
# The model endpoint, key, and name reach the agent through Kimi Code's
# KIMI_MODEL_* variables, so the judge's OPENAI_API_KEY is left untouched.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [ -f ".venv/bin/activate" ]; then
    # shellcheck disable=SC1091
    source ".venv/bin/activate"
fi

if [ -f ".env" ]; then
    set -a
    # shellcheck disable=SC1091
    source ".env"
    set +a
fi

export PYTHONPATH="$REPO_ROOT:${PYTHONPATH:-}"

if [ -z "${VERCEL_AI_GATEWAY_API_KEY:-}" ]; then
    echo "error: VERCEL_AI_GATEWAY_API_KEY not set (export it or put it in .env)" >&2
    exit 1
fi

: "${KIMI_MODEL:=moonshotai/kimi-k3}"
: "${VERCEL_AI_GATEWAY_BASE_URL:=https://ai-gateway.vercel.sh/v1}"

# Default to --no-delete unless the caller passed an explicit choice.
delete_flag="--no-delete"
for arg in "$@"; do
    case "$arg" in
        --delete|--no-delete) delete_flag=""; break ;;
    esac
done

: "${GAMECRAFT_BENCH_JOBS_ROOT:=$REPO_ROOT/../gamecraft-bench-jobs}"
mkdir -p "$GAMECRAFT_BENCH_JOBS_ROOT"

exec harbor run \
    --environment-import-path gamecraft_bench.local_env:LocalSubprocessEnvironment \
    --agent kimi-code \
    --jobs-dir "$GAMECRAFT_BENCH_JOBS_ROOT" \
    --model "$KIMI_MODEL" \
    --ae "KIMI_MODEL_BASE_URL=$VERCEL_AI_GATEWAY_BASE_URL" \
    --ae "KIMI_MODEL_API_KEY=$VERCEL_AI_GATEWAY_API_KEY" \
    --ae "KIMI_MODEL_CAPABILITIES=image_in,thinking" \
    ${delete_flag} \
    "$@"
