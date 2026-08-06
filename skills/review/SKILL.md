---
name: review
description: Use when the user wants DeepSeek to review code — review a diff, PR, or repo with the cheap model, a second pair of eyes before committing — without letting it modify anything.
---

# review — dispatch a read-only review

DeepSeek reviews, the planner triages. Findings come back as a report; accepted fixes go through a normal implement dispatch afterwards — never in the same run.

## Spec template (read-only variant)

```
GOAL: review <target> (repo | diff range | specific files)
CONTEXT: what the code is and where it lives; for diff reviews, the exact `git diff <range>` to run
DIMENSIONS: name them explicitly — e.g. correctness, security, docs/code consistency, robustness, performance
OUTPUT: your final message must be exactly: VERDICT (one line); FINDINGS (numbered, each = severity HIGH/MED/LOW, file:line, what is wrong, concrete fix); NITS (optional). No praise padding.
VERIFY: n/a — the report is the deliverable. Read-only checks (bash -n, linters, --help) are allowed to confirm claims before reporting them.
LIMITS: READ-ONLY — do NOT modify, create, or delete files; do NOT commit; do NOT call external services.
```

## Dispatch and confirm

```bash
FABLESEEK_JSON=1 fableseek < /path/outside/review-spec.md > out.json
jq -r '.result' out.json          # the report
git status --porcelain            # MUST be empty — confirm read-only held
```

## Triage discipline (the planner's half)

- Verify every HIGH/MED yourself before acting. Expect false positives wherever project or harness context is missing — the reviewer doesn't know your conventions or your platform's mechanisms.
- Its mechanical claims are usually verified (it runs read-only checks); weight those above its architectural opinions.
- Escalate to `FABLESEEK_MODEL=deepseek-v4-pro` for subtle logic or security reviews.
