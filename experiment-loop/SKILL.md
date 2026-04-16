---
name: experiment-loop
description: Autonomous optimization loop for any file with any measurable scalar metric. Use this when the user wants to "optimize X by metric Y", "improve autonomously", "reduce loss", "lower latency", "shrink bundle size", "raise pass rate", "improve a prompt", "make it faster", or run an agent-driven search over edits to any target file. Works for ML training (val_loss, val_bpb), API performance (p50_ms, p99_ms), bundle size, prompt evaluation (pass_rate), LLM-judged design quality, or any measurable metric with a direction (minimize or maximize). The evaluation can be a single command or a multi-step pipeline (write code, build Docker, take a screenshot, LLM-judge, extract score) — either way it collapses to one shell command producing one parseable number. The skill runs three phases: setup (analyze repo → propose target/metric/eval → scaffold → baseline, collaborative, once), develop (edit, run, measure, keep-or-discard, commit or revert), and reflect (periodic log analysis to refresh the idea backlog). Use when the user says "run the experiment loop", "start autoresearch", "start the optimization loop", or points at a target file plus a metric and wants the agent to iterate until stopped.
---

# experiment-loop

Turn an agent into a keep/discard optimizer over one target and one scalar
metric. Three phases: **setup** (once), **develop** (per experiment),
**reflect** (periodic).

## Phase selection

Read `./autoresearch/config.md` from the user's project root.

1. File missing OR contains `<FILL IN>` → **setup**
   (`references/01-setup.md`).
2. `state.md` says `baseline not run` → run the baseline via **develop**.
3. `state.md` `next_action` is `reflect` OR `experiments_since_reflection ≥
   config.reflect_every` OR `no_improvement_streak ≥
   config.reflect_on_plateau` → **reflect**
   (`references/03-reflect.md`).
4. Else → **develop** (`references/02-develop.md`).

## DO / DO NOT

**DO**
- Read `./autoresearch/state.md` at the start of every cycle.
- Only edit files listed in `config.target`.
- Append one row to `./autoresearch/results.tsv` per experiment (including
  crashes and scope violations).
- Write `./autoresearch/experiments/NNN-<slug>.md` per experiment.
- Commit kept experiments; `git reset --hard HEAD~1` discarded ones.

**DO NOT**
- Edit `./autoresearch/config.md` mid-run. It is frozen after setup.
- Edit the eval script (`eval.sh`, `eval.py`, or whatever the eval command
  invokes) mid-run. It is part of the frozen contract.
- Rewrite or delete rows in `./autoresearch/results.tsv`.
- Skip the log or experiment note, even on crash or scope violation.
- Ask "should I continue?" — the develop phase is autonomous until a
  termination condition fires.
- Touch sections of `state.md` below the `<!-- outer-loop-only -->`
  marker while in the develop phase.

## Termination

Stop when EITHER:
- `experiment_count ≥ config.max_experiments`, or
- `no_improvement_streak ≥ config.stop_after_plateau`.

Both default to `unlimited` / `never`. On stop, print final best metric,
best commit SHA, and path to the winning experiment note.

## Links

- `./autoresearch/config.md` — frozen fix + mutable changeable sections.
- `./autoresearch/context.md` — project overview and hard constraints.
- `./autoresearch/auxiliary.md` — side integrations (W&B, Slack, …).
- `references/01-setup.md` · `references/02-develop.md` ·
  `references/03-reflect.md`
- `examples/README.md` — four fully-worked configs.
