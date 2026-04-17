# setup

One-time collaborative setup. Five phases:

1. **Analyze & propose** — read the repo, print a full proposal, ask for
   missing context.
2. **Scaffold** — write `config.md`, `context.md`, any missing eval artifact.
3. **Bootstrap** — run everything that must happen exactly once (dataset
   load, preprocessing, fixture seeding, base image build, …).
4. **Baseline** — run the eval once unmodified, initialize state.
5. **Hand off** — exit to develop, which loops autonomously.

Exit setup only after phase 4 produces a real baseline metric.

## Working principle

**Propose, don't interrogate.** The first thing the user sees is a complete
proposal they can react to — not a questionnaire. Read the code before
asking. The only question allowed before the proposal is none; the only
question after it is "what other context should I know?".

## Phase 1 — analyze & propose

1. **Inventory the repo.** `ls -la` at root. Read `README*`,
   `pyproject.toml` / `package.json`, any `Makefile`, existing entrypoints.
   `git log --oneline -n 20`. Scan for: entrypoint scripts, metric-producing
   code, data/eval splits, existing test/bench harnesses. Cap at ~15 files.

2. **Print one proposal block:**
   - **Project** — 2–4 sentences on what this repo does.
   - **Proposed target** — one file (or small set) the agent will edit.
     Justify in one sentence. If the target doesn't exist yet, mark "will
     scaffold in phase 2".
   - **Proposed metric** — `name`, `direction: min|max`,
     `source: human|code|llm-judge`, `parse_method`. **Must be scalar.**
   - **Proposed eval** — the shell command. If multi-step, sketch the
     pipeline.
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
   - **Assumptions** — 2–5 bullets (hardware, dataset, eval fidelity).
   - **Open questions** — 0–3 specific questions.

3. **Ask once:**
   > "Any additional context, constraints, or corrections? (hardware, hard
   > rules, things to avoid, scope limits, things I misread)"

   Wait. `none` is valid.

4. **Fold the reply into the proposal.** Reprint changed lines. Do not
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
