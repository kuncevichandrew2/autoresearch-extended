# loop

Per-experiment protocol. One call = one experiment.

## Protocol

1. **Read state and context.**
   ```sh
   cat ./autoresearch/state.md
   cat ./autoresearch/context.md
   ```
   Parse mechanical fields (best, last, experiments_since_reflection,
   no_improvement_streak, next experiment number `N`). Read hard
   constraints from context.

2. **Form a hypothesis.** Prefer the top-ranked entry in "Ideas to
   explore" below the `<!-- outer-loop-only -->` marker. Write:
   - One-sentence description (imperative, e.g. "Swap AdamW for Lion
     with lr=3e-4").
   - Kebab-case slug (`swap-adamw-for-lion`).

3. **Edit target file(s).** Single-variable, minimal diff. If you're
   tempted to change two things, pick one and queue the other as a new
   idea after reflection.

4. **Validate scope.**
   ```sh
   git diff --name-only
   ```
   Every path must be in `config.target`. Anything outside — including
   `./autoresearch/config.md`, `eval.sh`, `eval.py`, or the eval folder
   — triggers:
   ```sh
   git checkout -- .
   ```
   Log status `scope-violation`, write the experiment note, abort cycle.

5. **Commit.**
   ```sh
   git add <each target file>
   git commit -m "exp <NNN>: <description>"
   ```
   Use the experiment number zero-padded to 3 digits.

6. **Run eval with timeout.**
   ```sh
   timeout <config.timeout_sec> <config.eval_command> \
     >/tmp/run.log 2>&1
   EVAL_EXIT=$?
   ```
   Never pipe the log elsewhere; the loop re-reads it on crashes.

7. **Parse metric.** Use `config.parse_method`:
   - `summary_block` — extract the last fenced ```json block, take
     `<metric_name>`.
   - `regex:<pattern>` — last match of `<pattern>` in `/tmp/run.log`.
   - `json_path:<expr>` — JSONPath into the judge output file.
   - `file:<path>` — read the file.
   - `exit_code` — `EVAL_EXIT`.
   Parse failure or `EVAL_EXIT != 0` (unless source is `exit_code`) →
   status `crash`; keep going to step 8 with `metric=NaN`,
   `delta=NaN`.

8. **Decide keep/discard (direction-aware).**
   - `metric_direction: min` → keep iff `metric < best`.
   - `metric_direction: max` → keep iff `metric > best`.
   - Equal or worse → discard. Crash → discard.
   Discard path:
   ```sh
   git reset --hard HEAD~1
   ```
   Keep path: update `best` in the state update (step 11).

9. **Append to results.tsv.** One row, tab-separated, exact form:
   ```sh
   printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
     "$N" "$(git rev-parse --short HEAD)" "$METRIC" "$DELTA" \
     "$STATUS" "$DESC" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TAGS" \
     >> ./autoresearch/results.tsv
   ```
   `$STATUS` ∈ {`kept`, `discarded`, `crash`, `scope-violation`}.
   `$TAGS` is comma-separated kebab-case (e.g. `optimizer,lr`).

10. **Write `./autoresearch/experiments/NNN-<slug>.md`** with sections:
    - Front matter: `status`, `metric`, `commit` (or `reset to <sha>`
      if discarded), `tags`.
    - `## Hypothesis` — one paragraph.
    - `## Changes` — 3–8 bullets of the diff.
    - `## Result` — one paragraph.
    - `## Log excerpt` — last ~20 lines of `/tmp/run.log` in a fence.

11. **Regenerate the mechanical sections of state.md.** Above the
    `<!-- outer-loop-only -->` marker only:
    - `best = <new or unchanged>`
    - `last = <this metric>`
    - `experiments_since_reflection += 1`
    - `no_improvement_streak` → 0 on keep, +=1 on discard/crash
    - `recent trajectory` → append `NNN status metric`
    **PRESERVE everything below the marker verbatim.** Ideas, learnings,
    and what-not-to-try belong to reflect.

12. **Print the one-liner and return control:**
    ```
    #<N>: <status> | <metric_name>=<value> (Δ=<delta>) | <description>
    ```

## Failure modes

- **Scope violation** — agent edited outside `config.target`. Caught at
  step 4. `git checkout -- .`, log, abort. If two cycles in a row,
  recommend re-setup.
- **Crash loop** — 3 crashes in 5 experiments. Trigger reflect on the
  next cycle regardless of `reflect_every`.
- **Flat metric** — `no_improvement_streak ≥ reflect_on_plateau`. Loop
  dispatcher routes to reflect next.
- **Regression marked kept** — the parser returned the wrong sign. Audit
  `metric_direction` and the parse expression against `/tmp/run.log`;
  fix in setup, never mid-loop.
- **Missing log row** — if `results.tsv` wasn't appended, the run didn't
  happen. Re-run the experiment from scratch; do not synthesize a row.
