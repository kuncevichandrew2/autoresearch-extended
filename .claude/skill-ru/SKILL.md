---
name: autoresearch
description: Автономный цикл оптимизации для любого репозитория с одной скалярной метрикой. Срабатывает на "запусти autoresearch", "старт цикла экспериментов", "оптимизируй X по метрике Y", "снизь loss / latency / bundle size", "подними pass rate", или при указании целевого файла + метрики. После одноразовой настройки главный тред — event-driven координатор, который диспатчит два фоновых суб-агента: `experimenter` (правит target files, запускает eval, записывает) и `researcher` (анализирует источники, предлагает гипотезы). Работает для любой метрики, сводимой к одному числу (например, shell-команде, печатающей одно парсящееся число).
---

# autoresearch — автономный цикл оптимизации

Skill `autoresearch` превращает репозиторий с одной целевой метрикой в автономный оптимизационный цикл. Вы задаёте файл(ы), которые можно править, и команду, печатающую одно число (val_loss, p99_ms, bundle_kb, pass_at_k, judge_score и т. п.) — дальше главный тред Claude Code диспатчит фоновые суб-агенты, они пробуют гипотезы, меряют, фиксируют результат, и цикл продолжается до прерывания.

---

## 1. Архитектура и инварианты

### Главный тред и два суб-агента

Главный тред (main) — event-driven координатор. Он не запускает eval сам. Он:

1. Создаёт git worktree для следующего эксперимента.
2. Вызывает `Agent(subagent_type=..., run_in_background=true, prompt=<brief>)` с самодостаточным брифом.
3. Ждёт Agent-complete уведомлений.
4. Читает compact-отчёт, делает sanity-check на диске, интегрирует результат в ATLAS.md, FACTS.md, LEADS.md, backlog.tsv, knowledge/. Свой анализ при необходимости ведёт в workbench/.
5. Диспатчит следующую задачу.

Суб-агенты:

- **experimenter** — выполняет ровно один эксперимент end-to-end. Применяет change_plan, прогоняет eval, парсит метрику, пишет в TSV и заметку, делает два коммита, возвращает короткий отчёт.
- **researcher** — выполняет ровно одну research-задачу. Читает источники, анализирует прошлые эксперименты, предлагает численно-фальсифицируемые гипотезы для backlog.

### Главный инвариант

Только когда эксперимент возвращается со `status=keep`, знание считается подтверждённым — main добавляет его в FACTS.md (и удаляет соответствующий предварительный bullet из LEADS.md). Исследование рекомендательно, эксперимент — ground truth.

Идея flow: main выдвигает гипотезу → researcher → experimenter → FACTS.md + knowledge/. Стрелки здесь концептуальные — между ними скрыты backlog-записи и интеграционные шаги, но направление передачи знания именно такое.

### Принципы

1. **Бинарный keep/discard по одной скалярной метрике.** Keep, если бьёт текущий best в заданном направлении (min или max). Иначе откат.
2. **Замороженный контракт.** CONFIG.md, команда eval и bootstrap неизменны после того, как baseline (эксперимент 000) распарсился. Любое изменение требует re-setup.
3. **Эксперименты — истина, исследование — совет.**
4. **Изолированные суб-агенты.** У каждого суб-агента одна директория для записи: researcher пишет только в research/, experimenter — в experiments/ и в target-файлах внутри CONFIG.scope; main пишет везде, кроме этих двух областей. Чтение — универсально. Брифы самодостаточны; суб-агенты никогда не ходят по autoresearch/.
5. **Изоляция worktree.** Каждый эксперимент живёт в своём git worktree на ветке `exp/NNN-<slug>`. На keep — fast-forward merge. На остальное — cherry-pick только record-коммита, без кода.
6. **Хирургические правки.** Каждая изменённая строка трассируется к гипотезе. Никакого попутного клининга.
7. **Автономно до остановки.** После сетапа main никогда не спрашивает "продолжить?".

---

## 2. Четыре фазы

1. **Setup** — создаёт CLAUDE.md, CONFIG.md, дерево, устанавливает обоих агентов. Gate: CONFIG валиден, дерево создано.
2. **Prepare** — создаёт bootstrap.sh или bootstrap.md, верифицирует интеграции. Gate: bootstrap exit 0, все интеграции green.
3. **Baseline** — строка `000` в experiments.tsv, инициализация ATLAS. Gate: row 000 парсится, CONFIG и bootstrap замораживаются.
4. **Loop** — бесконечный dispatch/integrate. Выход по прерыванию пользователя.

### Фаза 1 — Setup (совместно с пользователем)

**Шаг 1. Картография репозитория → CLAUDE.md.** Исследуй entry points, билд, target-файлы, eval-флоу. Напиши CLAUDE.md в корне репо со всей архитектурой и контекстом, который ты понял.

**Шаг 2. Интервью через блоки AskUserQuestion.** Один вызов на блок; заранее набросай опции из репо, затем задавай.

- **A · Цель, метрика, направление.** Target-файл(ы) · метрика · min/max · политика seed (`fixed:N` / `sampled:K-runs` / `none`).
- **B · Предложи варианты метрик.** Каталог: val_loss, pass_at_k, f1_macro, auroc, judge_score, latency_p99_ms, bundle_kb, hbm_peak_gb и т. д. (не закрытый список).
- **C · Eval-флоу.** Команда · парсинг (`regex:…` / `json_path:…` / `exit_code`) · таймаут · любые кастомные TSV-колонки.
- **D · Контекст исследования.** Домен · известные потолки / SOTA · prior art · ограничения.
- **E · Интеграции.** Грепни W&B, MLflow, Docker, LLM-судьи. Один вызов AskUserQuestion с одним под-вопросом на каждую обнаруженную интеграцию (максимум 4): scope + env vars + команда health.

**Шаг 3. Scaffold.** Построй дерево под autoresearch/ (см. раздел 3). Напиши CONFIG.md из ответов Шага 2. Создай TSV только с заголовками. Напиши FACTS.md и LEADS.md с пустыми секциями. Засей backlog 2–4 строками `hypothesis/pending` + 1–3 `deferred/pending`. Скопируй шаблоны агентов — `examples/agent-experimenter.md` и `examples/agent-researcher.md` из этого скила — в `.claude/agents/` проекта под именами `experimenter.md` и `researcher.md`; при необходимости адаптируй только секции Mission и Common failure modes под домен. Не трогай frontmatter, секцию Protocol и схемы.

### Фаза 2 — Prepare

Напиши bootstrap.sh (или bootstrap.md, когда нужно несколько скриптов, computer-use или ручная аутентификация) — идемпотентный, повторно-запускаемый, артефакты в .gitignore. Перед любым скачиванием >100 МБ или записью в общую систему — подтверждение у пользователя. Запусти до exit 0, запусти health-check каждой интеграции, запиши `YYYY-MM-DD — integrations verified: <names>` в секцию Decisions файла FACTS.md.

### Фаза 3 — Baseline

Диспатчь experimenter против немодифицированного target. Бриф: эксперимент 000, slug `baseline`, без гипотезы, без change plan; worktree `../autoresearch-wt/exp-000-baseline`, ветка `exp/000-baseline` от HEAD; eval / parse / timeout / direction / seed policy / custom columns из CONFIG; current best = NaN. Главный создаёт worktree перед dispatch. Experimenter пропускает commit A (нет change plan → нет правки), запускает eval, пишет row 000 и `000-baseline.md`, делает commit B `"exp 000: baseline"`. Главный fast-forward'ит в main.

Инициализируй ATLAS.md (секция Now) с `000` как best; prepend `000` в Recent signal.

Если метрика NaN — итерируй по `eval_command` / `parse_method` / `timeout_sec`. CONFIG остаётся редактируемым до тех пор, пока row 000 не распарсится. Как только распарсился — CONFIG и bootstrap замораживаются, любое дальнейшее изменение требует re-setup.

### Фаза 4 — Loop

После baseline главный становится event-driven координатором. Описан в разделе 4.

---

## 3. Структура файлов

### Дерево директорий

```
autoresearch/
├── CONFIG.md                       # заморожен после baseline
├── bootstrap.sh OR bootstrap.md    # заморожен после baseline
│
├── ATLAS.md                        # main — живой дашборд
├── FACTS.md                        # main — подтверждённое знание из экспериментов
├── LEADS.md                        # main — зацепки и предположения из research
├── backlog.tsv                     # main — очередь работы
├── knowledge/
│   ├── README.md
│   └── <topic>.md                  # emergent; только когда заслужено
│
├── experiments/
│   ├── README.md
│   ├── experiments.tsv
│   └── NNN-<slug>.md               # только при status ∈ {keep, invalid}
│
├── research/
│   ├── README.md
│   ├── research.tsv
│   └── NNN-<slug>.md               # одна на сессию
│
└── workbench/                      # main scratchpad
    ├── README.md
    └── *
```

**Правило размера.** Каждый mutable .md держится под ~400 строк (одно окно Read). При приближении к лимиту главный сжимает: обрезает старые ATLAS-bullets, схлопывает устаревшие записи FACTS/LEADS в однострочники, продвигает повторяющуюся тему в `knowledge/<topic>.md`. Write-once заметки исключены.

### CONFIG.md — замороженный контракт

```markdown
# CONFIG

goal:            <одна строка: что оптимизируем и зачем>
metric:          val_loss
direction:       min                           # min | max
eval_command:    bash scripts/eval.sh
parse_method:    regex:^val_loss=([0-9.]+)$    # regex:… | json_path:… | exit_code
timeout_sec:     1800
scope:                                         # globs, которые experimenter может править
  - src/model/**
  - configs/train.yaml
seed_policy:     fixed:42                      # fixed:N | sampled:N-runs | none
reflect_every:   10                            # число экспериментов между reflect-триггерами
max_parallel_experimenters: 1
max_parallel_researchers:   2
custom_tsv_columns:                            # добавляются в experiments.tsv в порядке
  - train_loss
  - wall_time_s

## Context
<3-6 bullets: форма репо, target, как выглядит хороший прогон>

## Constraints
<жёсткие правила: held-out данные, лицензии, детерминизм, wall-clock потолки>

## Integrations
<на каждую интеграцию: имя, env vars, команда health>
```

### bootstrap.sh или bootstrap.md

Идемпотентная инициализация окружения. .sh для одного скрипта; .md — когда нужно несколько скриптов или проза. Замораживается вместе с CONFIG.

### ATLAS.md — живой дашборд

Перезаписывается при каждой интеграции. Ничего load-bearing: здесь только снимок.

- **Now** — текущий best (метрика, exp id, commit), работающие суб-агенты, флаги `paused` / `recommend_resetup`.
- **Recent signal** — кольцевой буфер 5 последних интеграционных событий.
- **Hot topics** — 2–4 топ-тега по активности из backlog + последних 10 экспериментов.

### FACTS.md — подтверждённое знание

Всё, что прошло через `keep`-эксперимент или имеет интеграционное значение. Аккумулируется, не перемешивается. Стартовые секции (setup пишет их пустыми):

- **Established** — утверждения, продвинутые `keep`-экспериментом. Каждое цитирует `exp/NNN`.
- **Dead ends** — повторно проваливающиеся подходы; append-only, dedup по подстроке.
- **Decisions** — однострочный changelog: интеграции, паузы, policy-выборы.
- **Anti-cheat log** — рассинхрон TSV/report, foreign writes, события целостности.

Main свободно добавляет секции, если нужно (например, Invariants, Calibrations).

### LEADS.md — зацепки и предположения

Всё, что исходит из research: литература, дайджесты, предварительные паттерны. Накапливается и перерабатывается — утверждение уходит отсюда, как только его продвинул `keep`. Стартовые секции:

- **Emerging** — предварительные утверждения из research, ждут подтверждения экспериментом.
- **Domain context** — фоновые знания о поле: SOTA, ограничения, типовые подходы.
- **Open questions** — вопросы, которые всплыли, но пока не превратились в гипотезу.
- **Heuristics** — спекулятивные паттерны ("кажется, X коррелирует с Y"), не ground truth.

> **ATLAS vs FACTS vs LEADS.** ATLAS = текущее состояние цикла, затухает. FACTS = что мы доказали экспериментом, накапливается. LEADS = что мы прочитали и заподозрили, перерабатывается по мере подтверждения или опровержения.

### backlog.tsv — очередь работы

Append-only, 9 tab-separated колонок. Main мутирует строки in-place по id через атомарную перезапись (read → edit → temp → rename).

```
id	kind	status	claim	source	created	consumed_by	outcome	notes
H-019	hypothesis	pending	apply Muon to 2D params	research/008-muon-digest.md#H-019	2026-04-20	-	-	top of queue
H-017	hypothesis	consumed	cosine warmup 10% beats linear	research/007-warmup-sweep.md#H-017	2026-04-15	exp/042	keep	-0.012 val_bpb
D-002	deferred	pending	digest arxiv:2501.15105	-	2026-04-17	-	-	-
T-002	tooling	pending	ATLAS recent-signal regen script	-	2026-04-19	-	-	-
```

- kind ∈ {hypothesis, question, deferred, tooling}
- status ∈ {pending, blocked, running, consumed, done, dropped}
- Колонки 1, 2, 4, 5, 6 неизменны после append; 3, 7, 8, 9 мутабельны.

### experiments/experiments.tsv — судовой журнал

8 фиксированных колонок + любые `custom_tsv_columns` из CONFIG в порядке.

```
id	status	metric	delta	hypothesis	commit	timestamp	note
000	keep	3.074	0	-	a0b1c2d	2026-04-10T08:00Z	experiments/000-baseline.md
042	keep	3.041	-0.012	H-017	a1b2c3d	2026-04-22T12:30Z	experiments/042-warmup-cosine.md
043	discard	3.089	+0.048	-	e4f5g6h	2026-04-22T13:05Z	-
```

- status ∈ {keep, discard, crash, timeout, invalid}
- metric = NaN при crash / timeout / нераспарсенном
- commit — 7-char SHA record-коммита (commit B), не коммита с изменениями кода
- delta: отрицательное улучшает при direction=min; положительное — при direction=max

### experiments/NNN-<slug>.md — запись эксперимента

Write-once. Создаётся только при status ∈ {keep, invalid}.

```yaml
---
id: 042
slug: warmup-cosine
kind: experiment
date: 2026-04-22T12:30:00Z
status: keep
parent: 014
source_hypothesis: H-017
commit: a1b2c3d
metric: 3.041
delta: -0.012
---

## Hypothesis
<один абзац>

## Changes
<bullets: file:line — зачем>

## Result
<метрика, delta, проверка направления, wall time, сюрпризы>

## Log excerpt
<последние ~20 сигнальных строк>

## Notes
<оговорки, связанные FACTS/LEADS-bullets>
```

### research/research.tsv

5 tab-separated колонок, одна строка на завершённую сессию.

```
id	type	date	report	one_line
R-008	digest	2026-04-20	research/008-muon-digest.md	Muon optimizer; H-019, H-020
R-009	reflect	2026-04-22	research/009-reflect-cycle-42.md	reflect after 10 exps; H-021 added
```

type ∈ {digest, sweep, eda, broader-tooling, reflect}.

### research/NNN-<slug>.md — дайджест сессии

Write-once. Frontmatter: id, slug, type, date, trigger, hypotheses_produced.

```yaml
---
id: R-008
slug: muon-digest
type: digest
date: 2026-04-20
trigger: D-001 (digest arxiv:2502.16982)
hypotheses_produced: [H-019, H-020]
---

## Context
## Findings
## Hypotheses produced

### H-019: <однострочник>
- **Claim:** …
- **Rationale:** … (цитирует arxiv:2502.16982 §4)
- **Method:** edit configs/train.yaml и src/optim/build.py:42
- **Predicted Δmetric:** -0.01 до -0.03 val_bpb
- **Risks:** …
- **Falsifier:** improvement < 0.5% after 3 lr-scaled runs

## Recommendations        # только для type=reflect
## Notes
```

### knowledge/<topic>.md

Создаётся только когда тема накопила ≥2 `keep`-эксперимента или reflect её продвинул. Проверенные факты, точные данные, load-bearing эвристики. Не перемешивается.

### Алфавит ID

NNN — эксперимент · R-NNN — research · H-NNN, Q-NNN, D-NNN, T-NNN — backlog. Zero-padded три цифры. Монотонные. Никогда не переиспользуются.

### Поток гипотез

По умолчанию: backlog (kind=hypothesis) → researcher → experimenter. Острая, обоснованная идея может пропустить researcher; размытая может зациклиться обратно на researcher. Отклонения — решения по суждению, не нарушения.

---

## 4. Hot loop — Фаза 4

### Dispatch

Главный вызывает `Agent(subagent_type=..., run_in_background=true, prompt=<brief>)`. Брифы — проза, самодостаточны.

Concurrency (переопределяется через CONFIG):

- ≤ 1 experimenter (тяжёлые GPU/disk evals сериализуются).
- ≤ 2 researcher (дёшево, I/O-bound).

Перед диспатчем experimenter главный создаёт worktree:

```sh
git worktree add ../autoresearch-wt/exp-NNN-<slug> -b exp/NNN-<slug> <parent_commit>
```

worktree_path и branch идут в брифе. Суб-агент `cd`'ится внутрь и работает там.

Возвраты приходят как Agent-complete уведомления. Main читает compact report, делает disk-check (см. раздел Verification), интегрирует.

### Интеграция по типу возврата

**Experiment keep:**

```sh
git merge --ff-only exp/NNN-<slug>
git worktree remove ../autoresearch-wt/exp-NNN-<slug>
git branch -d exp/NNN-<slug>
```

Затем: продвинь соответствующий bullet из LEADS.md (Emerging) в FACTS.md (Established), цитируя `exp/NNN`. Пометь backlog-строку `consumed/keep`. Обнови ATLAS Now новым best; prepend в Recent signal.

**discard / crash / timeout:** изменение кода *не должно* попасть в main; только record-коммит.

```sh
git cherry-pick <record_commit>              # commit B трогает только autoresearch/experiments/*
git worktree remove ../autoresearch-wt/exp-NNN-<slug>
git branch -D exp/NNN-<slug>
```

Закрой backlog-строку с `outcome=<status>`; отметь попытку в ATLAS Recent signal. Повторяющийся паттерн провалов → запись в FACTS.md Dead ends.

**invalid** (нарушение scope, нужен прекурсор, eval выглядит сломанным): cherry-pick record-коммита, если он есть, иначе просто дропни worktree. Закрой backlog `outcome=invalid`. Два подряд invalid → выставь `recommend_resetup=true` в ATLAS Now, приостанови диспатч experimenter (researcher продолжают).

**Research digest / sweep / eda / broader-tooling:** добавь предложенные гипотезы как pending H-NNN строки в backlog.tsv; добавь поддержанные утверждения в LEADS.md (Emerging или Domain context).

**Research reflect:** применяй секцию Recommendations отчёта к FACTS.md / LEADS.md / backlog.tsv механически.

### Между возвратами main никогда не простаивает

Главный однопоточный — он не думает параллельно. Но между dispatch и возвратом он может:

- сформировать и задиспатчить следующий бриф (до лимита concurrency)
- запустить verification на последнем возврате
- сжать ATLAS / FACTS / LEADS, когда mutable .md приближается к ~400 строк
- переупорядочить или урезать backlog.tsv

Простаивать нормально, если ничего не подходит. Главный просыпается на следующем Agent-complete.

### Остановка

Только по прерыванию пользователя: запиши `paused` в ATLAS Now, дай работающим суб-агентам завершиться, интегрируй их возвраты, остановись.

### Когда что-то идёт не так

Логируй, восстанавливайся, продолжай. Эскалируй только когда цикл не может продвигаться.

- **Несоответствие TSV / report** → доверяй TSV, логируй в FACTS.md Anti-cheat log, пропускай этот возврат.
- **Два подряд invalid** → `recommend_resetup=true`, приостанови диспатч experimenter.
- **Конфликт --ff-only** (не должен случаться при concurrency=1) → abort, пауза, уведомление пользователю.
- **Суб-агент записал вне своей директории** → `git checkout HEAD -- <path>`, логируй в FACTS.md Anti-cheat log, помечай шаблон агента на ревью.
- **Orphan worktree после упавшей интеграции** → `git worktree remove --force` + `git branch -D`, реконструируй состояние из TSV.

---

## 5. Контракты между main и суб-агентами

### Task brief (main → суб-агент)

Проза. Самодостаточно — суб-агент никогда не дозапрашивает контекст. Пиши как короткое сообщение коллеге: скажи, что нужно сделать, и дай конкретные факты, которые суб-агент не может угадать. Включай деталь только если без неё суб-агент гадал бы.

#### Бриф experimenter

Должно быть: гипотеза (одно-два предложения с предсказанным направлением и численным фальсификатором); план изменений, достаточно конкретный, чтобы применить (пути файлов с номерами строк где важно, точные значения); worktree path, имя ветки, parent commit; scope (подмножество CONFIG.scope); eval command, parse, timeout; direction и текущий best; seed policy; пути для TSV-строки и заметки; любые `custom_tsv_columns` в порядке.

Пример:

```
Run experiment 042 — slug warmup-cosine — в worktree
../autoresearch-wt/exp-042-warmup-cosine на ветке exp/042-warmup-cosine
(ответвляется от commit 9f8e7d6, где приземлился exp 014).

Гипотеза (H-017): cosine warmup 10% бьёт текущий linear-2%.
Ожидаемое улучшение val_loss ≥ 0.005. Falsifier: drop если ΔVal_loss > -0.005
после 3 lr-scaled runs.

Change plan:
- configs/train.yaml — set schedule: cosine, warmup_ratio: 0.1
- src/optim/build.py:42 — заменить LinearLR(...) на CosineAnnealingLR(T_max=total_steps)

Scope: configs/train.yaml, src/optim/build.py.
Eval: bash scripts/eval.sh, парсинг ^val_loss=([0-9.]+)$, timeout 1800s.
Direction: min. Current best: 3.053 (exp 014). Seed: fixed 42.
Custom TSV columns: train_loss, wall_time_s.

Записать в autoresearch/experiments/experiments.tsv и, на keep/invalid,
заметку в autoresearch/experiments/042-warmup-cosine.md.
```

#### Бриф researcher

Односложная задача; type (digest / sweep / eda / broader-tooling / reflect); trigger (id из backlog или prompt); research id и slug. Inline контекст, экономящий перечитывание: недавние релевантные эксперименты, конкретные bullets из FACTS/LEADS, URL / arxiv ids / пути файлов. Для reflect: inline последние N экспериментов и релевантный срез FACTS/LEADS. Пути для TSV-строки и отчёта.

Пример:

```
Research task R-008 (digest), slug muon-digest. Trigger: backlog row D-001.

Digest arxiv:2502.16982 (оптимизатор Muon). Извлеки load-bearing утверждения про
структуру второго порядка на 2D-параметрах, переведи в 1–3 гипотезы под
наш val_loss. Каждая гипотеза требует численного фальсификатора.

Context:
- Recent experiments: exp 041 discard (SOAP on 2D params, +0.008 val_loss);
  exp 038 keep (mu-parametrisation, -0.011).
- Relevant FACTS: "2D optimisers interact with warmup schedule" (exp/038).

Write report to autoresearch/research/008-muon-digest.md; append row to
autoresearch/research/research.tsv.
```

### Compact report (суб-агент → main): сначала инсайты, метаданные в конце

Это ключевой момент. Суб-агент потратил compute и контекст, чтобы что-то узнать. **Задача отчёта — сказать main, что было узнано**, а не перечислять ID, которые main и так знает. Полезный отчёт читается как коллега, рассказывающий *интересную вещь, которую он нашёл*, а не как квитанция.

Формат:

1. Первая строка — sentinel: EXPERIMENT_DONE или RESEARCH_DONE.
2. Вторая строка — одно предложение со статусом и ключевым числом.
3. Тело — содержательная находка: что эксперимент реально показал, что литература говорит, что означают числа.
4. Последняя строка — refs: с путями и commit SHA. Всё остальное main читает из TSV.

**Правило.** Если удаление тела не изменит ни одного решения main — перепиши тело с реальной находкой.

#### Experimenter — успешный keep:

```
EXPERIMENT_DONE
042 warmup-cosine: keep. val_loss 3.041 (-0.012 vs best), H-017.

Cosine warmup 10% обходит linear-2% по всем измеренным осям: итоговый
val_loss ниже на -0.012, train_loss идёт чище через первые 2k шагов (нет
mid-warmup спайка на шаге 800, который показывает linear), wall time тот же.
Улучшение полностью содержится в первых 3k шагах — графики сходятся с
шага 5k — что означает: выигрыш про *раннюю* форму lr, не асимптотическую.
Falsifier был Δ < -0.005 после 3 lr-scaled runs; мы попали на -0.012 на
первом seed. Стоит протестить warmup_ratio ∈ {5%, 15%}.

refs: commit a1b2c3d · note experiments/042-warmup-cosine.md
```

#### Experimenter — crash, который main должен увидеть:

```
EXPERIMENT_DONE
043 muon-2d-params: crash. OOM на шаге 12000 на единственной попытке, H-019.

Muon на 2D-параметрах не такой дешёвый, как подразумевает статья — пиковый
HBM дошёл до 78 GB, прежде чем аллокатор упал внутри CosineAnnealingLR.step().
Буфер второго момента оптимизатора только для 2D-тензоров — ~22 GB при
d_model=2048, и он складывается со стейтом activation-checkpointing вместо
оверлапа. H-019 в текущем виде непроверяема на этой машине без прекурсорного
изменения — либо checkpoint каждого слоя (потеря pipeline-выигрыша из exp/038),
либо шардинг Muon-state. Не переставляй H-019 в очередь, пока это решение
не принято.

refs: commit e4f5g6h · no note written
```

#### Researcher:

```
RESEARCH_DONE
R-008 muon-digest: done, две гипотезы в очереди (H-019, H-020).

Основное утверждение Muon — что шаг ортогонализации Newton-Schulz (arxiv
:2502.16982 §3.2) несёт улучшение, а не оценка второго момента — абляция
в §4.1 показывает, что почти весь выигрыш выживает при подмене второго
момента AdamW. Это переформулирует гипотезу для нашего кода: дешёвый
выигрыш — добавить ортогонализацию поверх AdamW 2D-параметров (H-019),
а не заменять AdamW целиком. H-020 — дорогой-но-острый вариант — полный
Muon только на 2D-параметрах — с фальсификатором в 200 шагов против exp/014.
Вторичная блог-агрегация в §3 утверждает, что Muon помогает MoE-routing;
я не смог отследить первичный источник и пометил speculative.

refs: report research/008-muon-digest.md
```

### Verification

После чтения возврата main делает дешёвый disk check:

1. `tail -1 <referenced_tsv>` начинается с заявленного id.
2. Если status подразумевает существование note — проверить файл на диске.
3. При несоответствии: доверять TSV, добавить в FACTS.md Anti-cheat log:
   `YYYY-MM-DD — <id> report/tsv mismatch, trusting TSV`
   Пропустить интеграцию этого возврата.

Это не gate протокольного соответствия, а sanity check.

### Re-setup

Триггер — когда CONFIG, bootstrap или eval должны измениться после baseline. Это крайняя мера. Большинство изменений, которые ощущаются как re-setup, на самом деле повод завести question в backlog.

1. Остановить цикл (прерывание пользователя).
2. Почистить orphan worktrees и ветки: `git worktree list` → `git worktree remove --force` всех `autoresearch-wt/*`; `git branch -D exp/*`.
3. Архив: `git mv autoresearch autoresearch.archive-<date>`.
4. Перезапустить Фазы 1–3.
5. Вручную портировать релевантные bullets из старых FACTS.md и LEADS.md в новые файлы. История experiments.tsv **не** переносится — baseline'ы разные.

---

## 6. Протокол experimenter

### Идентичность и миссия

Дисциплинированный senior-инженер. Возьми конкретную гипотезу, сделай минимальную хирургическую правку, запусти eval, запиши число, вернись. **Твоя записанная скалярная — ground truth** — число должно быть честным, воспроизводимым, однозначным.

Ровно один эксперимент. Бриф самодостаточен; не ходи по autoresearch/, не читай прошлые заметки, не ищи в интернете.

### Операционные принципы

1. **Хирургические правки.** Каждая изменённая строка трассируется к гипотезе. Никакого попутного клининга.
2. **Минимальный diff, совпадающий стиль.** Следуй существующему форматированию, именованию, импортам.
3. **Одна переменная.** Если нужен прекурсорный рефакторинг, верни status=invalid — не делай его сам.
4. **Честность ground-truth.** Репортируй измеренное число. Crash / timeout / NaN / не доверяешь → запиши ровно это со статусом и причиной. **Никогда не фабрикуй, не перезапускай молча до лучшего числа, не крути флаги, чтобы eval стал счастливее. Retry-to-success — это отмывание ground truth.**
5. **Eval и CONFIG заморожены.** Если eval выглядит сломанным, верни invalid с наблюдением.
6. **Два коммита на успешном пути.** A (code change), B (TSV + note). При invalid до commit A: ноль коммитов; `git checkout -- . && git clean -fd`; возврат.
7. **Дисциплина seed.** fixed:N — поставить этот seed. sampled:K-runs — прогнать K seed'ов, записать медиану, если бриф не говорит иначе. none — никакой фиксированный seed.
8. **Строгое владение записью.** Только autoresearch/experiments/ и файлы внутри scope.

### Протокол (12 шагов)

Бриф даёт тебе предсозданный worktree на ветке `exp/NNN-<slug>` с parent_commit на checkout. Все git-команды выполняются внутри worktree_path.

**1. Прочитай бриф.** Вытащи: id + slug, гипотезу (с предсказанным направлением и численным фальсификатором), change plan, worktree path + branch + parent commit, scope, eval + parse + timeout, direction + current best, seed policy, кастомные TSV-колонки, пути TSV и заметки. Если что-то нужное отсутствует и нельзя угадать — верни invalid и скажи, чего не хватает.

**2. Войди в worktree.**

```sh
cd <worktree_path>
git status                           # ожидается: on branch exp/NNN-<slug>, clean
```

Не clean или неверная ветка → invalid.

**3. Применить change_plan.** Минимальный diff, одна переменная, совпадающий стиль. Ничего вне scope. **Исключение для baseline:** когда бриф декларирует отсутствие change plan, пропусти этот шаг и шаг 5 — baseline измеряет немодифицированный код.

**4. Scope check.**

```sh
git diff --name-only
```

Изменённые пути — подмножество scope. При нарушении:

```sh
git checkout -- . && git clean -fd
```

Возврат invalid (ноль коммитов).

**5. Commit A (attempt).**

```sh
git add <scope files>
git commit -m "exp NNN: <slug>"
```

Пропусти для baseline.

**6. Запуск eval с таймаутом.**

```sh
timeout <timeout_sec> <eval_command> > /tmp/run-NNN.log 2>&1
EVAL_EXIT=$?
```

**7. Парсинг метрики.**

- regex:\<pattern\> → первая capture group
- json_path:\<path\> → dot-path в JSON stdout
- exit_code → сам exit code

Правила:
- Ошибка парсинга или EVAL_EXIT != 0 (кроме parse_method=exit_code) → crash, metric=NaN.
- EVAL_EXIT=124 → timeout, metric=NaN.
- Иначе вычисли `delta = metric - current_best`.

**8. Решить статус.** keep, если метрика валидна **и** улучшает против current_best. Иначе discard / crash / timeout.

**9. Написать заметку (только при keep / invalid).** Frontmatter + короткое тело. Никакой заметки при discard / crash / timeout.

**10. Append в experiments.tsv.** 8 фиксированных колонок + custom_tsv_columns в порядке. Оставь колонку commit пустой — заполнишь в шаге 11.

**11. Commit B (record), затем заполни SHA.**

```sh
git add <tsv + note если написана>
git commit -m "exp NNN: record"
RECORD_COMMIT=$(git rev-parse --short HEAD)
```

Теперь отредактируй TSV-строку и frontmatter заметки, чтобы вписать RECORD_COMMIT в поле commit, затем `git add` и `git commit --amend --no-edit`. Amend переписывает SHA B, так что перехвати заново:

```sh
RECORD_COMMIT=$(git rev-parse --short HEAD)
```

Sanity: новый SHA должен совпадать с тем, что сейчас записан в TSV.

**12. Вернуть compact report.** Формат — см. раздел 5.

### Планка качества experimenter

- Diff совпадает с гипотезой, ничего больше.
- Число надёжно — никаких молчаливых перезапусков, best-of-N, крутилок флагов.
- Запись полна — TSV-строка + (если применимо) заметка + два коммита.
- При status != keep отчёт конкретно говорит *почему* — достаточно, чтобы проинформировать следующий dispatch.

### Распространённые режимы отказа

- **Scope creep** (чистить соседний код) — откатить всё, что не несёт гипотезу.
- **Retry-to-success** — один честный прогон, одна честная запись.
- **Игры с кэшем eval.**
- **Held-out leak** → invalid.
- **Молчаливое продление timeout.**
- **Раздувание заметки** — она короткая, не эссе.

### Запрещено

Что-либо вне scope ∪ autoresearch/experiments/\*, мутация eval-пути, retry-to-success, shortcuts по кэшу, чтение held-out данных, навигация по ATLAS.md / FACTS.md / LEADS.md / backlog.tsv / research/. При любом запрещённом действии: `git checkout -- . && git clean -fd`, возврат invalid.

---

## 7. Протокол researcher

### Идентичность и миссия

Сильный PhD-уровня research-коллаборатор. Читай литературу, вытягивай сигнал из прошлых экспериментов, запускай исследовательский анализ, предлагай следующую гипотезу. Ты не решаешь, что шипится — только keep/discard experimenter продвигает утверждение. Твоя работа — сделать эти эксперименты точно нацеленными.

Ровно одна задача. Бриф самодостаточен.

### Типы задач

- **digest** — один источник, глубокое чтение. Суммаризируй, извлеки load-bearing утверждения, переведи в гипотезы.
- **sweep** — 3–5 целевых запросов, синтез. Первичные источники предпочтительнее блог-агрегации.
- **eda** — короткие скрипты в /tmp/research-<id>/ (вне репо). ≤ 60 с, без GPU, без сети за пределами URL из брифа. Графики — только когда картинка проясняет то, что проза не может.
- **broader-tooling** — оцени библиотеки или инструменты *вне* пути вычисления метрики. Репортируй зрелость, цену интеграции, режимы отказа. Никогда не модифицируй eval.
- **reflect** — проанализируй inline_context.recent_experiments и inline_context.relevant_facts_leads. Определи исчерпанные оси, возникающие паттерны, тупики. Предложи гипотезы **и** секцию Recommendations, которую main применит механически.

### Операционные принципы

1. **Фальсификация бьёт подтверждение.** Каждая гипотеза несёт конкретный **численный фальсификатор** по метрике проекта. *"Improvement < 0.5% after 3 lr-scaled runs"* — фальсификатор. *"Ожидаем улучшение"* — нет.
2. **Широко перед узким.** Начни широко, потом сужай. Одиночный узкий запрос тратит вызовы.
3. **Думай между вызовами инструментов.** После каждого результата: *это подтверждает, опровергает или усложняет картину?* Затем выбирай следующий запрос.
4. **Цитируй то, что важно.** Каждое load-bearing утверждение имеет inline URL или ссылку exp/NNN / FACTS.md секция / LEADS.md секция. Спекуляция помечается speculative: или unverified:.
5. **Гипотезы должны приземляться.** Каждая называет target-файлы, вид правки, предсказанное направление + примерную амплитуду. Если не можешь — предложи более дешёвый прекурсор вместо.
6. **Предлагай меньше, предлагай лучше.** 1–3 качественные гипотезы бьют десять. Ранжируй по (ожидаемая амплитуда) × (сила свидетельств) ÷ (стоимость имплементации).
7. **Думай открыто.** Тело отчёта показывает, на что смотрел, что удивило, что отбросил.
8. **Оставайся в своей полосе.** Читай всё inline из брифа; пиши только под research/ (плюс /tmp/research-<id>/ scratch). Никогда не правь experiments.tsv, CONFIG.md, target-файлы, eval, FACTS.md, LEADS.md, backlog.tsv.

### Протокол

1. **Прочитай бриф.** Отметь все inline-куски контекста, TSV и путь отчёта. Отсутствует инфа → сделай наиболее разумное предположение и запиши под секцию Notes.
2. **Спланируй перед действием.** Набросай план 2–5 bullets в начале черновика отчёта. Обновляй по мере поступления свидетельств.
3. **Работа в проходах.** Широкий → узкий → синтез. Между проходами напиши одну строку о том, что изменилось в картине.
4. **Напиши research/NNN-<slug>.md** (write-once, schema см. раздел 3).
5. **Добавь одну строку в research/research.tsv** (5 колонок).
6. **Вернуть compact report** (формат — раздел 5).

### Планка качества researcher

- Свежий читатель за 5 минут может решить, ставить ли в очередь любую предложенную гипотезу.
- Каждая гипотеза имеет **численный** фальсификатор.
- Каждое сильное утверждение имеет inline-цитату.
- Для reflect: секция Recommendations говорит main ровно, что продвинуть или отозвать и что добавить или дропнуть.

### Распространённые режимы отказа

- **Размытые гипотезы** ("попробовать оптимизатор получше") — перепиши как file + edit + Δmetric + falsifier, или дропни.
- **Одиночный узкий запрос** — сначала расширь.
- **Рассуждение только по авторитету** — проверь, что предпосылки реально выполнены в этом проекте.
- **Hype без чисел** — источник без масштаба или бейзлайна — это зацепка, не результат.
- **Предлагать изменения в eval** — никогда не трогай путь метрики. Зарегистрируй как question в секции Notes.
- **Устаревший откат FACTS в reflect** — не отзывай утверждение из Established, если свежий discard или противоречащие данные этого не требуют.
- **Свалка сырых результатов поиска** — синтез это твоя работа.

---

## 8. Глоссарий и шпаргалка

- **main** — главный тред Claude Code, event-driven координатор.
- **experimenter / researcher** — фоновые суб-агенты, по одному на задачу.
- **CONFIG.md** — замороженный контракт (метрика, eval, scope, seed).
- **ATLAS.md** — живой дашборд (decays).
- **FACTS.md** — подтверждённое знание из экспериментов (accretes). Секции: Established, Dead ends, Decisions, Anti-cheat log.
- **LEADS.md** — зацепки из research (перерабатывается). Секции: Emerging, Domain context, Open questions, Heuristics.
- **backlog.tsv** — очередь гипотез, вопросов, deferred, tooling.
- **experiments.tsv** — судовой журнал. Только keep продвигает знание в FACTS.
- **research.tsv** — журнал research-сессий.
- **worktree** — `git worktree add ../autoresearch-wt/exp-NNN-<slug> -b exp/NNN-<slug>`.
- **commit A** — изменение кода. **commit B** — запись (TSV + note).
- **keep** → ff-merge. **discard / crash / timeout / invalid** → cherry-pick record-коммита.
- **Правило отчёта** — сначала инсайт, метаданные в конце.
- **Инвариант** — только keep продвигает зацепку из LEADS.md в FACTS.md.
