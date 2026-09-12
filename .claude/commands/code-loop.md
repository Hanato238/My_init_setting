---
description: General-purpose coding task prompt — run standalone or as the payload for /loop
argument-hint: task: <what to build/fix> | done: <acceptance criteria, incl. how to verify> | scope: <optional, files/dirs allowed> | max-iterations: <optional, default 10>
---

You are executing one iteration of a general-purpose coding task. Parse `$ARGUMENTS` for these fields (labeled, free text, any order):

- **task** (required): what to implement/fix/change.
- **done** (required): the acceptance criteria, including how to verify it (e.g. "npm test passes with 0 failures", "the CLI prints X for input Y"). This is the only source of truth for "are we finished" — do not invent your own definition of done.
- **scope** (optional): files/directories you may touch. If omitted, use judgment but keep changes minimal and confined to what the task requires — no unrelated refactors.
- **max-iterations** (optional, default 10): hard cap on total iterations for this task if run under `/loop`.

If **task** or **done** is missing or too vague to act on, do not guess — stop this iteration and report exactly what's missing.

## Each iteration

1. **Orient**: check current state (`git status`, `git diff`, recent commits) to see what prior iterations (if any) already did toward this same task.
2. **Act**: make one focused, incremental change toward the task, within `scope` if given. Don't add abstractions, error handling, or refactors beyond what the task needs.
3. **Verify**: run whatever check the `done` criteria imply (e.g. run the specified test/build command). Do not mark done without running the actual verification.
4. **Record locally only**: if the change is an improvement, commit it locally with a clear message. Never `git push`, never force-push, never touch files outside `scope`. Pushing/PR creation is a separate step the user does after reviewing.
5. **Classify this iteration's outcome** and report it as a single status line:
   - `DONE` — done criteria fully verified as satisfied. Stop; do not continue further iterations.
   - `PROGRESS` — meaningful change made and committed, criteria not yet met, continue.
   - `NOOP` — no meaningful progress this iteration (same failure, blocked, nothing left to try differently). Track consecutive NOOPs.
   - `STUCK` — 3 consecutive NOOPs, or a blocker that won't resolve by repeating this loop (e.g. missing credentials, ambiguous spec). Stop; do not continue.
   - `MAX_ITERATIONS` — max-iterations reached without meeting done criteria. Stop.

## Final report (on DONE / STUCK / MAX_ITERATIONS)

Give a structured summary:
- **Status**: one of the outcomes above.
- **Commits made**: list of local commit hashes + one-line messages.
- **Verification result**: what the done-criteria check actually showed.
- **Remaining work** (if not DONE): what's left, or why it's stuck.
- Note explicitly that nothing was pushed and the user should review the local commits before pushing.
