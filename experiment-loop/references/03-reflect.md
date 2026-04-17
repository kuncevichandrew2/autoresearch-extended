# reflect

Periodic meta-step. Reads the log, regenerates the analysis notebook,
updates the idea backlog. Never edits target files or re-runs the eval.

## Protocol

1. **Read the log.**
   ```sh
   cat ./autoresearch/results.tsv
   ```
   Tally `kept`, `discarded`, `crash`, `scope-violation`. Note current
   best, baseline, the gap. Identify top-3 kept by delta.

2. **Build the tag map.**
   ```sh
   ls ./autoresearch/experiments/*.md
   ```
   For each, read the `tags:` line and the status. Produce a `tag →
   [status,…]` summary (e.g. `optimizer: [kept, kept, discarded]`).

3. **Cross-reference git.**
   ```sh
   git log --oneline -n 50
   ```
   Confirm kept experiments have commits and discarded ones don't.
   Discrepancies are the first signal of a broken cycle.

4. **Regenerate `./autoresearch/analysis.ipynb`.** A full data analysis
   notebook. Inputs: `results.tsv` and `experiments/*.md`. Required cells:
   - **Load** — read `results.tsv` into pandas.
   - **Trajectory** — line plot of `metric` vs `experiment`, with `best`
     as a step line and baseline as a horizontal reference.
   - **Keep/discard timeline** — scatter coloured by `status`.
   - **Tag performance** — bar chart of keep-rate per tag; table of
     mean delta per tag.
   - **Streak analysis** — longest kept / discarded / crash streaks;
     distribution of `no_improvement_streak`.
   - **Top wins** — table of the 5 largest positive deltas with commit
     SHA and description.
   - **Regression watch** — any `kept` whose later `last` drifted below
     (worse than) it — flag possible eval noise.

   Preferred path: **invoke a data-analysis skill if one is installed**
   (check `ls ~/.claude/skills/ | grep -Ei 'data-analysis|notebook|jupyter'`).
   Hand it `./autoresearch/results.tsv` and the rubric above. If none is
   available, write the notebook directly with `nbformat` — one Python
   script `./autoresearch/build_notebook.py` (idempotent) keeps this step
   deterministic. Commit both the script and the rendered `.ipynb`.

5. **Pattern analysis.** 2–4 sentences each:
   - **What worked** — tags/regions where keeps concentrate.
   - **What's exhausted** — tags whose last 5+ attempts all lose.
   - **Plateau signal** — trajectory shape: monotone, sawtooth, flat.
   - **Headroom** — linear, diminishing, or stalled? Estimate remaining.

6. **Pick a strategy level.**
   - **1–5 low-hanging** — hyperparameters, tiny code tweaks.
   - **6–15 systematic** — swap components, ablate, scan ranges.
   - **16–30 structural** — change architecture, rewrite hot paths.
   - **30+ radical** — rethink the problem within hard constraints.

   If `no_improvement_streak ≥ reflect_on_plateau`, escalate one level.

7. **Rewrite the strategy block of `state.md` (below the marker only).**
   Three sections:
   - `### Learnings` — condensed facts, 3–8 bullets.
   - `### What not to try` — exhausted paths, 2–6 bullets with reasons.
   - `### Ideas to explore` — 2–5 ranked ideas, each with a one-line
     rationale and an expected tag.

   **Do not touch mechanical sections above the marker.** Reset
   `experiments_since_reflection` to 0 there ONLY (one-line edit).

8. **Flag metric gaming.** Any `kept` experiment that:
   - looks like a safety bypass, or
   - violates a hard constraint from `context.md`, or
   - matches a known gaming pattern (exec of ground-truth file,
     disabled tests, trivial early-exit),

   gets a `⚠ gaming candidate` bullet in `### Learnings` with the
   experiment number. If `metric_source: llm-judge`, add: "scores are
   noisy — trust aggregate trends, not single wins."

9. **Print**
   ```
   Reflection complete | <N> experiments | strategy level: <L> | <K> ideas queued | notebook: ./autoresearch/analysis.ipynb
   ```
   and return control. The next cycle runs develop again.

## When to escalate

Escalate one strategy level if ANY of:
- `no_improvement_streak ≥ reflect_on_plateau` (plateau).
- Three consecutive crashes (brittle region).
- Every tag in the map has ≥ 3 discards in a row (space exhausted).
- Gap to a known ceiling (user-provided in context) is < 10%.

De-escalate if the last reflection escalated and the next 3 experiments
all kept — the simpler tier still has juice.
