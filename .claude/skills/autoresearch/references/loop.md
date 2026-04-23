# Loop — Phase 4, hot path

After baseline, main becomes an event-driven coordinator. It dispatches `experimenter` and `researcher` as background sub-agents, waits for returns, integrates each one as it arrives, and kicks off the next task. Read alongside `protocol.md`.

## The cycle

**Baseline is done.** Main looks at `ATLAS.md`, `LORE.md`, and `backlog.tsv` and **thinks** about what to try next — which pending hypothesis is most promising, whether a fresh digest would help, whether a `reflect` is due. Then it dispatches work in the background: typically one experimenter and one researcher in parallel. Briefs are self-contained (see `protocol.md ## Task brief`) — sub-agents never re-fetch files.

**Main does not poll, but main never sits idle.** While sub-agents run in the background, main keeps working on everything that doesn't need their results: re-reading LORE and compressing stale bullets, pruning or re-ordering the backlog, sharpening the next task brief, spawning additional researchers/experimenters while capacity allows, tightening the ATLAS dashboard. The rule is **always be doing something useful** — thinking about state, shaping the next move, or dispatching more parallel work. Returns arrive asynchronously and may interleave: an experimenter finishes a run while the third researcher session is still digesting papers.

**When a return lands, main thinks.** It verifies the sub-agent actually wrote what it claimed (`protocol.md ## Verification`), then decides what the result means and updates the canon:

- *experiment kept* → promote the corresponding `LORE ## Emerging` bullet to `## Established`, mark the backlog row `consumed/keep`, merge the branch into main with `--ff-only`, update `ATLAS ## Now` with the new best.
- *experiment discarded / crashed / timed out / invalid* → close the backlog row with `outcome=<status>`, cherry-pick the record commit and drop the branch, note the attempt in `ATLAS ## Recent signal`. A pattern of failures may earn a `LORE ## Dead ends` entry.
- *research digest / sweep / eda / broader-tooling* → append the proposed hypotheses as pending `H-NNN` rows in `backlog.tsv`, add supported claims to `LORE ## Emerging`.
- *research reflect* → apply the report's `## Recommendations` to `LORE.md` and `backlog.tsv`.

**Then main thinks again** — state has changed — and dispatches the next task. Other sub-agents may still be running; their returns will be integrated the same way when they land. No cycle pairing, no "wait for both", no fixed cadence.

The loop ends only on user interrupt: write a `paused` marker in `ATLAS ## Now`, let in-flight sub-agents finish, integrate their returns, stop.

## When things go wrong

Log it, recover, keep going. Escalate only when the loop itself can't make progress.

- TSV / report mismatch → trust the TSV, log to `LORE ## Anti-cheat log`, skip this return.
- Two consecutive `invalid` → set `recommend_resetup=true`, pause experimenter dispatch (researcher keeps running).
- `--ff-only` conflict (shouldn't happen under worktree isolation) → abort the merge, pause, notify the user.
- No return (harness timeout) → on next dispatch, scan the TSV for orphan ids, mark them `crash`, continue.
- Sub-agent wrote outside its owned directory → revert foreign paths, log to `LORE ## Anti-cheat log`, flag the agent template for review.
