# fableseek

**Fable plans, DeepSeek implements.**

A Claude Code plugin for the planner/implementer split: a frontier Claude model (Claude Fable 5 — hence the name — or any Claude model) stays the architect and reviewer in your interactive session, while a cheap third-party model (DeepSeek V4 Flash by default; Kimi and GLM supported) does the implementation — running inside the **official Claude Code harness** as a one-shot headless subprocess.

The division of labor:

| Role | Model | Runs where | Auth |
|---|---|---|---|
| **Planner / reviewer** | Claude Fable 5 (or any Claude model) | your interactive Claude Code session | your Claude subscription (official) |
| **Implementer** | `deepseek-v4-flash` (escalate to `deepseek-v4-pro`) | headless `claude -p` subprocess, same repo | DeepSeek API key |

The planner owns everything that needs judgment or identity: task decomposition, spec writing, diff review, running tests, git, and any claude.ai connectors. The implementer owns the keyboard: reading files, writing code, iterating until the verify commands pass.

```
        one conversation (you only talk to Claude)
┌──────────────────────────────────────────────────┐
│  you: "build X"                                  │
│   │                                              │
│   ▼                                              │
│  Claude (planner, your subscription)             │
│   │ 1. plan, write a self-contained spec         │
│   │ 2. fableseek.sh "spec"  ────────────┐         │
│   │                                    ▼         │
│   │                     headless claude -p       │
│   │                     full official harness    │
│   │                     model: deepseek-v4-flash │
│   │                     auth: DeepSeek API key   │
│   │ 3. edits land in the same repo ◀───┘         │
│   │ 4. Claude reviews diff, runs tests,          │
│   │    re-dispatches fixes if needed             │
│   ▼                                              │
│  Claude reports back to you                      │
└──────────────────────────────────────────────────┘
```

## Why this shape

- **One `ANTHROPIC_BASE_URL` per session.** Claude Code has no native way to point a subagent at a different provider, so mixing models means a second process.
- **Compliance.** Anthropic's 2026 policy forbids using Claude subscription OAuth in third-party harnesses or proxies. fableseek never touches your subscription: the interactive session stays on official auth, and the dispatched process authenticates with the provider's own API key against the provider's own endpoint. No proxy sits in front of Anthropic traffic — there is nothing here to get banned for.
- **Per-invocation, not global.** Unlike config switchers (cc-switch etc.), nothing in `~/.claude/settings.json` changes, there is no state to switch back, and both providers run at the same time.

## Install

```
/plugin marketplace add leepokai/fableseek
/plugin install fableseek@fableseek
```

Set your key (once, in `~/.zshrc` or equivalent):

```bash
export DEEPSEEK_API_KEY=sk-...   # https://platform.deepseek.com/api_keys
```

Then just ask Claude to "dispatch this to DeepSeek" (or invoke `/fableseek`). Claude plans, dispatches, reviews the diff, and runs the tests.

**Optional — short command.** Symlink the script onto your PATH so dispatch is one word from any repo:

```bash
ln -sf "$(pwd)/skills/fableseek/fableseek.sh" ~/.local/bin/fableseek
```

## Direct usage

```bash
fableseek "task spec"                      # DeepSeek V4 Flash (default)
fableseek < spec.md                        # spec streamed via stdin (any size)
FABLESEEK_MODEL=deepseek-v4-pro fableseek "harder task"
fableseek -P kimi "task"                   # needs MOONSHOT_API_KEY + FABLESEEK_MODEL
fableseek -P glm  "task"                   # needs ZHIPU_API_KEY + FABLESEEK_MODEL
```

| Env | Effect |
|---|---|
| `FABLESEEK_MODEL` | model name (default `deepseek-v4-flash`; required for kimi/glm) |
| `FABLESEEK_CONTEXT` | context window to assume (default 1,000,000 for DeepSeek V4) |
| `FABLESEEK_JSON=1` | JSON output with `session_id` and cost |
| `FABLESEEK_RESUME=<id>` | continue a previous implementer session |
| `FABLESEEK_UNSAFE=1` | `--dangerously-skip-permissions` (disposable dirs/worktrees only) |

## Getting the most out of the implementer

1. **The spec is the interface.** The implementer shares none of your conversation. Include: goal, key file paths, conventions, concrete expected changes, exact verify commands, and limits (`do NOT commit/push`).
2. **Make it self-verify.** The dispatched process can run shell commands — give it the test command and tell it to iterate until green.
3. **Iterate through resumes, not fresh runs.** `FABLESEEK_JSON=1` returns a `session_id`; `FABLESEEK_RESUME=<id>` continues with full context. DeepSeek's cache-hit pricing (~$0.003/M input) makes follow-up rounds nearly free.
4. **Escalation ladder.** V4 Flash for mechanical work → `deepseek-v4-pro` for multi-file refactors and tricky logic → do it in the main session when two rounds fail.
5. **Parallel fan-out.** Cheap tokens make parallelism affordable: dispatch independent tasks concurrently, each in its own git worktree to avoid edit collisions.
6. **Exploit the harness.** The subprocess loads the repo's `CLAUDE.md`, skills, and local MCP servers automatically — keep project conventions in `CLAUDE.md` and the implementer inherits them for free.

## Edge cases & troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Set DEEPSEEK_API_KEY first` | Export the key in your shell profile; restart the session so its shell snapshot includes it |
| `claude.ai connectors are disabled` warning | Expected: the subprocess uses API-key auth, so claude.ai-login connectors (Gmail etc.) don't load there. Locally configured MCP servers still work. Keep connector-dependent steps in the main session |
| `"deepseek-v4-flash" is not a model this version recognizes` | Cosmetic; fableseek already sets `CLAUDE_CODE_MAX_CONTEXT_TOKENS` so the 1M window is used |
| 401 / auth errors from the subprocess | Key invalid or out of balance — test with a raw `curl` against `https://api.deepseek.com/anthropic/v1/messages` |
| Implementer reports success but nothing changed | Never trust the self-report: check `git diff` and run tests. Re-dispatch quoting the concrete defects |
| Edits landed in the wrong place | The subprocess runs in the caller's cwd — dispatch from the target repo root |
| Two dispatches stepped on each other | Parallel runs in one checkout collide — use one git worktree per task |
| Spec too large for argv | Pipe it via stdin: `fableseek < spec.md` — streamed straight to the CLI, never enters argv |
| `total_cost_usd` in JSON output looks huge | It's computed with Anthropic pricing tables and is meaningless for third-party models — check the provider's own usage dashboard |
| Global provider overrides (cc-switch etc.) interfering | fableseek sets env explicitly per process, but a provider block in `~/.claude/settings.json` can still conflict — keep global settings on official defaults |
| Implementer committed/pushed on its own | Say `do NOT commit or push` in every spec (the planner owns git); review before committing |

## Security notes

- API keys are read from env only — never hardcoded, never written to disk by this tool. Note that env-based auth is visible to same-user processes (`ps eww`) for the run's duration, as with any env-configured CLI.
- Your Claude subscription OAuth token is never read, forwarded, or proxied.
- Default permission mode is `acceptEdits` with an explicit tool allowlist; `FABLESEEK_UNSAFE=1` is opt-in and meant for disposable worktrees.
- Headless `claude -p` skips the workspace-trust dialog — only dispatch into directories you trust.

## License

MIT
