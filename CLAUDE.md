# CLAUDE.md — autoresearch-extended

This repository is the **source** of the `autoresearch` Claude Code skill. It is not a consumer project; it is what other projects install to turn their main Claude Code thread into an autonomous optimization coordinator. Editing here means editing the skill itself.

## Layout

```
.claude/skills/autoresearch/
├── SKILL.md                    # entry point — principles, phase map, memory skeleton, coordination
├── references/
│   ├── setup.md                # phases 1–3: collaborative setup, bootstrap, baseline
│   ├── file-structures.md      # file reference — per-file purpose, TSV schemas, frontmatter, examples
│   ├── bootstrap-recipes.md    # bootstrap patterns and health-check recipes
│   └── interview.md            # interview question bank
├── agents/
│   ├── experimenter.md         # sub-agent system prompt — runs one experiment
│   └── researcher.md           # sub-agent system prompt — runs one research task
└── templates/
    └── autoresearch/           # scaffolded into the consumer project as autoresearch/
```

`README.md` at the root is the user-facing install/run guide.

## Where to make changes

- Setup flow (interview, scaffold, bootstrap, baseline) → `references/setup.md`.
- Live loop (dispatch, integration, coordinator behaviour) → `SKILL.md ## Coordination`.
- A file's purpose or schema (CONFIG, MEMORY, KNOWLEDGE, log.tsv, NNN-<slug>.md) → `references/file-structures.md`.
- Sub-agent behaviour → the file under `agents/`.
- Cross-cutting conventions → `SKILL.md`, but verify you're not duplicating what `references/file-structures.md` already owns.

When you change a section header or file name, grep for cross-refs and update them: `grep -rn "<name>" .claude/skills/autoresearch/`.

## Editorial style

The product is prose quality. The user has repeatedly pushed back on length — prefer a tight paragraph over a sprawling bullet list.

- **Prose-first, not schema-first.** Loose human descriptions beat rigid YAML templates. Reserve structured formats for genuinely structured data (TSVs).
- **One-sentence purpose** per file/section block, then details.
- **Plain markdown.** Use `##` headings. No `§`. No HTML-comment sentinels like `<!-- section:X -->`.
- **Cross-reference, don't duplicate.** Schemas own their home in `references/file-structures.md`; everything else links.
- **Drop over-specification.** "Allocate the next zero-padded id" beats "`next NNN = (lines in experiments.tsv) - 1` zero-padded". Trust the reader.
- **Size rule** (applies to the skill's *runtime* files, not these source files): mutable `.md` stays under ~400 lines; compress when approaching the cap.

## Load-bearing concepts (don't collapse these)

These distinctions took iteration to reach — keep them.

- **`current/` vs `knowledge/`.** `current/MEMORY.md` is the live dashboard — it decays under compression. `knowledge/` is accreted learning: `knowledge/<topic>.md` files accumulate only confirmed propositions (≥ 2 keep). `## Avoid` and `## Open questions` belong in `current/`; `knowledge/` contains only what experiments have confirmed.
- **Hypothesis flow.** Default path: Queue (in `current/MEMORY.md`) → researcher → experimenter. Direct dispatch without researcher is an allowed judgement call, not a violation.
- **Experiments = ground truth, research = advisory.** Only a `keep` experiment promotes a claim to `knowledge/<topic>.md ## Propositions`.
- **Main never sits idle.** While sub-agents run in background, main keeps working: sharpening the next brief, pruning Queue, compressing MEMORY, dispatching more work. Idle is only acceptable if capacity is full and Queue is empty.
- **Agent templates are adapted *before* copying** into a consumer project's `.claude/agents/` — adapt Mission and Common failure modes to that project's task and eval flow. Frontmatter, Workflow, and schemas stay unchanged.
- **`bootstrap.sh` OR `bootstrap.md`.** `.sh` for a single script; `.md` when setup needs multiple scripts or prose instructions (e.g., computer-use steps).

## Shipping

- Default branch: `main`. No staging branches, no CI, no release process.
- Commit style: `autoresearch: <what changed>` — short subject, 1–2 short paragraphs on *why*. Co-Authored-By footer.
- Never commit `.claude/settings.local.json` (local harness settings).
- Don't bundle unrelated edits — if the repo has unrelated dangling changes, leave them for a separate commit.
