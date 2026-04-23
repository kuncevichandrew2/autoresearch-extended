# CLAUDE.md — autoresearch-extended

This repository is the **source** of the `autoresearch` Claude Code skill. It is not a consumer project; it is what other projects install to turn their main Claude Code thread into an autonomous optimization coordinator. Editing here means editing the skill itself.

## Layout

```
.claude/skills/autoresearch/
├── SKILL.md                    # entry point — principles, phase map, per-project layout, routing
├── references/
│   ├── setup.md                # phases 1–3: collaborative setup, bootstrap, baseline
│   ├── loop.md                 # phase 4: the hot-path cycle narrative
│   └── file_structure.md             # file reference — per-file purpose, TSV schemas, frontmatter,
│                               #   hypothesis flow, task brief, compact report, verification
└── agents/
    ├── experimenter.md         # sub-agent system prompt — runs one experiment
    └── researcher.md           # sub-agent system prompt — runs one research task
```

`README.md` at the root is the user-facing install/run guide.

## Where to make changes

- Setup flow (interview, scaffold, bootstrap, baseline) → `references/setup.md`.
- Live loop (dispatch, integration, coordinator behaviour) → `references/loop.md`.
- A file's purpose or schema (CONFIG, ATLAS, LORE, backlog, TSVs, frontmatter) → `references/file_structure.md ## Files`.
- Sub-agent behaviour → the file under `agents/`.
- Cross-cutting conventions → `SKILL.md`, but verify you're not duplicating what file_structure.md already owns.

When you change a section header or file name, grep for cross-refs and update them: `grep -rn "<name>" .claude/skills/autoresearch/`.

## Editorial style

The product is prose quality. The user has repeatedly pushed back on length — prefer a tight paragraph over a sprawling bullet list.

- **Prose-first, not schema-first.** Loose human descriptions beat rigid YAML templates. Reserve structured formats for genuinely structured data (TSVs).
- **One-sentence purpose** per file/section block, then details.
- **Plain markdown.** Use `##` headings. No `§`. No HTML-comment sentinels like `<!-- section:X -->`.
- **Cross-reference, don't duplicate.** Schemas own their home in `file_structure.md`; everything else links (`see file_structure.md ## Files`).
- **Drop over-specification.** "Allocate the next zero-padded id" beats "`next NNN = (lines in experiments.tsv) - 1` zero-padded". Trust the reader.
- **Size rule** (applies to the skill's *runtime* files, not these source files): mutable `.md` stays under ~400 lines; compress when approaching the cap.

## Load-bearing concepts (don't collapse these)

These distinctions took iteration to reach — keep them.

- **ATLAS vs LORE.** ATLAS = latest state of the loop, decays. LORE = aggregation of *everything* the agent has learned, accretes. `## Dead ends` and `## Anti-cheat log` live in LORE, not ATLAS. LORE sections are a starting skeleton, not a closed schema — new sections (`## Domain context`, `## Heuristics`, `## Open questions`) are added freely.
- **Hypothesis flow.** Default path: backlog (`kind=hypothesis`) → researcher → experimenter. Rare direct skips are allowed judgement calls, not violations.
- **Experiments = ground truth, research = advisory.** Only a `keep` experiment promotes a claim to `LORE ## Established`.
- **Main never sits idle.** While sub-agents run in background, main keeps working: pruning backlog, compressing LORE, sharpening the next brief, spawning more sub-agents while capacity allows. Rule: *always be doing something useful.*
- **Agent templates are adapted *before* copying** into a consumer project's `.claude/agents/` — adapt to that project's task, eval flow, scope, and examples. The top frontmatter section and each agent's purpose stay unchanged.
- **`bootstrap.sh` OR `bootstrap.md`.** `.sh` for a single script; `.md` when setup needs multiple scripts or prose instructions (e.g., computer-use steps).

## Shipping

- Default branch: `main`. No staging branches, no CI, no release process.
- Commit style: `autoresearch: <what changed>` — short subject, 1–2 short paragraphs on *why*. Co-Authored-By footer.
- Never commit `.claude/settings.local.json` (local harness settings).
- Don't bundle unrelated edits — if the repo has unrelated dangling changes, leave them for a separate commit.
