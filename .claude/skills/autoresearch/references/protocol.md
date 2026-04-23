# Protocol — data shapes

Reference. Read in parallel with `loop.md`.

## Directory tree

```
autoresearch/
├── CONFIG.md                       # frozen
├── bootstrap.sh OR bootstrap.md    # frozen (one of the two)
│
├── ATLAS.md                        # main-owned live dashboard
├── LORE.md                         # main-owned durable memory
├── backlog.tsv                     # main-owned queue
├── knowledge/
│   ├── README.md
│   └── <topic>.md                  # emergent; only when a topic earns it
│
├── experiments/
│   ├── README.md
│   ├── experiments.tsv
│   └── NNN-<slug>.md               # only for status ∈ {keep, invalid}
│
├── research/
│   ├── README.md
│   ├── research.tsv
│   └── NNN-<slug>.md               # one per session
│
└── workbench/
    ├── README.md
    └── *
```

## Files

**Size rule.** Every mutable `.md` file under `autoresearch/` stays **under ~400 lines**. When a file approaches the cap, main compresses — trim oldest bullets in ATLAS, summarise stale Decisions / Dead-end entries in LORE into one-liners, or promote a recurring topic into `knowledge/<topic>.md`. Write-once notes (`experiments/NNN-*.md`, `research/NNN-*.md`) are exempt.

### `CONFIG.md` — the frozen contract for what's being optimized and how.
Goal · metric · direction · eval command · parse method · scope globs · timeout · reflect cadence, plus `## Context`, `## Constraints`, `## Integrations` sections. Written at setup, frozen after baseline; changes require a re-setup.

### `bootstrap.sh` or `bootstrap.md` — one-time, idempotent environment init.
Use `.sh` for a single script. Use `.md` when setup is multi-step or mixes scripts with prose instructions (several sub-scripts, computer-use steps, manual auth). Frozen alongside `CONFIG.md`.

### `ATLAS.md` — live dashboard of the current state of the loop.
Rewritten on every integration; nothing here is load-bearing history. Plain markdown sections:
- `## Now` — current best (metric, exp id, commit), running experiments/research, `recommend_resetup` flag if set.
- `## Recent signal` — ring buffer of the 5 newest integration events.
- `## Hot topics` — 2–4 top tags by activity, recomputed from backlog + last 10 experiments.

### `LORE.md` — aggregation of *everything* the agent has learned.
The total knowledge store. Anything worth remembering beyond the current tick lands here — confirmed claims, tentative patterns, decisions, failure modes, domain context, heuristics, surprising observations, rules of thumb, mental models. Sections emerge as the body of knowledge grows; typical ones include:
- `## Established` — claims promoted by a `keep` experiment, each citing `exp/NNN`.
- `## Emerging` — tentative claims from research, awaiting confirmation.
- `## Decisions` — one-liner changelog (integrations verified, pauses, policy choices).
- `## Dead ends` — approaches that repeatedly fail; append-only, dedup by substring.
- `## Anti-cheat log` — TSV/report mismatches, foreign writes, integrity events.

Add new sections freely when the material wants them (e.g. `## Domain context`, `## Heuristics`, `## Open questions`). The list above is a starting skeleton, not a closed schema.

> **ATLAS vs LORE.** ATLAS = latest state, decays. LORE = *everything* the agent knows, accretes. If you'd erase it on the next tick, it's ATLAS; if you'd want it next week, it's LORE.

### `backlog.tsv` — queue of work waiting to be picked up.
Append-only, 9 columns; main mutates rows in place by id-key via atomic rewrite (read → edit → temp file → rename).
```
id	kind	status	claim	source	created	consumed_by	outcome	notes
H-019	hypothesis	pending	apply Muon to 2D params	research/008-muon-digest.md#H-019	2026-04-20	-	-	top of queue
H-020	hypothesis	blocked	layer-gated Muon	research/008-muon-digest.md#H-020	2026-04-20	-	-	blocked on H-019
H-017	hypothesis	consumed	cosine warmup 10% beats linear	research/007-warmup-sweep.md#H-017	2026-04-15	exp/042	keep	-0.012 val_bpb
Q-003	question	open	why does depth scaling break at d=24	-	2026-04-18	-	-	observed exp/039
D-002	deferred	pending	digest arxiv:2501.15105	-	2026-04-17	-	-	-
T-002	tooling	pending	ATLAS recent-signal regen script	-	2026-04-19	-	-	-
```
- `kind ∈ {hypothesis, question, deferred, tooling}` · `status ∈ {pending, blocked, running, consumed, done, dropped}`.
- Pre-registration prose lives in the `source` report, not the TSV.
- Columns 1, 2, 4, 5, 6 immutable after append; columns 3, 7, 8, 9 mutable in place.

### `experiments/experiments.tsv` — ship's log, one row per experiment.
8 fixed columns; custom columns declared in `CONFIG` append after column 8 in `CONFIG` order.
```
id	status	metric	delta	hypothesis	commit	timestamp	note
000	keep	3.074	0	-	0000000	2026-04-10T08:00Z	experiments/000-baseline.md
042	keep	3.041	-0.012	H-017	a1b2c3d	2026-04-22T12:30Z	experiments/042-warmup-cosine.md
043	discard	3.089	+0.048	-	e4f5g6h	2026-04-22T13:05Z	-
```
- `status ∈ {keep, discard, crash, timeout, invalid}` · `metric = NaN` if unparseable/crashed/timed out · `hypothesis = H-NNN | -` · `commit` is the 7-char SHA of the record commit.

### `experiments/NNN-<slug>.md` — per-experiment record for a `keep` or `invalid` run.
Write-once. Frontmatter below + short body (`## Hypothesis` · `## Changes` · `## Result` · `## Log excerpt` · `## Notes`).
```yaml
---
id: 042
slug: warmup-cosine
kind: experiment
date: 2026-04-22T12:30:00Z
status: keep
parent: 014
source_hypothesis: H-017
commit: a1b2c3d
metric: 3.041
delta: -0.012
---
```

### `research/research.tsv` — researcher session log, one row per session.
```
id	type	date	report	one_line
R-008	digest	2026-04-20	research/008-muon-digest.md	Muon optimizer; H-019, H-020
R-009	reflect	2026-04-22	research/009-reflect-cycle-42.md	reflect after 10 exps; H-021 added
```
`type ∈ {digest, sweep, eda, broader-tooling, reflect}`.

### `research/NNN-<slug>.md` — per-session digest from the researcher.
Write-once. Loose frontmatter — the usual identifiers (`id`, `slug`, `date`, `trigger`, hypotheses produced) plus whatever else is worth pinning for this digest. Body flows naturally: context → findings (URLs inline) → hypotheses produced → recommendations (for `reflect`). Each proposed hypothesis appears as an `### H-NNN: <one-liner>` block covering claim, rationale (citing sources), method, predicted metric movement, risks, and a concrete numeric falsifier — readable prose/bullets, not a rigid template.

### `knowledge/<topic>.md` — high-bar narrative deep-dive on a topic that has earned one.
Emergent — created only when a topic accumulates multiple `keep` experiments or a `reflect` recommendation promotes it. Holds verified facts, precise data tables, and load-bearing heuristics. Not churned.

### `README.md` (per folder) — orientation for a human (or agent) opening the folder first.
Each subdirectory's `README.md` explains what lives there and how to read it: what the records mean, where the ground truth lives, conventions worth knowing, and any pointers to other files. It can grow as conventions settle (usage examples, edge cases, gotchas) — but it is still bounded by the size rule; when it outgrows that, split the stable bits into a dedicated note or promote a topic into `knowledge/`.

## ID alphabet

`NNN` (experiment) · `R-NNN` (research) · `H-NNN | Q-NNN | D-NNN | T-NNN` (backlog). Zero-padded three digits. Monotonic. Never reused.

## Hypothesis flow

Most hypotheses travel: **backlog (`kind=hypothesis`) → researcher (digest/pre-registration) → experimenter (runs it)**. Rarer paths exist and are fine: a sharp, grounded idea can skip the researcher and go straight to the experimenter; a vague one can loop back into the researcher again before it ever reaches an experiment. The three-stop path is the default — treat deviations as judgement calls, not violations.

## Task brief (main → sub-agent)

Self-contained: sub-agents never fetch extra context. The brief is prose/YAML, not a fixed schema — pass what the sub-agent actually needs for this task, drop what doesn't apply.

- **Experimenter brief** should make it clear *what* to try (id + slug, the hypothesis short line + pre-registration), *where* and *how* to change things (target files + edit intent), which commit it branches from, how to evaluate (command, parse method, timeout), what "good" looks like (metric direction, current best), and where to record the result (tsv + note path).
- **Researcher brief** should make it clear *what question* to answer (id + slug + type, the trigger, a one-sentence task), inline any context that saves a re-read (recent experiments, relevant LORE slices), and say where to record (tsv + report path).

Example shapes live in `loop.md`; reuse them, but edit freely per task.

## Compact report (sub-agent → main)

A short text reply main reads as text, not a parsed schema. First line is a sentinel so main knows the kind of return: `EXPERIMENT_DONE` or `RESEARCH_DONE`. After that, hand back whatever main needs to integrate the result — typically the id, the status, the metric and delta (for experiments), the record commit hash, the path to the note/report, and a one-line headline. If something noteworthy happened (OOM, retry, surprise), add free-form comments. Pass extra fields when they help; omit fields that don't apply. Unknown lines are ignored.

## Verification

After reading a return:

1. `tail -1 <referenced_tsv>` begins with the reported `id`.
2. If `status` implies a note must exist (`keep` / `invalid` for experimenter; any `status=done` research) → `note_path` / `report` exists on disk.
3. On mismatch: trust the TSV, append to `LORE.md ## Anti-cheat log`:
   ```
   YYYY-MM-DD — <id> report/tsv mismatch, trusting TSV
   ```
   Skip the rest of integration for this return.

Cheap disk check. Not a protocol-conformance gate.
