---
name: autoresearch
description: Autonomous optimization loop for any repository with a single scalar metric. Triggers on "run autoresearch", "optimize X by metric Y", "reduce loss / latency / bundle size", "improve pass rate", "find the best version of file X", "make it faster / smaller / better", a target file + metric, or any phrasing around iterative improvement toward a measurable goal. Works with any metric that prints one number (val_loss, p99_ms, bundle_kb, pass_at_k, judge_score, image_size_mb, …) — even if the user doesn't say the word autoresearch. After a one-time setup the main thread becomes an event-driven coordinator that dispatches two background sub-agents: experimenter (edits the target, runs the eval, records results) and researcher (reads sources, proposes hypotheses).
---

# autoresearch

A repo plus one metric (a number from a shell command) becomes an autonomous optimization loop. The main thread is an event-driven coordinator that holds all state and memory. Two background sub-agents, experimenter and researcher, do the work. Main dispatches them in the background, waits for completion notifications, reads each compact report, verifies disk state, and integrates the result; if concurrency headroom allows, it spawns new agents immediately; in free time main thinks and aggregates. Knowledge accumulates on disk; sub-agents read the project directly; briefings contain only pointers.

## Invariants

1. Frozen contract. CONFIG.md and bootstrap.sh are frozen after experiment 000 passes.
2. Binary keep/discard against a single scalar.
3. Experiments are ground truth, research is advisory.
4. Sub-agents write only to their own zone. Read access to the entire project.
5. One worktree per experiment. Main creates the worktree before dispatching experimenter; experimenter receives the path in its brief. Keep → ff-merge; otherwise → cherry-pick only commit B (record).
6. Surgical edits. Every changed line is justified by a hypothesis. No incidental cleanup.
7. Autonomous by default. After setup, main does not ask permission to continue.
8. User interrupts are first-class. A question or small request is handled inline; background sub-agents keep running.

## Principles

Invariants — what must never be violated. Principles — how to think.

1. **Main never idles.** Between dispatch and return, main prepares the next briefing, verifies the last return, compresses MEMORY/KNOWLEDGE when approaching the cap, reorders the Queue. Idle is acceptable only when nothing useful remains — then main waits for the next Agent-complete notification.
2. **Procedure separate from context.** Protocols and rules live in SKILL.md, agents/*.md, references/. State and accumulated knowledge live in CONFIG.md, MEMORY.md, KNOWLEDGE.md, log.tsv. Never mix procedure and context in the same file.
3. **Briefing = mini-spec.** A sub-agent has no session context; over-specifying is cheaper than debugging misunderstandings later. A long briefing is normal; it explicitly covers background, scope boundaries, and edge cases.
4. **Reports carry findings, not identifiers.** If removing the report body would leave main making the same decisions — rewrite the body. The sub-agent spent compute and context; the report's job is to surface numbers, surprises, and the obvious follow-up. Main already reads identifiers from the TSV.
5. **Falsifiers are numeric.** Every hypothesis carries a number that falsifies it. Without a numeric falsifier an experiment cannot conclude with an unambiguous keep/discard.
6. **Size discipline.** Every mutable `.md` under autoresearch/ stays ≤ ~400 lines (one Read window). Compression order and non-compressible sections are per-role (see "MEMORY.md skeleton"). Write-once notes (`NNN-<slug>.md`) are never touched.

## File structure

Everything the agent knows accumulates in autoresearch/. Tree, schemas, examples — references/file-structures.md.

### Memory: MEMORY.md and log.tsv

Each agent (main, experimenter, researcher) has its own pair: MEMORY.md (live context between tasks) and log.tsv (full event log). This is their private write zone; other agents do not write here (read access to the full project remains per the invariants). Each agent updates its own MEMORY.md and log.tsv upon completing its task.

- main           current/MEMORY.md + current/log.tsv
- experimenter   sub-agents/experiments/MEMORY.md + log.tsv
- researcher     sub-agents/research/MEMORY.md + log.tsv

knowledge/ — shared zone where the agent accumulates knowledge (in compressed form) across domains. Written only by main on keep.

### MEMORY.md skeleton

Section descriptions — references/file-structures.md. Sections are per-role:

```
main (current/):    Status · Queue · Recent · Patterns · Avoid
                    Optional: Open questions · Tooling notes · Scratch
experimenter:       Status · Recent · Patterns · Avoid
                    Optional: Tooling notes · Scratch
researcher:         Status · Recent · Patterns · Avoid
                    Optional: Adjacent domains · Scratch
cap:                ~400 lines
compression order (main):       Recent → optional → Open questions
compression order (exp/res):    Recent → optional
do not compress:    Status, Queue (main only), Patterns, Avoid
```

Cold-start (current/MEMORY.md only): a fresh main, given only CONFIG.md, current/MEMORY.md, and the last 30 lines of current/log.tsv, must be able to resume work.

## Four phases

1. Setup — interview, cartography, scaffold, copy agents
2. Prepare — bootstrap, verify integrations
3. Baseline — experiment 000; CONFIG and bootstrap are frozen
4. Loop — continuous dispatch and integration

Details — references/setup.md, references/interview.md, references/bootstrap-recipes.md.

## Coordination (phase 4)

Main does not idle if it can still delegate. While waiting for a return it prepares the next briefing.

Default concurrency (override in CONFIG):
- experimenter=1
- researcher=2

### Sub-agent delegation

Main dispatches with `run_in_background=True` and subscribes to the Agent-complete notification. When a sub-agent completes, main receives the notification and resumes by processing the sentinel in the response. If the notification does not arrive within the expected timeout — record as timeout, write an integrity event, reconstruct from TSV.

Delegates a specific task (e.g., "change SEQ_LEN from 512 to 1024" or "survey recent LLM optimizer trends"). Sub-agents have read access to the entire project and pull what they need — briefings contain only pointers and context the sub-agent wouldn't think to fetch itself. Write briefings as mini-specs (see Principle 3): long, explicit, with border cases and scope boundaries.

Sub-agent return: sentinel (`EXPERIMENT_DONE` / `RESEARCH_DONE`) + one header line (status, key number) + body ≤ token budget from CONFIG (what was found, surprises, obvious follow-up) + `refs:` line with paths and SHAs. Compactness rule (Principle 4): if removing the body would leave main making the same decisions, rewrite it with the real finding; main reads identifiers from the TSV anyway.

### Integration flow

The sub-agent has already done its part: appended a row to its sub-agents/.../log.tsv, updated its MEMORY.md, and on keep / invalid placed NNN-`<slug>`.md. Main closes the loop: verify → understand → record → dispatch next.

1. **Disk-check.** The last row of the relevant TSV starts with the claimed id; if status implies a note file — it exists. Mismatch → trust the TSV, record an integrity event in KNOWLEDGE.md, skip this integration step.
2. **Git.** On keep — ff-merge worktree, remove worktree, delete branch (on ff-only failure — see "Errors"). On discard / crash / timeout / invalid — cherry-pick commit B (record), `worktree remove --force`, `branch -D`.
3. **Thinking.** How does this result change the overall picture? What hypothesis does it surface or refute? Does it contradict anything already confirmed in KNOWLEDGE? This step is main's primary creative work; everything else is routine bookkeeping.
4. **current/log.tsv.** Append a row (action, target, outcome, delta, notes).
5. **current/MEMORY.md.** Update Status (best, active agents, flags, scheduler state), Queue, Recent.
6. **knowledge/.** On keep — process topic files and index (see "Keep: knowledge" below).
7. **Next briefing.** Form a task for researcher or experimenter and, if concurrency allows, dispatch (see "Sub-agent delegation" above). If capacity is full — place the briefing in Queue.

Main does not modify other agents' MEMORY.md or log.tsv. Write permissions: experimenter — sub-agents/experiments/ + CONFIG.scope; researcher — sub-agents/research/ + /tmp/research-`<id>`/. Unauthorized writes trigger `git checkout HEAD -- <path>`, an integrity event, and a template review.

### Keep: knowledge

- At ≥ 2 keep on a topic — create knowledge/<topic>.md (propositions + evidence appendix); if the file already exists — update it.
- In KNOWLEDGE.md move the entry: Watch list ↔ Confirmed ↔ Contested.
- Contradiction check: if KNOWLEDGE.md has an entry with overlapping scope and the opposite claim — mark both contested, add an analysis-researcher to the Queue. Source data is never deleted.

### invalid

Two invalid results in a row — raise the paused flag for experimenter in Status; researcher continues; add an analysis-researcher to the Queue to investigate the cause.

## Scheduler

Cadences live in CONFIG; state is shown in current/MEMORY.md Status.

```
exploration_every       how many keep-misses before exploration
analysis_every          how many experiments before analysis
consolidation_every     how many experiments before compression and topic promotion
coldstart_check_every   how often to verify cold-startability
```

## Errors

```
TSV ↔ report mismatch       trust TSV, integrity event, skip
two invalid in a row        pause experimenter, add analysis-researcher to Queue
ff-only conflict            abort, pause, notify user
unauthorized write          checkout HEAD, integrity event, agent under review
orphaned worktree           worktree remove --force + branch -D, reconstruct from TSV
```

## Stop

Only on user interrupt. Raise paused in Status, let active sub-agents finish, integrate returns, stop.
