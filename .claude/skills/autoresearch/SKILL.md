---
name: autoresearch
description: Autonomous optimization loop for any repo with one scalar metric. Use when the user says "run autoresearch", "start the experiment loop", "optimize X by metric Y", "reduce loss", "lower latency", "make it faster", "shrink bundle size", "raise pass rate", "improve a prompt", or points at a target file + metric and wants the agent to iterate until stopped. After a one-time setup, a main thread runs an event-driven coordinator that spawns two sub-agents in background — `experimenter` (edits target, runs eval, records) and `researcher` (digests sources, proposes hypotheses, reflects). Returns are integrated as they arrive; the next task dispatches immediately. Works for ML training (val_loss, val_bpb), API performance (p50_ms, p99_ms), bundle size, prompt pass_rate, LLM-judge scores, or any measurable metric with a direction. The eval may be a single command or a multi-step pipeline (write code, build Docker, take a screenshot, LLM-judge, parse score) — it collapses to one shell command producing one number.
---

# autoresearch

Turns a repo + one scalar metric into an autonomous optimization loop. After setup, the main thread is an event-driven coordinator; `experimenter` and `researcher` are background sub-agents. Each return is integrated immediately and the next task dispatches — no fixed cycle, no pairing.

**Invariant:** a `keep` row in `experiments/experiments.tsv` is the only way a claim reaches `LORE.md ## Established`. Research is advisory.

## Principles

1. **Binary keep/discard on one scalar.** Each experiment → one number. Keep if it beats `best` in the configured direction; else revert.
2. **Frozen contract.** `CONFIG.md`, the eval command, everything it transitively invokes, and bootstrap artifacts are immutable after setup.
3. **Experiments are truth, research is advisory.** Only `keep` rows promote claims.
4. **Knowledge bar is high.** `knowledge/<topic>.md` holds only verified facts, precise data, and load-bearing heuristics. Tentative claims live in `LORE.md ## Emerging`.
5. **Strict write ownership.** Each agent writes one directory (plus target files for experimenter). Read is universal.
6. **Async pipeline.** Sub-agents run in background; main integrates returns as they arrive. No cycle pairing; researcher returns may interleave with experimenter returns.
7. **Surgical edits.** Every changed line traces to the hypothesis. No drive-by cleanup.
8. **Autonomous until stopped.** After setup, main never asks "continue?".
9. **Workflow decided at setup.** Cadence, reflect triggers, integrations, and scope are locked during setup.
10. **Sub-agents are isolated.** They don't navigate `autoresearch/`. Main composes a self-contained task brief. Agent READMEs contain no cross-references.

## Phase map

```
  setup → prepare → baseline ──► loop (endless, async)
   │        │         │            │
   │        │         │            ├─ experimenter ─┐
   │        │         │            │                ├─► main integrates each
   │        │         │            └─ researcher ───┘   return independently
   │        │         │
   │        │         └─ gate: exp/000 row has a valid scalar; CONFIG freezes
   │        └─ gate: bootstrap exit 0; every integration health-check green
   └─ gate: CONFIG valid; agents copied into user project; tree scaffolded
```

A gate failure blocks the next phase. `references/setup.md` covers phases 1–3. `references/loop.md` covers phase 4. `references/protocol.md` holds data shapes.

## Per-project layout

Setup scaffolds this tree. See `references/protocol.md ## Files` for the full file-by-file reference (purposes, schemas, frontmatter, size rule).

```
autoresearch/
├── CONFIG.md                       # frozen contract: goal · metric · eval · scope · integrations
├── bootstrap.sh OR bootstrap.md    # frozen: idempotent one-time init (.md for multi-step / computer-use)
│
├── ATLAS.md                        # live dashboard (decays)
├── LORE.md                         # durable memory (accretes)
├── backlog.tsv                     # queue: hypotheses · questions · deferred · tooling
├── knowledge/<topic>.md            # high-bar narrative deep-dives
│
├── experiments/                    # experimenter-owned
│   ├── experiments.tsv             # ship's log
│   └── NNN-<slug>.md               # per-experiment note (keep or invalid only)
│
├── research/                       # researcher-owned
│   ├── research.tsv                # session log
│   └── NNN-<slug>.md               # per-session digest
│
└── workbench/                      # main-owned scratchpad
```

### Write-ownership matrix

| Path | main | experimenter | researcher |
|---|---|---|---|
| `CONFIG.md`, `bootstrap.{sh,md}` | — (frozen) | — | — |
| `ATLAS.md`, `LORE.md` | rewrite / append-sections | — | — |
| `backlog.tsv` | append + in-place status | — | — |
| `knowledge/*`, `workbench/*` | create / edit | — | — |
| `experiments/*` | read | append / write-once | — |
| `research/*` | read | — | append / write-once |
| `CONFIG.scope` target files | — | edit in worktree | — |

## Routing

- **One-time setup, prepare, baseline** → `references/setup.md`.
- **Main-thread loop (dispatch, handle returns, ATLAS rewrite, error asides)** → `references/loop.md`.
- **File reference (per-file purpose, TSV columns, frontmatter, hypothesis flow, task brief, compact report, verification)** → `references/protocol.md`.
- **Sub-agent behavior** → `agents/experimenter.md`, `agents/researcher.md` (these are templates; setup copies them into the user's `.claude/agents/`).

## Stopping

Loop exits only on user interrupt. On interrupt, main writes a `paused` marker in `ATLAS.md ## Now` and stops dispatch. Running sub-agents finish; their returns are integrated before exit.
