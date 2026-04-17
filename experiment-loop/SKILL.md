---
name: experiment-loop
description: Autonomous optimization loop for any file with any measurable scalar metric. Use this when the user wants to "optimize X by metric Y", "improve autonomously", "reduce loss", "lower latency", "shrink bundle size", "raise pass rate", "improve a prompt", "make it faster", or run an agent-driven search over edits to any target file. Works for ML training (val_loss, val_bpb), API performance (p50_ms, p99_ms), bundle size, prompt evaluation (pass_rate), LLM-judged design quality, or any measurable metric with a direction (minimize or maximize). The evaluation can be a single command or a multi-step pipeline (write code, build Docker, take a screenshot, LLM-judge, extract score) — either way it collapses to one shell command producing one parseable number. Three phases: setup (analyze repo → propose → scaffold → one-time bootstrap → baseline, collaborative, once), develop (edit → run → measure → keep-or-discard → commit or revert), reflect (periodic log analysis + notebook → refresh idea backlog). Use when the user says "run the experiment loop", "start autoresearch", "start the optimization loop", or points at a target file plus a metric and wants the agent to iterate until stopped.
---

# experiment-loop

Three phases: **setup** (once) → **develop** (per experiment) → **reflect**
(periodic).

## Principles

1. **Binary keep/discard on one scalar metric.** Every experiment produces
   one number `M`. Keep iff `M` beats `best` in `metric_direction`;
   otherwise `git reset --hard HEAD~1`. No multi-objective, no subjective
   calls, no "close enough".
2. **Frozen contract, one mutable surface.** After setup:
   - **Immutable** (editing = scope violation): `config.md ## Fix`, the eval
     script, every one-time bootstrap artifact (dataset caches, fixtures,
     built images), `context.md`, `auxiliary.md`, the mechanical block of
     `state.md`, and every file outside `config.target`.
   - **Mutable**: files listed in `config.target` (develop only);
     `state.md` strategy block below the `<!-- outer-loop-only -->` marker
     and `config.md ## Changeable` (reflect only).
3. **Autonomous until termination.** Develop never asks "continue?". Stop
   only when `experiment_count ≥ max_experiments` or
   `no_improvement_streak ≥ stop_after_plateau`.

## Phase selection

Read `./autoresearch/config.md` from the project root.

1. File missing OR contains `<FILL IN>` → **setup** (`references/01-setup.md`).
2. `state.md` says `baseline not run` → run baseline via **develop**.
3. `state.md` `next_action=reflect` OR `experiments_since_reflection ≥
   config.reflect_every` OR `no_improvement_streak ≥
   config.reflect_on_plateau` → **reflect** (`references/03-reflect.md`).
4. Else → **develop** (`references/02-develop.md`).

## Termination

Stop when EITHER `experiment_count ≥ config.max_experiments` OR
`no_improvement_streak ≥ config.stop_after_plateau`. Both default to
unlimited / never. On stop, print final best metric, best commit SHA, and
path to the winning experiment note.

## Links

- `./autoresearch/config.md` — frozen fix + mutable changeable sections.
- `./autoresearch/context.md` — project overview and hard constraints.
- `./autoresearch/auxiliary.md` — side integrations (W&B, Slack, …).
- `references/01-setup.md` · `references/02-develop.md` · `references/03-reflect.md`
- `examples/README.md` — four fully-worked configs.
