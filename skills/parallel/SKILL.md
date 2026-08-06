---
name: parallel
description: Use when implementation work splits into independent tasks that could run at the same time — the user asks to parallelize, or a plan contains 2+ tasks touching disjoint files.
---

# parallel — fan out independent dispatches

One git worktree per task; implementers never share a checkout.

## Precondition (strict)

Tasks are independent only if they touch **disjoint files** AND none needs another's output. Two tasks editing the same file are NOT independent — the merge will conflict. If unsure, serialize.

## Mechanics

```bash
# 1. one worktree + branch per task (from the repo root)
git worktree add ../<repo>-task1 -b fable/task1
git worktree add ../<repo>-task2 -b fable/task2

# 2. one spec per task (standard template), LIMITS scoped to that task's files

# 3. dispatch concurrently — preferred: one fableseek:implementer agent per
#    task; or background shell dispatches:
(cd ../<repo>-task1 && FABLESEEK_JSON=1 fableseek < /path/spec1.md > /path/out1.json) &
(cd ../<repo>-task2 && FABLESEEK_JSON=1 fableseek < /path/spec2.md > /path/out2.json) &
wait

# 4. review each worktree's diff and run its verify commands independently

# 5. merge from the main checkout, one at a time
git merge --no-ff fable/task1 && git merge --no-ff fable/task2
# a conflict means the split was not independent — redo that task serially

# 6. cleanup
git worktree remove ../<repo>-task1 && git branch -d fable/task1
```

## Notes

- Concurrent dispatches share the warmed prompt-cache prefix — fan-out is cheap.
- Review each task before merging any; a broken task should be dropped or re-dispatched, not merged and patched later.
- Never run two dispatches in one checkout.
