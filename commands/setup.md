---
description: Set up fableseek — API key, PATH shortcut, defaults, smoke test
---

Set up fableseek for this user. The plugin's files live at `${CLAUDE_PLUGIN_ROOT}` (script: `${CLAUDE_PLUGIN_ROOT}/skills/fableseek/fableseek.sh`). Work through these steps, reporting progress as you go:

1. **API key.** Check whether `DEEPSEEK_API_KEY` is set in the environment or present in `~/.config/fableseek/config`. If missing, ask the user for their key (from https://platform.deepseek.com/api_keys), then store it in `~/.config/fableseek/config` as `DEEPSEEK_API_KEY=<key>` (create the directory if needed, `chmod 600` the file). The script reads this file automatically, so no shell-profile edit is required — only add it to the shell profile if the user explicitly prefers that. Never echo the key back in full; mask all but the last 4 characters.

2. **PATH shortcut.** Create a one-word command: verify `~/.local/bin` is on `PATH` (fall back to `/usr/local/bin` if writable, or ask), then `ln -sf "${CLAUDE_PLUGIN_ROOT}/skills/fableseek/fableseek.sh" ~/.local/bin/fableseek`. Confirm `command -v fableseek` resolves.

3. **Smoke test.** Verify the key works with a minimal request against the provider endpoint:
   ```bash
   curl -sS --max-time 30 https://api.deepseek.com/anthropic/v1/messages \
     -H "x-api-key: $DEEPSEEK_API_KEY" -H "anthropic-version: 2023-06-01" \
     -H "content-type: application/json" \
     -d '{"model":"deepseek-v4-flash","max_tokens":16,"messages":[{"role":"user","content":"Reply with exactly: OK"}]}'
   ```
   (Read the key from the config file if it is not in the environment.) Report success or the error returned.

4. **Optional defaults.** Ask whether the user wants defaults written to `~/.config/fableseek/config`, e.g. `FABLESEEK_MODEL=deepseek-v4-pro` (stronger implementer) or `FABLESEEK_CONTEXT=<tokens>`. Explicit env vars always override the file.

5. **Wrap up.** Show a one-line usage recap (`fableseek "task"`, `fableseek < spec.md`, `-P kimi|glm`) and mention that in conversation the user can simply ask Claude to "dispatch this to DeepSeek".
