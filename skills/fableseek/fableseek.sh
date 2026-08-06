#!/usr/bin/env bash
# fableseek — Fable plans, DeepSeek implements.
#
# Runs the OFFICIAL claude binary against a third-party Anthropic-compatible
# provider by setting process-local env for this one run. Nothing global is
# rewritten (no ~/.claude/settings.json changes), nothing to switch back, and
# the Claude subscription/OAuth is never involved — the main interactive
# session and these subprocesses can run at the same time on different
# providers.
#
# Usage:
#   fableseek [-P provider] "task spec"      # task as argument
#   fableseek [-P provider] < spec.md        # spec streamed via stdin
#
# Providers (-P, must be the first argument; default: deepseek):
#   deepseek   needs DEEPSEEK_API_KEY   (https://platform.deepseek.com/api_keys)
#   kimi       needs MOONSHOT_API_KEY   (https://platform.moonshot.ai)
#   glm        needs ZHIPU_API_KEY      (https://open.bigmodel.cn)
#
# Env overrides:
#   FABLESEEK_MODEL      model name (required for kimi/glm; deepseek defaults
#                        to deepseek-v4-flash)
#   FABLESEEK_CONTEXT    context window to assume, integer tokens (default
#                        1000000 for deepseek — V4 supports 1M)
#   FABLESEEK_JSON=1     --output-format json (includes session_id and cost)
#   FABLESEEK_RESUME=id  --resume that session for a follow-up round
#   FABLESEEK_UNSAFE=1   --dangerously-skip-permissions instead of the default
#                        acceptEdits + tool allowlist (disposable dirs only)
set -euo pipefail

command -v claude >/dev/null 2>&1 || {
  echo "fableseek: claude CLI not found in PATH" >&2
  exit 127
}

# Optional defaults file (~/.config/fableseek/config, KEY=VALUE lines).
# Explicit env always wins. Keys are allowlisted — the file is parsed, never
# sourced, so it cannot execute code. FABLESEEK_RESUME is deliberately
# excluded (session-specific, never a default).
CONFIG_FILE="${FABLESEEK_CONFIG:-$HOME/.config/fableseek/config}"
if [ -f "$CONFIG_FILE" ]; then
  while IFS='=' read -r k v; do
    case "$k" in
      DEEPSEEK_API_KEY|MOONSHOT_API_KEY|ZHIPU_API_KEY|FABLESEEK_MODEL|FABLESEEK_CONTEXT|FABLESEEK_UNSAFE|FABLESEEK_JSON)
        if [ -z "${!k:-}" ]; then
          export "$k=$v"
        fi
        ;;
    esac
  done < "$CONFIG_FILE"
fi

PROVIDER="deepseek"
if [ "${1:-}" = "-P" ]; then
  PROVIDER="${2:-}"
  if [ -z "$PROVIDER" ]; then
    echo "fableseek: -P requires a provider (deepseek|kimi|glm)" >&2
    exit 1
  fi
  shift 2
fi
for arg in "$@"; do
  if [ "$arg" = "-P" ]; then
    echo "fableseek: -P must be the first argument" >&2
    exit 1
  fi
done

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

case "$CONTEXT" in
  ''|*[!0-9]*)
    if [ -n "$CONTEXT" ]; then
      echo "fableseek: FABLESEEK_CONTEXT must be an integer token count, got '$CONTEXT'" >&2
      exit 1
    fi
    ;;
esac

# Argument form passes the task via argv; stdin form streams the spec straight
# through to `claude -p`, so huge specs never hit ARG_MAX.
PROMPT_ARGS=(-p)
if [ $# -ge 1 ]; then
  TASK="$*"
  if [ -z "$(printf '%s' "$TASK" | tr -d '[:space:]')" ]; then
    echo "fableseek: empty task spec" >&2
    exit 1
  fi
  PROMPT_ARGS=(-p "$TASK")
elif [ -t 0 ]; then
  echo 'usage: fableseek [-P deepseek|kimi|glm] "task spec"   (or pipe a spec via stdin)' >&2
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

# Same key under both names: DeepSeek's docs specify ANTHROPIC_API_KEY, while
# some Anthropic-compatible providers read the bearer ANTHROPIC_AUTH_TOKEN.
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

exec env "${ENV_ARGS[@]}" claude --model "$MODEL" "${PERM_ARGS[@]}" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} "${PROMPT_ARGS[@]}"
