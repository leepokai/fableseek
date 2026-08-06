---
name: ask
description: Use when the user wants DeepSeek's answer or opinion directly — a second opinion, a model comparison, "ask/try DeepSeek", a quick question to the cheap model — without dispatching an implementation task or touching files.
---

# ask — query DeepSeek directly

One API call, answer on stdout. No subprocess harness, no tools, no file access — seconds instead of minutes. For implementation work, use the fableseek skill instead.

```bash
fableseek-ask "question"                       # or the bundled skills/ask/fableseek-ask
fableseek-ask < prompt.md                      # long prompts via stdin
FABLESEEK_MODEL=deepseek-v4-pro fableseek-ask "harder question"
FABLESEEK_ASK_THINKING=1 fableseek-ask "..."   # also print reasoning (stderr)
```

- The model has no context — include everything relevant in the prompt (paste the code, don't reference files).
- Second-opinion pattern: give it your own conclusion and ask it to attack, not confirm ("Here is my analysis: … Try to refute it.").
- Thinking counts against `FABLESEEK_ASK_MAX_TOKENS` (default 4096); an "empty text response" error means raise it, not that the key is broken.
- Needs `DEEPSEEK_API_KEY` (env or `~/.config/fableseek/config`) and `jq`.
