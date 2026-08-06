#!/usr/bin/env bash
# fableseek — Claude plans, DeepSeek implements.
#
# Runs the OFFICIAL claude binary against a third-party Anthropic-compatible
# provider by setting process-local env for this one run. Nothing global is
# rewritten (no ~/.claude/settings.json changes), nothing to switch back, and
# the Claude subscription/OAuth is never involved — the main interactive
# session and these subprocesses can run at the same time on different
# providers.
#
# Usage:
#   fableseek.sh [-P provider] "task spec"      # task as argument
#   fableseek.sh [-P provider] < spec.md        # task from stdin
#
# Providers (-P, must be the first argument; default: deepseek):
#   deepseek   needs DEEPSEEK_API_KEY   (https://platform.deepseek.com/api_keys)
#   kimi       needs MOONSHOT_API_KEY   (https://platform.moonshot.ai)
#   glm        needs ZHIPU_API_KEY      (https://open.bigmodel.cn)
#
# Env overrides:
#   FABLESEEK_MODEL      model name (required for kimi/glm; deepseek defaults
#                       to deepseek-v4-flash)
#   FABLESEEK_CONTEXT    context window to assume (default 1000000 for
#                       deepseek — V4 supports 1M; unset for kimi/glm)
#   FABLESEEK_JSON=1     --output-format json (includes session_id and cost)
#   FABLESEEK_RESUME=id  --resume that session for a follow-up round
#   FABLESEEK_UNSAFE=1   --dangerously-skip-permissions instead of the default
#                       acceptEdits + tool allowlist (disposable dirs only)
set -euo pipefail

PROVIDER="deepseek"
if [ "${1:-}" = "-P" ]; then
  PROVIDER="$2"
  shift 2
fi

CONTEXT="${FABLESEEK_CONTEXT:-}"

case "$PROVIDER" in
  deepseek)
    BASE_URL="https://api.deepseek.com/anthropic"
    KEY="${DEEPSEEK_API_KEY:?Set DEEPSEEK_API_KEY first}"
    MODEL="${FABLESEEK_MODEL:-deepseek-v4-flash}"
    if [ -z "$CONTEXT" ]; then
      CONTEXT=1000000
    fi
    ;;
  kimi)
    BASE_URL="https://api.moonshot.ai/anthropic"
    KEY="${MOONSHOT_API_KEY:?Set MOONSHOT_API_KEY first}"
    MODEL="${FABLESEEK_MODEL:?Set FABLESEEK_MODEL to a current Kimi model name}"
    ;;
  glm)
    BASE_URL="https://open.bigmodel.cn/api/anthropic"
    KEY="${ZHIPU_API_KEY:?Set ZHIPU_API_KEY first}"
    MODEL="${FABLESEEK_MODEL:?Set FABLESEEK_MODEL to a current GLM model name}"
    ;;
  *)
    echo "fableseek: unknown provider '$PROVIDER' (deepseek|kimi|glm)" >&2
    exit 1
    ;;
esac

if [ $# -ge 1 ]; then
  TASK="$*"
else
  TASK="$(cat)"
fi
if [ -z "$(printf '%s' "$TASK" | tr -d '[:space:]')" ]; then
  echo "fableseek: empty task spec" >&2
  exit 1
fi

PERM_ARGS=(--permission-mode acceptEdits --allowedTools "Read" "Edit" "Write" "Glob" "Grep" "Bash")
if [ "${FABLESEEK_UNSAFE:-0}" = "1" ]; then
  PERM_ARGS=(--dangerously-skip-permissions)
fi

EXTRA_ARGS=()
if [ -n "${FABLESEEK_RESUME:-}" ]; then
  EXTRA_ARGS+=(--resume "$FABLESEEK_RESUME")
fi
if [ "${FABLESEEK_JSON:-0}" = "1" ]; then
  EXTRA_ARGS+=(--output-format json)
fi

ENV_ARGS=(
  ANTHROPIC_BASE_URL="$BASE_URL"
  ANTHROPIC_API_KEY="$KEY"
  ANTHROPIC_AUTH_TOKEN="$KEY"
  ANTHROPIC_MODEL="$MODEL"
  ANTHROPIC_SMALL_FAST_MODEL="$MODEL"
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
)
if [ -n "$CONTEXT" ]; then
  ENV_ARGS+=(CLAUDE_CODE_MAX_CONTEXT_TOKENS="$CONTEXT")
fi

exec env "${ENV_ARGS[@]}" claude --model "$MODEL" "${PERM_ARGS[@]}" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} -p "$TASK"
