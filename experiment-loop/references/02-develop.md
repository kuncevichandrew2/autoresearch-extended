# develop

Per-experiment protocol. One call = one experiment.

## Working principle

**Surgical, single-variable diffs.** Every changed line must trace to the
hypothesis in step 2. Don't fix adjacent things, don't rename, don't
"improve" nearby code — queue those as new ideas after the next reflect.
Match existing style. Remove only imports/helpers that YOUR change
orphaned; leave pre-existing dead code alone.

## Protocol

1. **Read state and context.**
   ```sh
   cat ./autoresearch/state.md
   cat ./autoresearch/context.md
   ```
   Parse `best`, `last`, `experiments_since_reflection`,
   `no_improvement_streak`, next experiment number `N`.

2. **Form a hypothesis.** Prefer the top-ranked entry in "Ideas to
   explore" (below the `<!-- outer-loop-only -->` marker). Write:
   - One-sentence description, imperative ("Swap AdamW for Lion lr=3e-4").
   - Kebab-case slug (`swap-adamw-for-lion`).

3. **Edit target file(s).** Single-variable, minimal diff.

4. **Validate scope.**
   ```sh
   git diff --name-only
   ```
   Every path must be in `config.target`. Anything outside — including
   `config.md`, the eval script, bootstrap artifacts, anything in
   `bootstrap_artifacts` — triggers:
   ```sh
   git checkout -- .
   ```
   Log `scope-violation`, write the experiment note, abort cycle.

5. **Commit.**
   ```sh
   git add <each target file>
   git commit -m "exp <NNN>: <description>"
   ```
   Experiment number zero-padded to 3 digits.

6. **Run eval with timeout.**
   ```sh
   timeout <config.timeout_sec> <config.eval_command> >/tmp/run.log 2>&1
   EVAL_EXIT=$?
   ```
   Never pipe the log elsewhere.

7. **Parse metric** per `config.parse_method`:
   - `summary_block` — last fenced ```json block, take `<metric_name>`.
   - `regex:<pattern>` — last match in `/tmp/run.log`.
   - `json_path:<expr>` — JSONPath into the judge output file.
   - `file:<path>` — read the file.
   - `exit_code` — `EVAL_EXIT`.

   Parse failure or `EVAL_EXIT != 0` (unless source is `exit_code`) →
   status `crash`, `metric=NaN`, `delta=NaN`, continue to step 8.

8. **Decide keep/discard (direction-aware).**
   - `metric_direction: min` → keep iff `metric < best`.
   - `metric_direction: max` → keep iff `metric > best`.
   - Equal, worse, or crash → discard.

   Discard path:
   ```sh
   git reset --hard HEAD~1
   ```
   Keep path: update `best` in step 11.

9. **Append one row to `results.tsv`.**
   ```sh
   printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
     "$N" "$(git rev-parse --short HEAD)" "$METRIC" "$DELTA" \
     "$STATUS" "$DESC" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TAGS" \
     >> ./autoresearch/results.tsv
   ```
   `$STATUS` ∈ {`kept`, `discarded`, `crash`, `scope-violation`}.
   `$TAGS` is comma-separated kebab-case.

10. **Write `./autoresearch/experiments/NNN-<slug>.md`** with:
    - Front matter: `status`, `metric`, `commit` (or `reset to <sha>` if
      discarded), `tags`.
    - `## Hypothesis` — one paragraph.
    - `## Changes` — 3–8 bullets of the diff.
    - `## Result` — one paragraph.
    - `## Log excerpt` — last ~20 lines of `/tmp/run.log` in a fence.

11. **Regenerate mechanical fields of `state.md`** (above the marker only):
    - `best` = new or unchanged
    - `last` = this metric
    - `experiments_since_reflection += 1`
    - `no_improvement_streak` → 0 on keep, +=1 on discard/crash
    - `recent trajectory` → append `NNN status metric`

    **Preserve everything below the marker verbatim.**

12. **Print and return control:**
    ```
    #<N>: <status> | <metric_name>=<value> (Δ=<delta>) | <description>
    ```

## Failure modes

- **Scope violation** — caught at step 4. `git checkout -- .`, log, abort.
  Two in a row → recommend re-setup.
- **Crash loop** — 3 crashes in 5 experiments → force reflect next cycle.
- **Flat metric** — `no_improvement_streak ≥ reflect_on_plateau` → reflect.
- **Regression marked kept** — parser sign bug. Audit `metric_direction`
  and parse expression against `/tmp/run.log`; fix in re-setup, never
  mid-develop.
- **Missing log row** — re-run from scratch; never synthesize a row.
