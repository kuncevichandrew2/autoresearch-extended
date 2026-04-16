# reflect

Periodic meta-step. Reads the log, updates the idea backlog, never edits
target files or re-runs the eval.

## Protocol

1. **Read the log.**
   ```sh
   cat ./autoresearch/results.tsv
   ```
   Tally `kept`, `discarded`, `crash`, `scope-violation`. Note current
   best, baseline, and the gap. Identify the top-3 kept experiments by
   delta.

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
   Confirm kept experiments have commits; discarded ones don't.
   Discrepancies are the first signal of a broken cycle.

4. **Pattern analysis.** Write 2–4 sentences for each:
   - **What worked.** Tags or regions where keeps concentrate.
   - **What's exhausted.** Tags where the last 5+ attempts all lose.
   - **Plateau signal.** Trajectory shape — monotone, sawtooth, flat.
   - **Trajectory shape.** Is improvement linear, diminishing, or
     stalled? Estimate remaining headroom.

5. **Pick a strategy level.**
   - **1–5 low-hanging fruit** — hyperparameters, tiny code tweaks.
   - **6–15 systematic** — swap components, ablate, scan ranges.
   - **16–30 structural** — change architecture, rewrite hot paths.
   - **30+ radical** — rethink the problem statement within the
     context's hard constraints.
   If `no_improvement_streak ≥ reflect_on_plateau`, escalate one level
   above current.

6. **Rewrite strategy sections of state.md BELOW the marker only.**
   Three sections:
   - `### Learnings` — condensed facts, 3–8 bullets.
   - `### What not to try` — exhausted paths, 2–6 bullets with reasons.
   - `### Ideas to explore` — 2–5 ranked ideas, each with a one-line
     rationale and an expected tag.
   **Do not touch mechanical sections above the marker.** Reset
   `experiments_since_reflection` to 0 there ONLY (one-line edit).

7. **Flag metric gaming.** Any `kept` experiment that:
   - looks like a safety bypass, or
   - violates a hard constraint from `context.md`, or
   - matches a known gaming pattern (exec of ground-truth file,
     disabled tests, trivial early-exit),
   gets a `⚠ gaming candidate` bullet in `### Learnings` with the
   experiment number. Reference the Langfuse autoresearch case as
   precedent. If `metric_source: llm-judge`, add: "scores are noisy —
   trust aggregate trends, not single wins."

8. **Print**
   ```
   Reflection complete | <N> experiments | strategy level: <L> | <K> ideas queued
   ```
   and return control. The next cycle runs develop again.

## When to escalate

Escalate one strategy level if ANY of:
- `no_improvement_streak ≥ reflect_on_plateau` (plateau).
- Three consecutive crashes (brittle region).
- Current strategy level exhausted the obvious tag space (every tag in
  the map has ≥ 3 discards in a row).
- The gap to a known ceiling (user-provided in context) is < 10% —
  structural changes may be the only lever left.

De-escalate (step down) if the last reflection escalated and the next 3
experiments all kept — the simpler tier still has juice.
