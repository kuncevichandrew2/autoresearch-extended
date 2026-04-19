# setup

One-time collaborative setup. Five phases:

1. **Explore & ask** — inventory the repo, then ask four structured
   questions whose option lists are informed by what was found.
2. **Scaffold** — write `config.md`, `context.md`, `auxiliary.md`, any
   missing eval artifact, and request approval.
3. **Bootstrap** — run everything that must happen exactly once (dataset
   load, preprocessing, fixture seeding, base image build, …).
4. **Baseline** — run the eval once unmodified, initialize state.
5. **Hand off** — exit to develop, which loops autonomously.

Exit setup only after phase 4 produces a real baseline metric.

## Working principle

**Explore first, then ask structured questions with repo-informed
defaults.** The user never sees a blank interrogation. Read the code
before the first question so every option you offer corresponds to a file
or command that actually exists in this repo. Use one `AskUserQuestion`
call with all four questions so the user answers them together. The only
follow-up is a single open "anything I misread?" prompt after the
proposal.

## Phase 1 — explore & ask

1. **Inventory the repo BEFORE asking anything.** `ls -la` at root. Read
   `README*`, `pyproject.toml` / `package.json`, any `Makefile`, existing
   entrypoints. `git log --oneline -n 20`. Scan for: entrypoint scripts,
   metric-producing code, data/eval splits, existing test/bench harnesses,
   known auxiliary integrations (W&B, MLflow, DVC, TensorBoard, Slack
   hooks). Cap at ~15 files. Do not call `AskUserQuestion` before this
   step completes — options must reflect real files/commands found here.

2. **Ask four structured questions** in a single `AskUserQuestion` call.
   Each question's options should be grounded in the inventory; include
   2–4 concrete options plus always-available "Other" (auto-provided).
   Recommend the closest option by putting it first and suffixing
   "(Recommended)".

   - **Q1 — target + objective.** "Which file(s) should the loop
     optimize, and what is the objective?" Options derived from found
     entrypoints (e.g. `train.py`, `src/api/search.py`,
     `prompts/assistant.md`). Each option must name concrete paths and a
     direction (min/max on a scalar). If nothing plausible exists, one
     option must be "Scaffold a new <kind>".
   - **Q2 — eval flow.** "What eval flow should run each iteration?"
     Options are **high-level flows**, not literal commands:
     *single command prints metric as last line*, *multi-step pipeline
     (build → run → judge → extract)*, *existing test/bench harness emits
     the number*, *LLM-judge on an artifact*. Pick options consistent
     with what the repo already has.
   - **Q3 — research context.** "What domain context / hard constraints
     should I record in `context.md`?" Options:
     *paste constraints inline now* (user types them as free text),
     *reference file(s) in the repo* (user lists paths to read),
     *use README + existing docs only*, *minimal — objective + timeout
     only*. This answer can be a simple string OR a set of paths.
   - **Q4 — auxiliary tools** (`multiSelect: true`). "Which auxiliary
     tools should I wire into `auxiliary.md`? These must NOT affect the
     optimization itself — only logging, visualization, or cycle speed."
     Options drawn from the relevant ecosystem, e.g. for ML:
     *Weights & Biases*, *MLflow*, *TensorBoard (local)*, *DVC*; for API
     work: *Grafana/Prometheus*, *OpenTelemetry*; for prompt eval:
     *promptfoo dashboard*, *Braintrust*. Always include *None*.

3. **Fold answers into one proposal block and print it:**
   - **Project** — 2–4 sentences on what this repo does.
   - **Proposed target** — paths from Q1 + justification. If the target
     doesn't exist yet, mark "will scaffold in phase 2".
   - **Proposed metric** — `name`, `direction: min|max`,
     `source: human|code|llm-judge`, `parse_method`. **Must be scalar.**
   - **Proposed eval** — the shell command implementing the Q2 flow. If
     multi-step, sketch the pipeline.
   - **Proposed one-time bootstrap** — bullet list of everything that
     should run **exactly once** and then freeze. Examples by domain:
     - *ML training*: download dataset, tokenize, cache splits, download
       pretrained weights, warm CUDA kernels.
     - *API latency*: seed a fixtures DB, build indexes, pre-populate
       cache, capture a representative request log.
     - *Prompt eval*: build the golden eval set, pin judge model/version,
       cache reference outputs.
     - *UI + screenshot*: `docker build` base image, install browser
       binaries, render a reference screenshot for the judge.
     Mark each as "needed" or "skip — none apply".
   - **Proposed budget** — `timeout_sec` inferred from eval shape.
   - **Proposed context** — how Q3's answer will be recorded (verbatim
     paste, list of files to summarize, or README pointer).
   - **Proposed auxiliary** — Q4 selections with API-key placeholders
     that will land in `auxiliary.md`.
   - **Assumptions** — 2–5 bullets (hardware, dataset, eval fidelity).
   - **Open questions** — 0–3 specific questions.

4. **Ask once, free-form:**
   > "Any corrections before I scaffold? (hardware, hard rules, things
   > to avoid, scope limits, anything I misread)"

   Wait. `none` is valid.

5. **Fold the reply into the proposal.** Reprint changed lines. Do not
   advance while open questions remain.

## Phase 2 — scaffold

5. **Write `./autoresearch/context.md`**: project overview, optimization
   goal, **hard constraints** (user's reply verbatim + obvious ones from
   the proposal), prior attempts visible in git, domain pointers.

6. **Write `./autoresearch/auxiliary.md`** for side integrations (W&B,
   Slack). Template entry with API-key placeholders; empty if none apply.

7. **Write `./autoresearch/config.md`**:
   - `## Fix` — `target`, `eval_command`, `timeout_sec`, `metric_name`,
     `metric_direction`, `metric_source`, `parse_method`,
     `bootstrap_artifacts` (list of paths produced by phase 3, all of
     which become immutable).
   - `## Changeable` — `reflect_every: 5`, `reflect_on_plateau: 3`,
     `max_experiments: unlimited`, `stop_after_plateau: never`.

8. **Scaffold missing eval artifacts** (`eval.sh`, `eval.py`, judge
   script, entrypoints the proposal relies on). Do NOT modify existing
   eval code. If an existing entrypoint doesn't print the metric yet,
   add that single print line — and only that.

9. **Approve gate.** Print the full `config.md`, the full `context.md`,
   and any scaffolded file. Ask exactly:
   > "Approve? (yes/no)"

   No silence, no implicit yes.

## Phase 3 — one-time bootstrap

10. **Run each bootstrap action from the proposal.** Write the actions as a
    script `./autoresearch/bootstrap.sh` (idempotent — re-runs should be
    no-ops via cache checks), then execute it:
    ```sh
    bash ./autoresearch/bootstrap.sh 2>&1 | tee /tmp/bootstrap.log
    ```
    Typical contents per domain:
    - *ML*: `python -c "from datasets import load_dataset; …"` to pull +
      tokenize + save to `./autoresearch/data/` (gitignored).
    - *API*: `sqlite3 ./autoresearch/fixtures.db < seed.sql`.
    - *Prompt eval*: generate `./autoresearch/evalset.jsonl`.
    - *UI*: `docker build -t <tag>-base .` and save image digest.

    Every output path listed here is appended to
    `config.md::Fix.bootstrap_artifacts` and is **immutable** from develop
    onward. If bootstrap fails, fix collaboratively and re-run — never
    half-bootstrap.

11. **Add bootstrap outputs to `.gitignore`** if they are large/binary
    (datasets, docker layers, DB files). Commit `bootstrap.sh` itself.

## Phase 4 — baseline

12. **Run the eval once unmodified.**
    ```sh
    timeout <timeout_sec> <eval_command> > /tmp/run.log 2>&1
    ```
    Parse failure → show stderr, fix collaboratively, re-run. Never skip.

13. **Initialize project state.**
    - `./autoresearch/state.md` — mechanical fields
      (`best`, `last`, `experiments_since_reflection=0`,
      `no_improvement_streak=0`) above the `<!-- outer-loop-only -->`
      marker; empty strategy sections below.
    - `./autoresearch/results.tsv` — header row
      `experiment\tcommit\tmetric\tdelta\tstatus\tdescription\ttimestamp\ttags`
      plus `000` baseline row.
    - `./autoresearch/experiments/000-baseline.md` — hypothesis: none,
      result: baseline value.

14. **Print** `Setup complete. Baseline <metric_name>=<value>. Entering develop.`
    and hand off.

## Phase 5 — hand off

No further setup action. Next invocation routes to `02-develop.md` and
runs autonomously until `max_experiments` or `stop_after_plateau`. Re-enter
setup only on explicit user request — it destroys the prior contract.

## After setup — what's frozen

Everything outside `config.target` is **read-only**: the `## Fix` section of
`config.md`, every scaffolded eval file, `bootstrap.sh` and every artifact
it produced, `context.md`, `auxiliary.md`. Touching them is a scope
violation.
