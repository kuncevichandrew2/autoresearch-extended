# File structures

Reference: directory tree, per-file purpose, field definitions, and filled examples. Addressed by path.

## Tree

```
autoresearch/
├── CONFIG.md                    frozen contract
├── bootstrap.sh | bootstrap.md  frozen setup
│
├── current/                     main's zone
│   ├── MEMORY.md                cold-startable main memory
│   ├── log.tsv                  main activity log
│   └── workbench/               scratch space
│
├── knowledge/                   shared knowledge base (written by main)
│   ├── KNOWLEDGE.md             index / aggregator, not a journal
│   └── <topic>.md               propositions + evidence
│
└── sub-agents/
    ├── experiments/             experimenter's zone
    │   ├── MEMORY.md            experimenter memory
    │   ├── log.tsv              experimenter log
    │   └── NNN-<slug>.md        experiment record (on keep / invalid)
    └── research/                researcher's zone
        ├── MEMORY.md            researcher memory
        ├── log.tsv              researcher log
        └── NNN-<slug>.md        session report
```

## CONFIG.md

Frozen contract. Fields:

```
Goal              one line: what we are optimizing and why
Metric.name              metric name (e.g. val_loss)
Metric.direction         min or max
Metric.eval_command      shell command printing one number
Metric.parse_method      regex:… | json_path:… | exit_code
Metric.timeout_sec       per-run timeout
Metric.seed_policy       fixed:N | sampled:K-runs | none
Scope                    globs experimenter may edit
Custom TSV columns       columns appended after the 8 fixed ones
                         in sub-agents/experiments/log.tsv
Concurrency              max_parallel_experimenters,
                         max_parallel_researchers
Scheduler                exploration_every, analysis_every,
                         consolidation_every, coldstart_check_every
Brief budgets (tokens)   experimenter, deep_research, analysis,
                         exploration
Return budgets (tokens)  experimenter_body, researcher_body
Constraints              held-out, licenses, determinism, wall-clock
Integrations             per integration: name, env, health command
```

## current/MEMORY.md

Cold-startable main memory. Section descriptions — in the template itself (templates/autoresearch/current/MEMORY.md). Universal skeleton (Status, Queue, Recent, Patterns, Avoid + optional) — SKILL.md.

Filled example:

```
## Status
- Best metric: val_bpb 3.041 from experiments/042-warmup-cosine (a1b2c3d)
- Active sub-agents: experimenter on 079, researcher on 015
- Flags: none
- Scheduler: exploration in 4 · analysis in 4 · consolidation in 19 · coldstart-check in 23
- Phase: loop

## Queue
- Apply Muon to 2D parameters, source research/008-muon-digest.
- Try grad-clip 0.5 in low-LR regime — knowledge/gradient-clipping.md (contested).
- Check val for data leakage — deferred until cycle 50.

## Recent
- experiments/078 keep -0.008 — replicated cosine warmup at batch=64
- experiments/077 discard +0.003 — warmup_ratio=15% null
- research/014 analysis — formalised P2 in warmup-schedules

## Patterns
- LR-schedule ideas consistently produce keep (3 keep in the last 10).
- Eval is noisy below |Δ|=0.004 — falsifiers tighter than this come back invalid.

## Avoid
- LR > 1e-3 — always diverges (031, 044, 061).
- LayerNorm → RMSNorm — do not propose — research/009.
```

## current/log.tsv

Full action log maintained by main after each integration. Columns:

```
timestamp    UTC ISO time of the record
action       experiment | research | consolidate | compress | integrity
target       path of the object (experiments/NNN-<slug>, research/NNN-<slug>, knowledge/<topic>.md, ...)
outcome      experiment: keep | discard | crash | timeout | invalid
             research:   done
             other:      updated | recorded
delta        for experiment — signed metric change; otherwise "-"
notes        short remark
```

Example:

```
2026-04-22T12:30Z	experiment	experiments/042-warmup-cosine	keep	-0.012	new best
2026-04-22T13:05Z	experiment	experiments/043	discard	+0.048	-
2026-04-22T14:00Z	research	research/008-muon-digest	done	-	queued 2 ideas
2026-04-25T10:15Z	consolidate	knowledge/warmup-schedules.md	updated	-	exp/058 added; P2 confirmed
2026-04-22T13:55Z	integrity	experiments/044	recorded	-	report/tsv mismatch; trusted TSV
```

Empty values — `-`, not an empty cell.

## knowledge/KNOWLEDGE.md

Index. Written by main. Sections described in the template. Filled example:

```
## Current best
val_bpb 3.041 from experiments/042-warmup-cosine.

## Confirmed topics
- warmup-schedules — cosine 10% beats linear 2% at LR ∈ [1e-4, 5e-4]; gain front-loaded. → warmup-schedules.md
- data-integrity — held-out eval confirmed leak-free on data/v3. → data-integrity.md

## Watch list
- batch-size scaling (experiments/067) — batch=128 better than 64 at LR=3e-4.

## Contested
- gradient-clipping — clip=1.0 wins at LR ∈ [1e-4, 5e-4] (experiments/063); loses at LR=8e-5 (experiments/079). → gradient-clipping.md

## Integrity events
- 2026-04-15 — integrations verified: wandb, docker
- 2026-04-22 — experiments/044 report/tsv mismatch, trusted TSV
```

## knowledge/<topic>.md

Created when a topic has accumulated ≥ 2 keep results. Stable propositions at the top; evidence appendix append-only at the bottom. Written by main.

Frontmatter:

```
topic              topic name (slug)
created            date of first confirmation
last_evidence      date + reference to the latest evidence
related_topics     list of related topics
```

Body:

```
## Propositions (stable)
   ### Pn. <claim>
   - Scope:           conditions under which the claim applies
   - Falsifier:       numeric rule that refutes the claim
   - Established by:  list of experiments/NNN that confirmed it
   - Status:          confirmed | contested

## Evidence appendix (append-only)
   - experiments/NNN keep|discard ±delta — comment
   - research/NNN — comment
```

Contradiction: new evidence in an overlapping scope flips Status to contested; source data is never deleted.

Example:

```
---
topic: warmup-schedules
created: 2026-04-22
last_evidence: 2026-04-30 (experiments/078)
related_topics: [optimizers, lr-schedules]
---

# Warmup schedules

## Propositions (stable)

### P1. Cosine warmup at 10% beats linear warmup at 2% on val_bpb
- Scope: lr ∈ [1e-4, 5e-4], batch ≤ 64
- Falsifier: any in-scope experiment where linear ≤ cosine by ≥ 0.005
- Established by: experiments/042, experiments/058
- Status: confirmed

### P2. The gain concentrates in steps 0–3k; curves converge by 5k
- Scope: same as P1
- Falsifier: gap widens after step 5k
- Established by: experiments/042 (curve analysis), experiments/058
- Status: confirmed

## Evidence appendix
- experiments/042 keep -0.012 — first confirmation of P1, P2
- experiments/058 keep -0.008 — replicated at batch=64
- experiments/077 discard +0.003 — warmup_ratio=15% null
- research/007 — literature survey on warmup
- research/014 — analysis after experiments/058, formalised P2
```

## sub-agents/experiments/MEMORY.md

Experimenter memory. Section descriptions — in the template.

## sub-agents/experiments/log.tsv

Experimenter log. Appended by experimenter after each run. 8 fixed columns plus custom_tsv_columns from CONFIG in order.

```
id           NNN, monotonically increasing
status       keep | discard | crash | timeout | invalid
metric       metric value; NaN on crash, timeout, parse-fail
delta        signed change from current_best; NaN on crash/timeout/parse-fail
description  one line describing the change
commit       7-char SHA of commit B (record)
timestamp    UTC ISO time of the record
note         path NNN-<slug>.md if present, otherwise "-"
... custom   values of custom_tsv_columns in CONFIG order
```

Example:

```
000	keep	3.074	0	baseline	a0b1c2d	2026-04-10T08:00Z	000-baseline.md
042	keep	3.041	-0.012	cosine warmup 10% vs linear 2%	a1b2c3d	2026-04-22T12:30Z	042-warmup-cosine.md
043	discard	3.089	+0.048	cosine warmup 25%	e4f5g6h	2026-04-22T13:05Z	-
044	crash	NaN	NaN	swap tokenizer to BPE	b7c8d9e	2026-04-22T13:40Z	-
```

## sub-agents/experiments/NNN-<slug>.md

Write-once. Created on keep or invalid only. Written by experimenter. Frontmatter:

```
id, slug, kind                    identification
date                              UTC ISO time
status                            keep | invalid
parent                            NNN of the current_best at time of run
source                            research/NNN-<slug> or "-"
commit                            SHA of commit B
metric, delta                     values
```

Body: Hypothesis, Changes (file:line — why), Result (metric, delta, falsifier check, wall time, surprises), Log excerpt (~20 meaningful lines), Notes (caveats, references to affected knowledge/<topic>.md).

## sub-agents/research/MEMORY.md

Researcher memory. Section descriptions — in the template.

## sub-agents/research/log.tsv

Researcher log. Appended by researcher after each session. Columns:

```
id          NNN, monotonically increasing
type        deep-research | analysis | broader-tooling | exploration
date        YYYY-MM-DD
report      path NNN-<slug>.md
outcome     queued:N (how many ideas went to main's Queue)
            informational (useful context, no new hypotheses)
            null (nothing actionable)
one_line    one-line summary (≤ 80 chars)
```

Example:

```
007	deep-research	2026-04-15	007-warmup-sweep.md	queued:2	cosine warmup grounded
008	deep-research	2026-04-20	008-muon-digest.md	queued:2	Muon optimizer
009	exploration	2026-04-21	009-norm-survey.md	null	RMSNorm not justified
014	analysis	2026-04-26	014-cycle-50-review.md	queued:1	formalised warmup P2
```

## sub-agents/research/NNN-<slug>.md

Write-once. Written by researcher. Free prose, light scaffold. Frontmatter: id, slug, type, date, trigger.

Body: Topic (one sentence — what and why), Findings (free — what was found), Hypotheses produced (1–3 — with target files and numeric falsifiers), Sources (URL / arxiv id / file path — one line on significance), Recommendations (analysis only), Notes (caveats, dead ends).
