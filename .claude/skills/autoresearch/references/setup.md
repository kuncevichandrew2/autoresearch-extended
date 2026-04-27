# Setup — phases 1–3

What main does before entering the loop. No files under autoresearch/ or in the project's agents directory are written until the interview is complete.

## Phase 1 — Setup

1. Repo cartography → CLAUDE.md at the root of the consumer project. Entry points, build, target files, eval flow. This is project context, not autoresearch-specific. Written or updated before the interview — it feeds the suggested options.
2. Interview. AskUserQuestion is mandatory — never silently infer load-bearing setup from the repo alone (target file, metric and direction, eval command, dataset variant, vocab/config sizes, integration scope). Each block presents your best guess from repo cartography as the default and invites correction; options are pre-drafted, user selects. If real ambiguity remains after a block — two plausible target files, a dataset choice that decides hours of bootstrap, a metric whose direction isn't obvious — ask another block before scaffolding, not after. See references/interview.md.
3. Scaffold (first writes under autoresearch/):
   a. Copy the skeleton: `cp -r <skill_root>/templates/autoresearch <project_root>/autoresearch`, where `<skill_root>` is the skill directory (e.g. `~/.claude/skills/autoresearch/`). After this, autoresearch/ is fully in place: log.tsv files with headers, MEMORY.md from templates, knowledge/KNOWLEDGE.md, stub CONFIG.md and bootstrap.sh.
   b. Copy agents: `cp <skill_root>/agents/experimenter.md <skill_root>/agents/researcher.md <project_root>/.claude/agents/` (or `.codex/agents/`, etc.). Adapt only Mission and Common failure modes to the project's task; frontmatter, Workflow, and schemas are not touched.
   - Fill CONFIG.md from interview answers (the only file edited after copying).
   - Seed Queue in current/MEMORY.md with 2–4 items from the interview.

## Phase 2 — Prepare

1. Write bootstrap.sh (or bootstrap.md if multiple scripts or manual steps are needed). Idempotent, artifacts in .gitignore. Tips: references/bootstrap-recipes.md.
2. Before downloading > 100 MB or writing to a shared system — confirm with the user.
3. Run to exit 0 and health-check every integration.
4. Record an integrity event in KNOWLEDGE.md: "<date> — integrations verified: <names>".

## Phase 3 — Baseline

1. Create worktree exp-000-baseline.
2. Dispatch experimenter with an empty change_plan, slug=baseline.
3. Experiment skips commit A (no edits), runs eval, writes row 000 to sub-agents/experiments/log.tsv and sub-agents/experiments/000-baseline.md, makes commit B.
4. Main fast-forwards into main, updates current/MEMORY.md Status (best = 000) and KNOWLEDGE.md Current best.
5. If metric=NaN — fix eval/parse/timeout, repeat. CONFIG remains editable until experiment 000 passes.
6. If CONFIG.md contains Custom TSV columns — append those columns to the header of sub-agents/experiments/log.tsv before the first commit B (experimenter expects them in the header).
7. After experiment 000 passes — CONFIG.md and bootstrap are frozen.
