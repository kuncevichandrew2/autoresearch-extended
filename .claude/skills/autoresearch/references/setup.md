# Setup · Prepare · Baseline

Three one-time phases, run in order. Each phase has an exit gate — do not advance past a failure.

## Phase 1 — Setup (collaborative)

One session with the user. No background agents yet. Three steps, each with a single concrete artifact.

### Step 1 — Map the repo → `CLAUDE.md`

Explore the target repo **and** the two agent files in this skill (`agents/experimenter.md`, `agents/researcher.md`). Write a short `CLAUDE.md` at the repo root sketching the architecture: entry points, build system, target files, eval flow. As few words as possible.

**Artifact:** `CLAUDE.md`.

### Step 2 — Interview via four `AskUserQuestion` blocks

One `AskUserQuestion` **call per block** (not per sub-question, not all-in-one). Each block follows: **think** (scan repo, draft concrete options) → **ask** (bundle sub-questions with those options) → **think** (process answers) → next block. Record answers verbatim.

- **Block A · Target, metric, direction.** Pre-draft target-file candidates from the repo and metric candidates from the catalogue below. Ask: file(s) · metric · min/max.
  ```
  val_loss (min) · val_bpb (min) · pass_at_k (max) · exact_match (max)
  f1_macro (max) · auroc (max) · judge_score (max) · win_rate (max)
  latency_p99_ms (min) · tps (max) · hbm_peak_gb (min) · bundle_kb (min)
  ```
- **Block B · Eval flow.** Pre-draft candidate commands, parse strategies (`summary_block` / `regex:…` / `json_path:…` / `file:…` / `exit_code`), and a timeout. Ask: single command or pipeline · command · parse · timeout.
- **Block C · Research context.** Pre-draft candidate domains, known ceilings / SOTA, prior-art pointers, likely hard constraints — as options to accept/edit/reject. Ask: domain · ceilings · prior art · constraints.
- **Block D · Integrations.** Grep for W&B, MLflow, Docker, LLM judges, etc. For each suspected one, pre-draft env vars and a health command. Ask per integration: in scope? · env vars · health.

**Artifact:** four recorded answer sets.

### Step 3 — Scaffold the project

Build the layout defined in SKILL.md ## Per-project layout. In one pass:

- Write `autoresearch/CONFIG.md` from Step 2 answers.
- Create the header-only TSVs and `README.md` stubs per that layout; seed `backlog.tsv` with 2–4 `hypothesis/pending` + 1–3 `deferred/pending` rows from the interview.
- Copy `agents/{experimenter,researcher}.md` into `.claude/agents/`. You **may** lightly adapt the body to this project (task framing, examples), but **keep the top frontmatter section unchanged and preserve each agent's purpose** — no drastic rewrites. If a destination file already exists, stop and ask; never overwrite.

**Exit gate:** `CLAUDE.md` + `CONFIG.md` valid · tree + backlog scaffolded · two agents installed.

## Phase 2 — Prepare

Write `autoresearch/bootstrap.sh` (or `bootstrap.md` when setup needs multiple scripts or complex instructions like computer use) from Phase 1 answers — idempotent, re-runnable, artifacts `.gitignore`d, stop-and-confirm before any >~100 MB pull. Run it to exit 0, then run each integration's `health` command, then append `YYYY-MM-DD — integrations verified: <names>` to `LORE.md ## Decisions`.

```
write bootstrap → run to exit 0 → health-check integrations → record in LORE
```

**Exit gate:** bootstrap exit 0 · every integration green.

## Phase 3 — Baseline

Dispatch the experimenter with a minimal brief (`experiment_id: 000`, `slug: baseline`, `hypothesis: baseline`, empty `change_plan`; full shape in `protocol.md ## Task brief`). It runs eval on the unmodified target, writes row `000` to `experiments.tsv`, and commits `"exp 000: baseline"`. Then initialise `ATLAS.md ## Now` with baseline as `best` and prepend it to `## Recent signal`.

If the metric is `NaN`, iterate with the user on `Eval` / `Parse` / `Timeout` — `CONFIG.md` stays editable until baseline parses.

**Exit gate:** row `000` has a parseable scalar · `ATLAS.md` rendered · `CONFIG.md` and bootstrap freeze (changes require re-setup).
