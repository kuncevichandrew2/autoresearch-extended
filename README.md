# autoresearch

**An autonomous optimization loop for any repository with one scalar metric.**

A Claude Code skill that turns the main thread into an event-driven research
coordinator. Point it at a target file (or small scope) and one measurable
scalar — any metric with a direction (min/max) — and it iterates:
hypothesize → edit → run eval → keep or discard → learn → repeat, until you
stop it.

Works for ML training (`val_loss`, `val_bpb`), API performance (`p50_ms`,
`p99_ms`), bundle size, prompt pass-rate, LLM-judged quality, or anything
else you can reduce to one shell command that prints one parseable number.
The eval may be a single command or a multi-step pipeline (write code →
build Docker → screenshot → LLM-judge → extract) — either way it collapses
to **one shell command producing one scalar**.

## Architecture

After a one-time setup, the main Claude Code thread becomes an event-driven
coordinator. It dispatches two sub-agents in the background and integrates
their returns as they arrive:

- **`experimenter`** — runs one experiment end-to-end in an isolated git
  worktree. Applies a minimal hypothesis-bearing change, runs the eval,
  parses a scalar, records to `sub-agents/experiments/log.tsv`, commits
  twice, returns.
- **`researcher`** — runs one research task (digest a source, run a
  literature sweep, do light EDA, evaluate tooling, or reflect on recent
  experiments). Proposes numerically falsifiable hypotheses for the
  experimenter to pick up.

Returns arrive asynchronously; main integrates each one, keeps the backlog
full, and stays busy between dispatches — there is no cycle pairing and no
fixed cadence.

```
           ┌──────────┐
           │  setup   │  (once, collaborative)
           └────┬─────┘
                │
                ▼
           ┌──────────┐
           │ baseline │  (exp/000)
           └────┬─────┘
                │
    ┌───────────▼────────────┐
    │   main coordinator     │◄──── async returns
    │  think → dispatch →    │
    │  integrate → think     │
    └──┬──────────────────┬──┘
       │                  │
       ▼                  ▼
  experimenter        researcher
  (edits, evals,      (digest · sweep ·
   records)            eda · reflect)
```

## Install

```sh
git clone https://github.com/kuncevichandrew2/autoresearch-extended.git
cp -r autoresearch-extended/.claude/skills/autoresearch ~/.claude/skills/
```

Or symlink `.claude/skills/autoresearch/` from this repo into any
Claude Code skills path.

## Run

Open Claude Code in the project you want to optimize, then say:

> run autoresearch

or

> start the experiment loop — optimize `<file>` by `<metric>`

On the first run the agent enters **setup** — a collaborative phase where
you agree on the target file(s), the eval command, the metric + direction,
integrations, and hard constraints. Setup produces a short `CLAUDE.md` at
the repo root and scaffolds `./autoresearch/` inside the project. After
`bootstrap` and a `baseline` run, the loop becomes autonomous and keeps
running until you interrupt it.

## Per-project layout created by setup

```
autoresearch/
├── CONFIG.md                       # frozen: goal · metric · eval · scope · integrations
├── bootstrap.sh OR bootstrap.md    # frozen: idempotent one-time init
│
├── current/                        # main-owned: live state
│   ├── MEMORY.md                   # cold-startable dashboard (Queue, Status, Recent, …)
│   ├── log.tsv                     # activity log
│   └── workbench/                  # scratch space
│
├── knowledge/                      # main-owned: accreted learning
│   ├── KNOWLEDGE.md                # index of confirmed topics
│   └── <topic>.md                  # propositions + evidence (created at ≥ 2 keep)
│
└── sub-agents/
    ├── experiments/                # experimenter-owned
    │   ├── MEMORY.md               # experimenter memory
    │   ├── log.tsv                 # experiment ship's log
    │   └── NNN-<slug>.md           # per-experiment note (keep or invalid)
    └── research/                   # researcher-owned
        ├── MEMORY.md               # researcher memory
        ├── log.tsv                 # research session log
        └── NNN-<slug>.md           # per-session digest
```

## Why it works

1. **Single target, single scalar.** The agent can't drift; keep/discard
   is `<` or `>`.
2. **Frozen contract.** `CONFIG.md`, the eval, and `bootstrap` are
   immutable after baseline — changes require re-setup.
3. **Experiments are ground truth, research is advisory.** Only a `keep`
   experiment promotes a claim into `knowledge/<topic>.md ## Propositions`.
4. **Strict write ownership.** Each sub-agent owns exactly one directory
   (plus target files for the experimenter). All integration of returns
   happens in the main coordinator.
5. **Async, event-driven.** Main stays busy — thinking, pruning the
   backlog, sharpening the next brief, dispatching more work — while
   sub-agents run in parallel.
6. **Falsification over confirmation.** Every researcher-proposed
   hypothesis ships with a numeric falsifier. Experiments are designed to
   risk being wrong.

## Limitations

- Single-node by default; no remote compute unless your eval arranges it.
- Linear keep/discard against the current best — no branching or
  tournament search.
- LLM-judged metrics are noisy; trust aggregate trends, not individual
  comparisons.
- Complex multi-step evals require a user-written `eval.sh` (or equivalent)
  that collapses the pipeline into a single scalar.
- Metric gaming is possible — encode hard rules in `CONFIG.md ## Constraints`.

## Inspiration

- Andrej Karpathy's [autoresearch](https://github.com/karpathy/autoresearch)
  — original minimal single-file, single-metric autonomous loop.
- Anthropic's
  [multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)
  — sub-agent architecture, task-briefing, and prompting principles.
- [Popper](https://arxiv.org/abs/2502.09858) and
  [AIGS](https://agent-force.github.io/AIGS/) — falsification-first
  hypothesis validation.
- Sakana's [AI Scientist-v2](https://github.com/SakanaAI/AI-Scientist-v2)
  — progressive, tree-search-style experimentation.
- MemGPT / [Letta](https://www.letta.com/blog/agent-memory) and
  [Generative Agents](https://arxiv.org/abs/2304.03442) — long-term memory
  patterns (tiered memory, chronological log + reflection) behind
  the `current/` + `knowledge/` split.
