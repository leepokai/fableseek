---
name: fableseek
description: Use when a coding task should be implemented by a third-party model (DeepSeek, Kimi, GLM) while Claude plans and reviews — e.g. the user asks to dispatch implementation to DeepSeek, delegate to a cheap implementer model, or invokes /fableseek.
---

# fableseek — Claude plans, DeepSeek implements

## Overview

Claude stays the planner/reviewer in the current session; implementation is dispatched to a third-party model running inside the **official Claude Code harness** as a one-shot headless subprocess (`claude -p`). Provider credentials are process-local env — nothing global is rewritten, and the user's Claude subscription is never proxied.

## Workflow

1. **Plan.** Write a self-contained spec (template below) to a file **outside the target repo** (temp/scratch dir — a spec inside the repo pollutes the diff). The implementer has ZERO conversation context — the spec is the entire interface.
2. **Dispatch in the background** from the target repo's root, always with `FABLESEEK_JSON=1` (captures `session_id` for follow-ups, plus cost). A dispatch takes 1–5 minutes — it is background work by nature, like a subagent: fire it, keep planning or talking, and let the completion notification trigger the review. Use the `fableseek` command if on PATH; otherwise the script at `<this skill's base directory>/fableseek.sh`:

   ```bash
   FABLESEEK_JSON=1 fableseek < /path/outside/spec.md > /path/outside/out.json
   ```

   Pick the form by weight:
   - **trivial, and the next step needs the result immediately** → foreground (timeout 240s+)
   - **single task you will review yourself** → background shell dispatch (as above)
   - **non-trivial, retries likely, or parallel** → spawn one `fableseek:implementer` agent per task; it supervises the whole dispatch → review → retry ladder asynchronously

   The script automatically prepends an implementer preamble (role, machine-report contract, no-commit rule) — do not duplicate that framing in specs; `FABLESEEK_RAW=1` sends the task verbatim instead.
3. **Review when the completion notification arrives.** Run `git diff`, read the changes, run the project's tests yourself. Never trust the implementer's own success report. For real cost, run `fableseek-cost <json-file>` (bundled next to the script) — `total_cost_usd` in the JSON uses Anthropic pricing and is meaningless here.
4. **Iterate.** Re-dispatch with `FABLESEEK_RESUME=<session_id>` quoting the concrete defects — the implementer keeps its context and provider cache-hit pricing makes reruns nearly free. After two failed rounds, escalate to `FABLESEEK_MODEL=deepseek-v4-pro` or implement it yourself.

## Spec template

```
GOAL: <one sentence>
CONTEXT: <repo layout, key file paths, conventions to match>
CHANGES: <concrete edits expected; interfaces/signatures to preserve>
VERIFY: <exact commands to run until green>
LIMITS: do NOT commit or push; do not touch files outside <scope>; <non-goals>
```

## Quick reference

| What | How |
|---|---|
| Default implementer | DeepSeek V4 Flash, 1M context (needs `DEEPSEEK_API_KEY`) |
| Other providers | `-P kimi` (`MOONSHOT_API_KEY`), `-P glm` (`ZHIPU_API_KEY`) — both also need `FABLESEEK_MODEL` |
| Stronger model | `FABLESEEK_MODEL=deepseek-v4-pro` |
| Structured output / session id | `FABLESEEK_JSON=1` |
| Continue an implementer session | `FABLESEEK_RESUME=<session_id>` |
| Skip permission prompts | `FABLESEEK_UNSAFE=1` (only inside disposable dirs or git worktrees) |
| Defaults / key storage | `~/.config/fableseek/config` (KEY=VALUE; env wins). First-time setup: `/fableseek:setup` |

## When NOT to dispatch

Dispatch overhead (~50s harness startup + spec writing) outweighs savings for: single-file edits under ~100 lines of change, architectural decisions, or work whose spec would be longer than the diff. Do those yourself. Dispatch shines on mechanical multi-file work, well-specified features, and batch transformations. Decide delegation when planning, before deep-reading the files — reading everything first spends the planner tokens the split is meant to save.

## Delegating the whole cycle

Instead of running the dispatch loop inline, spawn the plugin's `fableseek:implementer` agent with the spec — it handles dispatch, diff review, verification, and the retry ladder in the background and returns a structured report. Prefer this for anything non-trivial, and for parallel work spawn one agent per independent task.

## Parallel and risky work

- **Independent tasks:** dispatch each in its own git worktree, then merge — parallel implementers in one checkout collide on edits.
- **Large or risky rewrites:** worktree + `FABLESEEK_UNSAFE=1` scoped to that worktree only.

## Common mistakes

- **Vague specs produce junk.** Write the spec like a ticket for a contractor with zero context; include verification commands so the implementer can self-check until green.
- **Wrong cwd.** The subprocess edits files relative to where it runs; always dispatch from the target repo root.
- **`-P` must be the first argument.**
- **Missing key.** The script exits with `Set DEEPSEEK_API_KEY first` — ask the user for their key; never hardcode or invent one.
- **The warning `claude.ai connectors are disabled` in subprocess output is expected** (API-key auth), not an error.
- **Never point the script's env at the user's Claude subscription or OAuth token.** Subscription auth stays in the official interactive session only; dispatch always uses the provider's own API key.
