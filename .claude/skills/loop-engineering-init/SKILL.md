---
name: loop-engineering-init
description: Interactively scaffold a cobusgreyling/loop-engineering pattern (daily-triage, thin-loop, pr-babysitter, etc.) into the current repo by calling `npx @cobusgreyling/loop init`, then run `doctor` for the Loop Ready score. Use when the user wants to set up loop-engineering, initialize a maintenance loop, or scaffold STATE.md/LOOP.md for an autonomous repo-triage/PR-watch loop.
---

# Loop Engineering Init

Wraps `npx @cobusgreyling/loop init` (https://github.com/cobusgreyling/loop-engineering) in an interactive setup instead of the user having to memorize flags. This tool is for **recurring repo-maintenance loops** (triage, PR babysitting, CI sweeping) — not for a single bounded coding task with a done-condition (that's `/code-loop` in this repo instead).

## Step 1 — Ask what they want

If not already stated, ask which pattern fits, showing these options (from the project's `patterns/registry.yaml`):

| Pattern | Cadence | Week 1 | Cost | Fits when… |
|---|---|---|---|---|
| `daily-triage` | 1d–2h | L1 report | Low | general "keep this repo healthy" (default recommendation) |
| `thin-loop` | event + 1d | L1 snapshot | Very low | want the lightest possible setup, no `STATE.md` |
| `pr-babysitter` | 5–15m | L1 watch | High | actively landing/watching PRs |
| `ci-sweeper` | 5–15m | L2 cautious | Very high | flaky/failing CI needs constant attention |
| `dependency-sweeper` | 6h–1d | L2 patch-only | Medium | dependency bumps |
| `changelog-drafter` | 1d or tag | L1 draft | Low | changelog upkeep |
| `post-merge-cleanup` | 1d–6h | L1 off-peak | Low | leftover TODOs/changelog noise after merges |
| `issue-triage` | 2h–1d | L1 propose-only | Low | issue backlog grooming |

Also confirm `--tool` (default `claude` — this is a Claude Code session, so default to that unless told otherwise). Note: only `claude`, `grok`, `codex`, `opencode` are auto-scaffolded; `cursor`/`windsurf`/`openclaw` require manual copying (see the repo's `examples/<tool>/`).

Do not guess the pattern if genuinely ambiguous — ask. Do proceed with the `claude`-tool default without asking, since this is a Claude Code session.

## Step 2 — Confirm before writing files

`loop init` writes `STATE.md`, `LOOP.md`, `loop-budget.md`, `loop-run-log.md`, and a `gate.yaml` (merge allow/denylist) into the repo root. Tell the user what will be created and get a go-ahead before running, the same as any other action that adds multiple new files to a repo.

## Step 3 — Run it

```bash
npx @cobusgreyling/loop init . --pattern <pattern> --tool claude
```

Then immediately audit it:

```bash
npx @cobusgreyling/loop doctor .
```

(`doctor` = `audit` + `sync` + top-3 next actions in one call.)

## Step 4 — Report back

- Show the Loop Ready score and the top suggested next actions from `doctor`.
- List the files that were created (`git status --short`).
- Remind the user: **week one is report-only** — no auto-fix, no auto-merge. Nothing should run unattended (L2/L3) until a verifier has been correct for a while; see the repo's `docs/loop-design-checklist.md` before enabling anything beyond L1.
- Don't commit these scaffolded files automatically — let the user review them first, same as any other change.

## Notes

- This only wraps the one-time `init`/`doctor` setup step via `npx`. The recurring loop itself (`/loop 1d $loop-triage` etc.) is invoked through Claude Code's own `/loop` skill once the pattern's skill files exist — it does not need `npx` per run.
- If the user wants the repo's own Claude Code skills (not just the scaffolded files) available as `$loop-triage`-style skills, that requires installing the plugin (`claude plugin marketplace add cobusgreyling/loop-engineering` + `claude plugin install loop-engineering`) — a separate step from this skill, and one you should not run without asking, since it registers an external marketplace.
