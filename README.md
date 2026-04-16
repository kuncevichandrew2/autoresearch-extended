# experiment-loop

**AI agents running autonomous optimization on any file with any metric.**

A portable Claude Code skill that turns a coding agent into an autonomous
optimization loop. Point it at a target file and a measurable scalar metric;
it edits → runs → measures → keeps or discards → repeats until stopped.
Works for any metric with a direction (min/max): `val_loss`, `p50_ms`,
`bundle_size`, `pass_rate`, LLM-judged quality. The eval can be one command
or a multi-step pipeline (write code → build Docker → screenshot →
LLM-judge → extract); either way it collapses to ONE shell command
producing one parseable number.

## Install

```sh
git clone https://github.com/<you>/experiment-loop ~/.claude/skills/experiment-loop
# or symlink the experiment-loop/ folder into any Claude Code skills path
```

## Run

Open Claude Code in your project root and say:

> run the experiment loop

On first run the agent enters **setup** — a collaborative phase that agrees
on target files, the evaluation pipeline, the scalar metric, and writes
`./autoresearch/` into your project. After setup the agent loops
autonomously and reflects on the trajectory every few experiments.

## Layout created in your project by setup

```
./autoresearch/
├── config.md       frozen after setup (metric, eval, targets)
├── context.md      overview + hard constraints
├── auxiliary.md    side integrations (W&B, Slack, …)
├── state.md        agent working memory
├── results.tsv     append-only log
└── experiments/NNN-<slug>.md
```

## Why it works

1. Single target file (or small set) — the agent cannot drift.
2. Single scalar metric with a direction — keep/discard is `<` or `>`.
3. Fixed eval budget — every run takes the same wall-clock time.
4. Immutable context and config — setup locks the eval.
5. Binary keep/discard — no partial credit; reverted commits disappear.

## Limitations

- No remote compute, no parallel experiments.
- Linear keep/discard only — no branching or tournament search.
- LLM-judged metrics are noisy; trust aggregate trends.
- Complex pipelines require a user-written `eval.sh`.
- Metric gaming is possible; encode hard rules in `context.md`.

## Diagram

```
           ┌──────────┐
           │  setup   │  (once, collaborative)
           └────┬─────┘
                │
        ┌───────▼────────┐      every N experiments
        │     develop    ├──────────────────────────┐
        │ edit → run →   │                          │
        │ measure → keep │                          ▼
        │ or discard     │◄──────────────────┐ ┌─────────┐
        └───────┬────────┘                   │ │ reflect │
                │ writes                     │ └────┬────┘
                ▼                            │      │
   results.tsv · experiments/NNN · state.md ─┘ ─────┘
```

## Acknowledgments

- Andrej Karpathy's [autoresearch](https://github.com/karpathy/autoresearch)
  for the original single-file, single-metric autonomous loop.
- Anthropic's [SKILL.md](https://www.anthropic.com/) format for portable
  skills.
- Langfuse's metric-gaming writeup for the reflection-phase guardrails.

MIT.
