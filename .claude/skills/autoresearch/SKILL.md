---
name: autoresearch
description: Autonomous optimization loop for any repo with one scalar metric. Triggers on "run autoresearch", "start the experiment loop", "optimize X by metric Y", "reduce loss / latency / bundle size", "raise pass rate", or a target file + metric. After a one-time setup, the main thread is an event-driven coordinator that dispatches two background sub-agents — `experimenter` (edits target, runs eval, records) and `researcher` (digests sources, proposes hypotheses). Works for any metric reducible to one shell command that prints one parseable number (val_loss, p99_ms, bundle_kb, pass_at_k, judge_score, …).
---

# autoresearch

Repo + one metric (a number from a shell command) → autonomous loop. Main is an event-driven coordinator; two background sub-agents (experimenter, researcher) execute tasks. Main calls `Agent(subagent_type=..., run_in_background=true, prompt=<brief>)`, waits for Agent-complete notifications, reads the compact report, does a disk-check, integrates each return as it arrives, and dispatches the next task.

## Invariant

Only `status=keep` on an experiment promotes a claim from LEADS.md (leads from research) to FACTS.md (confirmed). Research is advisory; the experiment decides. Knowledge flow: main frames a hypothesis → researcher grounds it and sharpens the falsifier → experimenter measures → FACTS.md (+ optionally `knowledge/<topic>.md`).

## Principles

1. **Binary keep/discard on one scalar.** Keep if it beats the current best in the configured direction (min or max). Otherwise revert.
2. **Two layers: target vs. contract.** The only thing that changes each iteration is the **target** (files listed in `CONFIG.scope`) — that's the whole point of the loop. Everything else — the metric, the eval command, bootstrap, scope itself — is the **contract**, captured in `CONFIG.md`, and is strictly off-limits after baseline parses. Touching the contract requires re-setup.
3. **Experiments are truth, research is advisory.** Only `keep` promotes a bullet from LEADS to FACTS.
4. **Sub-agents stay in their lane.** Each sub-agent only touches files inside its area: researcher writes to `research/`; experimenter writes to `experiments/` and to target files inside `CONFIG.scope`. Main writes everywhere else. Reads are universal.
5. **Worktree isolation.** Every experiment lives in its own git worktree on branch `exp/NNN-<slug>`. On keep — fast-forward merge. On anything else — cherry-pick only the record commit, no code.
6. **Surgical edits.** Every changed line traces to the hypothesis. No drive-by cleanup.
7. **Autonomous until stopped.** After setup, main never asks "continue?".

---

## File structure

### Tree

```
autoresearch/
├── CONFIG.md                       # frozen after baseline
├── bootstrap.sh | bootstrap.md     # frozen after baseline
│
├── ATLAS.md                        # main — live dashboard (decays)
├── FACTS.md                        # main — confirmed knowledge (accretes)
├── LEADS.md                        # main — leads from research (churns)
├── backlog.tsv                     # main — work queue
├── knowledge/<topic>.md            # emergent; ≥ 2 keeps on the topic or promoted by reflect
│
├── experiments/{experiments.tsv, NNN-<slug>.md}   # experimenter — append / write-once
├── research/{research.tsv, NNN-<slug>.md}         # researcher — append / write-once
└── workbench/                      # main scratchpad
```

**Size rule.** Every mutable `.md` stays under ~400 lines (one Read window). As it approaches the cap, main compresses: trim old ATLAS bullets, collapse stale FACTS/LEADS entries into one-liners, promote a recurring topic into `knowledge/<topic>.md`. Write-once notes (`experiments/NNN-*.md`, `research/NNN-*.md`) are never touched.

### FACTS / LEADS / ATLAS sections

**FACTS.md** (accretes, confirmed by experiment):
- **Established** — claims promoted by a keep-experiment; each cites `exp/NNN`.
- **Dead ends** — recurring failures; append-only, dedup by substring.
- **Decisions** — one-line changelog (integrations, pauses, policy choices).
- **Anti-cheat log** — TSV/report mismatches, foreign writes, integrity events.

**LEADS.md** (churns, reworked as claims are confirmed/refuted; aggregates information from researcher reports):
- **Emerging** — tentative claims from research, waiting on experimental confirmation.
- **Domain context** — aggregated knowledge from researcher.
- **Open questions** — questions that haven't crystallised into a hypothesis yet.
- **Heuristics** — speculative patterns ("looks like X correlates with Y").

**ATLAS.md** (rewrites, snapshot, nothing load-bearing):
- **Now** — current best (metric, exp id, commit), running sub-agents, flags `paused` / `recommend_resetup`.
- **Recent signal** — ring buffer of the 5 latest integration events.
- **Hot topics** — 2–4 top tags by activity across backlog + last 10 experiments.

> **In short.** ATLAS = what is now, decays. FACTS = what is proven, accretes. LEADS = what was read and suspected, reworked. Each has its own aging dynamic. The starter section set is not closed — main freely introduces emergent sections (Invariants, Calibrations, …) when they help.

### CONFIG.md — frozen contract

```
goal              one line: what we're optimising and why
metric            val_loss
direction         min | max
eval_command      bash scripts/eval.sh
parse_method      regex:^val_loss=([0-9.]+)$ | json_path:… | exit_code
timeout_sec       1800
scope             globs the experimenter may edit
seed_policy       fixed:N | sampled:K-runs | none
reflect_every     10
max_parallel_experimenters  1
max_parallel_researchers    2
custom_tsv_columns          list (appended to experiments.tsv in order)

## Context            3–6 bullets: repo shape, target, what a good run looks like
## Constraints        hard rules: held-out data, licences, determinism, wall-clock caps
## Integrations       per integration: name, env vars, health command
```

### backlog.tsv — work queue

9 columns, append-only. In-place mutation by id via atomic `read → edit → temp → rename`.

```
id	kind	status	claim	source	created	consumed_by	outcome	notes
H-019	hypothesis	pending	apply Muon to 2D params	research/008-muon-digest.md#H-019	2026-04-20	-	-	top of queue
H-017	hypothesis	consumed	cosine warmup 10% beats linear	research/007-warmup-sweep.md#H-017	2026-04-15	exp/042	keep	-0.012 val_bpb
```

- `kind` ∈ {hypothesis, question, deferred, tooling}
- `status` ∈ {pending, blocked, running, consumed, done, dropped}
- Columns 1, 2, 4, 5, 6 are immutable after append; 3, 7, 8, 9 are mutable.

### experiments/experiments.tsv — ship's log

8 fixed columns + `custom_tsv_columns` from CONFIG in order.

```
id	status	metric	delta	hypothesis	commit	timestamp	note
000	keep	3.074	0	-	a0b1c2d	2026-04-10T08:00Z	experiments/000-baseline.md
042	keep	3.041	-0.012	H-017	a1b2c3d	2026-04-22T12:30Z	experiments/042-warmup-cosine.md
043	discard	3.089	+0.048	-	e4f5g6h	2026-04-22T13:05Z	-
```

- `status` ∈ {keep, discard, crash, timeout, invalid}
- `metric` = NaN on crash / timeout / parse failure
- `commit` — 7-char SHA of the record commit (commit B), **not** the code commit
- `delta`: negative improves when `direction=min`; positive improves when `max`

### experiments/NNN-<slug>.md — experiment record

Write-once. Created only when `status ∈ {keep, invalid}`.

```yaml
---
id: NNN
slug: <slug>
kind: experiment
date: <ISO8601>
status: keep | invalid
parent: <NNN of parent>
source_hypothesis: H-NNN | -
commit: <SHA of commit B>
metric: <number | NaN>
delta: <signed | NaN>
---

## Hypothesis        one paragraph
## Changes           bullets: file:line — why
## Result            metric, delta, direction check, wall time, surprises
## Log excerpt       last ~20 signal lines
## Notes             caveats, related FACTS/LEADS bullets
```

### research/research.tsv

5 columns, one row per completed session.

```
id	type	date	report	one_line
R-008	digest	2026-04-20	research/008-muon-digest.md	Muon optimizer; H-019, H-020
R-009	reflect	2026-04-22	research/009-reflect-cycle-42.md	reflect after 10 exps; H-021 added
```

`type` ∈ {digest, sweep, eda, broader-tooling, reflect}.

### research/NNN-<slug>.md — session digest

Write-once.

Mostly free-form prose, focused on the topic from the brief. Required scaffolding is light:

```yaml
---
id: R-NNN
slug: <slug>
type: digest | sweep | eda | broader-tooling | reflect
date: <YYYY-MM-DD>
trigger: <backlog id or prompt>
---

## Topic
One paragraph: what was investigated and why.

## Findings
Free-form. Write what you actually learned — claims, numbers, reframings,
what surprised you. Organise however the material wants to be organised.

## Hypotheses produced
- H-NNN — <one-liner> · falsifier: <numeric threshold>
- …

## Sources
- <url / arxiv id / file path> — one line on why it mattered
- …

Log every load-bearing source. Skip obvious junk, but err on the side of
logging — future reflect passes will thank you.

## Recommendations   # type=reflect only
## Notes            # caveats, dead ends, things flagged speculative
```

### knowledge/<topic>.md

Emergent. Created only once a topic has accumulated ≥ 2 keep-experiments or reflect has explicitly promoted it. Verified facts, precise numbers, load-bearing heuristics. Not reshuffled.

### ID alphabet

NNN — experiment · R-NNN — research · H-NNN / Q-NNN / D-NNN / T-NNN — backlog (hypothesis / question / deferred / tooling). Zero-padded three digits. Monotonic. Never reused.

### Hypothesis flow

Default: backlog (`kind=hypothesis`) → researcher (ground it, tighten the falsifier) → experimenter (measure). A sharp, well-founded idea may skip researcher; a vague one may loop back to researcher. Detours are judgement calls, not violations.

---

## Sub-agent protocols

Full protocols live in `agents/experimenter.md` and `agents/researcher.md` (copied during setup into the project's `.claude/agents/` as `experimenter.md` and `researcher.md`; only Mission and Common failure modes are adapted — everything else is left untouched). Below is only goals and key guardrails.

**experimenter** — a disciplined senior engineer. Goal: exactly one experiment, end-to-end. Enters a worktree pre-created by main on branch `exp/NNN-<slug>`, applies the change_plan (minimal diff, one variable, nothing outside scope), runs the eval with a timeout, parses the metric, decides `keep/discard/crash/timeout/invalid`, makes two commits (A: code, B: TSV + note), returns a compact report. **The recorded number is ground truth:** no fabrication, no retry-to-success, no best-of-N, no silent flag twiddling. Writes only to `autoresearch/experiments/` and target files inside scope. On `keep`/`invalid` writes a note; on `discard/crash/timeout` — no note. Details in `agents/experimenter.md`.

**researcher** — a PhD-level collaborator. Goal: exactly one research task of one of these types:

- **digest** — one source, deep read.
- **sweep** — 3–5 targeted queries, synthesis; primary sources preferred over aggregations.
- **eda** — short scripts in `/tmp/research-<id>/` (outside the repo), ≤ 60 s, no GPU, no network beyond URLs from the brief.
- **broader-tooling** — evaluate tools outside the metric path; never modifies the eval.
- **reflect** — analyse recent experiments + FACTS/LEADS → hypotheses + a `## Recommendations` section that main applies mechanically.

Proposes 1–3 hypotheses with a **numeric** falsifier, target files, predicted magnitude. Cites load-bearing claims. Writes only to `research/` (plus `/tmp/research-<id>/` scratch). Never edits `experiments.tsv`, CONFIG, target files, the eval, FACTS.md, LEADS.md, or backlog.tsv. Details in `agents/researcher.md`.

Common style: briefs are self-contained (no back-asks); the report is insights first, metadata last.

---

## 4 phases

| Phase | Artifact | Exit gate |
|---|---|---|
| 1. Setup | CLAUDE.md, CONFIG.md, tree, both agents installed | CONFIG valid, scaffold created |
| 2. Prepare | `bootstrap.{sh,md}`, integrations verified | bootstrap exit 0, all green |
| 3. Baseline | row 000 in experiments.tsv, ATLAS initialised | row 000 parses → CONFIG + bootstrap freeze |
| 4. Loop | endless dispatch/integrate | exits on user interrupt |

### Phase 1 — Setup (with the user)

**Step 1. Repo cartography → CLAUDE.md.** Explore entry points, build, target files, eval flow. Write CLAUDE.md at the repo root capturing the whole architecture and context you understood.

**Step 2. Interview via AskUserQuestion blocks.** One call per block; pre-sketch options from the repo, then ask.

- **A · Goal, metric, direction.** Target file(s) · metric · min/max · seed policy (`fixed:N` / `sampled:K-runs` / `none`).
- **B · Metric suggestions.** Catalogue: val_loss, pass_at_k, f1_macro, auroc, judge_score, latency_p99_ms, bundle_kb, hbm_peak_gb, etc. (not a closed list).
- **C · Eval flow.** Command · parser (`regex:…` / `json_path:…` / `exit_code`) · timeout · any custom TSV columns.
- **D · Research context.** Domain · known ceilings / SOTA · prior art · constraints.
- **E · Integrations.** Grep for W&B, MLflow, Docker, LLM judges. One AskUserQuestion call with one sub-question per detected integration (max 4): scope + env vars + health command.

**Step 3. Scaffold.** Build the tree under `autoresearch/`. Write CONFIG.md from Step 2 answers. Create TSVs with headers only. Write FACTS.md and LEADS.md with empty sections. Seed backlog with 2–4 `hypothesis/pending` rows + 1–3 `deferred/pending`. Copy this skill's `agents/experimenter.md` and `agents/researcher.md` into the project's `.claude/agents/`; adapt only Mission and Common failure modes to the domain. Do not touch frontmatter, the Protocol section, or the schemas.

### Phase 2 — Prepare

Write `bootstrap.sh` (or `bootstrap.md` for multi-script / computer-use / manual-auth setups) — idempotent, rerunnable, artifacts in `.gitignore`. Before any download > 100 MB or write to a shared system — confirm with the user. Run until exit 0. Run the health check of each integration. Append `YYYY-MM-DD — integrations verified: <names>` to FACTS.md Decisions.

### Phase 3 — Baseline

Dispatch experimenter against the unmodified target. Brief: experiment 000, slug `baseline`, no hypothesis, no change plan; worktree `../autoresearch-wt/exp-000-baseline`, branch `exp/000-baseline` off HEAD; `eval / parse / timeout / direction / seed policy / custom columns` from CONFIG; current best = NaN. Main creates the worktree before dispatch. Experimenter skips commit A (no change plan → no edit), runs the eval, writes row 000 and `000-baseline.md`, makes commit B `"exp 000: baseline"`. Main fast-forwards into `main`.

Initialise ATLAS Now with `000` as best; prepend `000` to Recent signal.

If the metric is NaN — iterate over `eval_command` / `parse_method` / `timeout_sec`. CONFIG stays editable until row 000 parses. Once it does — CONFIG and bootstrap **freeze**; any further change ⇒ re-setup.

### Phase 4 — Loop

Main becomes an event-driven coordinator. See the next section.

---

## Coordination (phase 4)

**Main never sits idle.** Main is single-threaded — it doesn't think in parallel — but between dispatch and return it prepares and dispatches the next brief (up to the concurrency cap), verifies the latest return, compresses ATLAS/FACTS/LEADS as a mutable `.md` approaches ~400 lines, and reorders or trims `backlog.tsv`. Idling is fine only if nothing fits — main wakes on the next Agent-complete.

**Concurrency** (override in CONFIG). Baseline:

- 1 experimenter (heavy GPU/disk evals serialise).
- 3 researcher (cheap, I/O-bound).

Before dispatching experimenter, main creates the worktree:

```sh
git worktree add ../autoresearch-wt/exp-NNN-<slug> -b exp/NNN-<slug> <parent_commit>
```

`worktree_path` and `branch` go in the brief; the sub-agent `cd`s into it and works there.

### Delegation (main → sub-agent): task brief

Prose, self-contained. Write it like a short message to a colleague: say what needs to happen, and give concrete facts the sub-agent couldn't guess. Include detail only when omitting it would force guessing.

**experimenter brief** must contain: the hypothesis (one or two sentences with a direction and a **numeric** falsifier); the change plan (file paths with line numbers where it matters, exact values); worktree path + branch + parent commit; scope (subset of `CONFIG.scope`); eval + parse + timeout; direction + current best; seed policy; paths for the TSV row and the note; `custom_tsv_columns` in order.

**researcher brief** must contain: a one-sentence task; `type` (digest / sweep / eda / broader-tooling / reflect); `trigger` (backlog id or prompt); research id + slug. Inline context that saves re-reading: relevant recent experiments, specific bullets from FACTS/LEADS, URLs / arxiv ids / file paths. For `reflect`: inline the last N experiments and the relevant FACTS/LEADS slice. Paths for the TSV row and the report.

### Return (sub-agent → main): compact report

Structure:

1. Sentinel: `EXPERIMENT_DONE` or `RESEARCH_DONE`.
2. One sentence with the status and the key number.
3. Body — what was *actually* learned: numbers, what surprised you, how the hypothesis reframes, the obvious follow-up.
4. At the end: a `refs:` line with paths and SHAs. Everything else main reads from the TSV.

**Rule.** If removing the body wouldn't change any decision main makes next, rewrite the body with the actual finding. The sub-agent spent compute and context learning *something*; the job of the report is to convey that, not to recite ids main already knows.

Mini-example:

```
EXPERIMENT_DONE
042 warmup-cosine: keep. val_loss 3.041 (-0.012 vs best), H-017.

Cosine warmup at 10% clears linear-2% on every axis; the improvement
concentrates in the first 3k steps (curves converge from 5k) — the win is
about early-lr shape, not asymptotic. Worth testing warmup_ratio ∈ {5%, 15%}.

refs: commit a1b2c3d · note experiments/042-warmup-cosine.md
```

### Verification (after every return)

Cheap disk check, not a gate:

1. `tail -1 <referenced_tsv>` starts with the reported id.
2. If the status implies a note — the file exists on disk.
3. Mismatch → trust the TSV, log to FACTS Anti-cheat log (`YYYY-MM-DD — <id> report/tsv mismatch, trusting TSV`), skip integration for this return.

### Integration by return type

**Experiment keep:**

```sh
git merge --ff-only exp/NNN-<slug>
git worktree remove ../autoresearch-wt/exp-NNN-<slug>
git branch -d exp/NNN-<slug>
```

Then: promote the matching bullet from LEADS Emerging into FACTS Established, citing `exp/NNN`; mark the backlog row `consumed/keep`; update ATLAS Now with the new best; prepend to Recent signal.

**discard / crash / timeout:** the code change must *not* reach main, only the record commit.

```sh
git cherry-pick <record_commit>
git worktree remove ../autoresearch-wt/exp-NNN-<slug>
git branch -D exp/NNN-<slug>
```

Close the backlog row with `outcome=<status>`; note the attempt in ATLAS Recent signal. A recurring pattern → an entry in FACTS Dead ends.

**invalid**: cherry-pick the record commit if there is one; otherwise just drop the worktree. Close backlog `outcome=invalid`. Two consecutive invalids → `recommend_resetup=true` in ATLAS Now, pause experimenter dispatch; researchers keep going.

**Research digest / sweep / eda / broader-tooling**: hypotheses → backlog as pending `H-NNN`; supported claims → LEADS Emerging or Domain context.

**Research reflect**: apply the Recommendations section to FACTS / LEADS / backlog mechanically.

### When something goes wrong

Log, recover, keep going. Escalate only when the loop can't move.

- **TSV/report mismatch** → trust the TSV, log to FACTS Anti-cheat, skip.
- **Two consecutive invalids** → `recommend_resetup=true`, pause experimenter.
- **ff-only conflict** (shouldn't happen at concurrency=1) → abort, pause, notify the user.
- **Foreign write by a sub-agent** → `git checkout HEAD -- <path>`, log in Anti-cheat, flag the agent template for review.
- **Orphan worktree** after a failed integration → `git worktree remove --force` + `git branch -D`, reconstruct state from the TSV.

### Stopping

Only on user interrupt: write `paused` into ATLAS Now, let running sub-agents finish, integrate their returns, stop.

### Re-setup

Triggered when CONFIG, bootstrap, or the eval must change after baseline. Last resort. Most "this feels like re-setup" moments are really a reason to file a `question` in backlog.

1. Stop the loop (user interrupt).
2. Clean up orphans: `git worktree list` → `git worktree remove --force` all `autoresearch-wt/*`; `git branch -D exp/*`.
3. Archive: `git mv autoresearch autoresearch.archive-<date>`.
4. Re-run Phases 1–3.
5. Hand-port relevant bullets from the old FACTS.md and LEADS.md into the new files. **The `experiments.tsv` history is not carried over** — the baselines differ.
