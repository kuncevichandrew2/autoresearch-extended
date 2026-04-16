# setup

One-time collaborative setup, four internal phases:

1. **Analyze & propose** — read the repo, print a full proposal, ask for
   missing context.
2. **Scaffold** — write `config.md`, `context.md`, any missing eval artifact.
   One "Approve?" gate.
3. **Baseline** — run the eval once unmodified, initialize state.
4. **Hand off** — exit to develop, which loops autonomously.

> Exit setup only after phase 3 produces a real baseline metric.

## Working principle

**Propose, don't interrogate.** The first thing the user sees is a complete
proposal they can react to — not a questionnaire. Read the code before asking.
The only question allowed before the proposal is none; the only question
after it is "what other context should I know?".

## Phase 1 — analyze & propose

1. **Inventory the repo.**
   - `ls -la` at root. Read `README*`, `pyproject.toml` / `package.json` /
     equivalent, any `Makefile`, any existing entrypoints.
   - `git log --oneline -n 20` to see active work.
   - Scan for: entrypoint scripts, metric-producing code, data/eval splits,
     existing test/bench harnesses.
   - Cap at ~15 files; skim, don't deep-read. Prioritize README and whatever
     it points to.

2. **Print one proposal block** with:
   - **Project** — 2–4 sentences on what this repo does.
   - **Proposed target** — one file (or small set) the agent will edit.
     Name the path; justify in one sentence. If the target doesn't exist
     yet, say so and mark "will scaffold in phase 2".
   - **Proposed metric** — `name`, `direction: min|max`,
     `source: human|code|llm-judge`, `parse_method`. Justify briefly.
   - **Proposed eval** — the shell command and what it runs. If multi-step,
     sketch the pipeline.
   - **Proposed budget** — `timeout_sec` inferred from what the eval looks
     like it takes.
   - **Assumptions** — 2–5 bullets (hardware, dataset, eval fidelity,
     anything inferred rather than read).
   - **Open questions** — 0–3 specific questions the user must resolve
     before phase 2.

3. **Ask for user context, once:**
   > "Any additional context, constraints, or corrections? (hardware, hard
   > rules, things to avoid, scope limits, things I misread)"

   Wait for a reply. `none` is valid.

4. **Fold the reply into the proposal.** If the user changed target, metric,
   eval, or budget, reprint the affected lines. Do not advance while open
   questions remain.

## Phase 2 — scaffold

5. **Write `./autoresearch/context.md`**: project overview, what we're
   optimizing and why, **hard constraints** (the user's reply verbatim plus
   the obvious ones from the proposal), what's already been tried (if
   visible in git), domain pointers.

6. **Write `./autoresearch/auxiliary.md`** for side integrations (W&B, Slack,
   …). One template entry with API-key-name placeholders; empty if nothing
   applies.

7. **Write `./autoresearch/config.md`**:
   - `## Fix` — `target`, `eval_command`, `timeout_sec`, `metric_name`,
     `metric_direction`, `metric_source`, `parse_method`.
   - `## Changeable` — `reflect_every: 5`, `reflect_on_plateau: 3`,
     `max_experiments: unlimited`, `stop_after_plateau: never` (override
     per proposal).

8. **Scaffold missing eval artifacts.** If the proposal relies on `eval.sh`,
   `eval.py`, a judge script, or an entrypoint that doesn't exist yet,
   write them now. Do NOT modify existing eval code. If an existing
   entrypoint doesn't print the metric yet, add that single print line —
   and only that. Anything you scaffold here becomes read-only after setup.

9. **Approve gate.** Print the full `config.md`, the full `context.md`, and
   any scaffolded file. Ask exactly:
   > "Approve? (yes/no)"

   No silence. No implicit yes.

## Phase 3 — baseline

10. **Run the eval once unmodified.**
    ```sh
    timeout <timeout_sec> <eval_command> > /tmp/run.log 2>&1
    ```
    Parse failure → show stderr, fix collaboratively, re-run. Never skip.

11. **Initialize project state.**
    - `./autoresearch/state.md` — mechanical fields
      (`best`, `last`, `experiments_since_reflection=0`,
      `no_improvement_streak=0`) above the `<!-- outer-loop-only -->`
      marker; empty strategy sections below.
    - `./autoresearch/results.tsv` — header row
      `experiment\tcommit\tmetric\tdelta\tstatus\tdescription\ttimestamp\ttags`
      plus `000` baseline row.
    - `./autoresearch/experiments/000-baseline.md` — hypothesis: none,
      result: baseline value.

12. **Print** `Setup complete. Baseline <metric_name>=<value>. Entering develop.`
    and hand off.

## Phase 4 — hand off

No further setup action. The next invocation routes to `02-develop.md` and
runs autonomously until `max_experiments` or `stop_after_plateau`. Re-enter
setup only on explicit user request — it destroys the prior contract.

## After setup

Everything outside `config.target` is **read-only**: the `## Fix` section of
`config.md`, any scaffolded eval file, `context.md`, `auxiliary.md`, and
every other file. Edits to them are scope violations.
