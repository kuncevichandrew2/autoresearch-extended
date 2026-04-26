# Setup — фазы 1–3

Что делает main до перехода в loop. Никаких файлов под autoresearch/ или в каталоге агентов проекта не пишется до завершения интервью.

## Фаза 1 — Setup

1. Картография репо → CLAUDE.md в корне. Точки входа, build, целевые файлы, eval-флоу. Это контекст проекта, не autoresearch-специфика. Пишется или обновляется до интервью — он питает варианты ответов.
2. Интервью. Один блок AskUserQuestion — один вопрос. Опции пред-набрасываются из репо. См. references/interview.md.
3. Скаффолд (первые записи под autoresearch/):
   a. Скопировать каркас: `cp -r <skill_root>/templates/autoresearch <project_root>/autoresearch`, где `<skill_root>` — каталог skill (например, `~/.claude/skills/autoresearch/`). После этого в autoresearch/ уже есть: log.tsv-файлы с заголовками, MEMORY.md из шаблонов, knowledge/KNOWLEDGE.md, заглушки CONFIG.md и bootstrap.sh.
   b. Скопировать агентов: `cp <skill_root>/agents/experimenter.md <skill_root>/agents/researcher.md <project_root>/.claude/agents/` (или `.codex/agents/` и т.п.). Адаптируется только Mission и Common failure modes под задачу проекта; frontmatter, Workflow и схемы не трогаются.
   - Заполнить CONFIG.md из ответов интервью (это единственный файл, который правится после копирования).
   - Засеять Queue в current/MEMORY.md 2–4 пунктами из интервью.

## Фаза 2 — Prepare

1. Написать bootstrap.sh (или bootstrap.md, если нужен мульти-скрипт или ручные шаги). Идемпотентность, артефакты в .gitignore. Подсказки: references/bootstrap-recipes.md.
2. Перед загрузкой > 100 МБ или записью в общую систему — подтверждение у пользователя.
3. Прогнать до exit 0 и health-check каждой интеграции.
4. Записать integrity-событие в KNOWLEDGE.md: "<дата> — integrations verified: <names>".

## Фаза 3 — Baseline

1. Создать worktree exp-000-baseline.
2. Диспатчить experimenter с пустым change_plan, slug=baseline.
3. Эксперимент пропускает commit A (нет правок), гоняет eval, пишет строку 000 в sub-agents/experiments/log.tsv и sub-agents/experiments/000-baseline.md, делает commit B.
4. Main делает fast-forward в main, обновляет current/MEMORY.md Status (best = 000) и KNOWLEDGE.md Current best.
5. Если metric=NaN — править eval/parse/timeout, повторять. CONFIG остаётся редактируемым до прохода 000.
6. Если CONFIG.md содержит Custom TSV columns — дописать эти колонки в заголовок sub-agents/experiments/log.tsv до первого commit B (experimenter ожидает их уже в заголовке).
7. После прохода 000 — CONFIG.md и bootstrap замораживаются.
