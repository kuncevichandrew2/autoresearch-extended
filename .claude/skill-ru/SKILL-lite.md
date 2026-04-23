---
name: autoresearch
description: Автономный цикл оптимизации репозитория по одной скалярной метрике. Lite-версия — выжимка основных моментов, достаточная, чтобы агент отработал полный цикл. Полный справочник — в SKILL.md.
---

# autoresearch — lite

Репозиторий + одна метрика (число из shell-команды) → автономный цикл. Main — event-driven координатор; два фоновых суб-агента (experimenter, researcher) исполняют задачи. Main вызывает `Agent(subagent_type=..., run_in_background=true, prompt=<brief>)`, ждёт Agent-complete уведомлений, читает compact-отчёт, делает disk-check, интегрирует возвраты по мере прихода, диспатчит следующее.

## Инвариант

Только `status=keep` эксперимента переводит утверждение из LEADS.md (зацепки из research) в FACTS.md (подтверждённое). Исследование советует, эксперимент решает. Поток знания: main формулирует гипотезу → researcher обосновывает и уточняет фальсификатор → experimenter меряет → FACTS.md (+ опционально `knowledge/<topic>.md`).

## Принципы

1. **Бинарный keep/discard по одной скалярной метрике.** Keep, если бьёт текущий best в заданном направлении (min или max). Иначе откат.
2. **Замороженный контракт.** CONFIG.md, команда eval и bootstrap неизменны после того, как baseline (эксперимент 000) распарсился. Любое изменение требует re-setup.
3. **Эксперименты — истина, исследование — совет.** Только keep продвигает bullet из LEADS в FACTS.
4. **Строгое владение записью.** У каждого суб-агента одна директория: researcher пишет только в `research/`, experimenter — в `experiments/` и в target-файлах внутри `CONFIG.scope`. Main пишет везде, кроме этих двух областей. Чтение универсально.
5. **Самодостаточные брифы.** Суб-агенты никогда не ходят по `autoresearch/`, не читают прошлые заметки, не дозапрашивают контекст, не ищут в сети (кроме researcher на URL из брифа).
6. **Изоляция worktree.** Каждый эксперимент живёт в своём git worktree на ветке `exp/NNN-<slug>`. На keep — fast-forward merge. На остальное — cherry-pick только record-коммита, без кода.
7. **Хирургические правки.** Каждая изменённая строка трассируется к гипотезе. Никакого попутного клининга.
8. **Автономно до остановки.** После сетапа main никогда не спрашивает «продолжить?».

---

## File structure

### Дерево

```
autoresearch/
├── CONFIG.md                       # заморожен после baseline
├── bootstrap.sh | bootstrap.md     # заморожен после baseline
│
├── ATLAS.md                        # main — живой дашборд (decays)
├── FACTS.md                        # main — подтверждённое знание (accretes)
├── LEADS.md                        # main — зацепки из research (churns)
├── backlog.tsv                     # main — очередь работы
├── knowledge/<topic>.md            # emergent; ≥2 keep по теме или продвинут reflect
│
├── experiments/{experiments.tsv, NNN-<slug>.md}   # experimenter — append / write-once
├── research/{research.tsv, NNN-<slug>.md}         # researcher — append / write-once
└── workbench/                      # main scratchpad
```

**Правило размера.** Каждый mutable .md держится под ~400 строк (одно окно Read). При приближении main сжимает: обрезает старые ATLAS-bullets, схлопывает устаревшие FACTS/LEADS-записи в однострочники, продвигает повторяющуюся тему в `knowledge/<topic>.md`. Write-once заметки (`experiments/NNN-*.md`, `research/NNN-*.md`) не трогаем.

### Секции FACTS / LEADS / ATLAS

**FACTS.md** (accretes, подтверждённое экспериментом):
- **Established** — утверждения из keep-эксперимента, цитируют `exp/NNN`.
- **Dead ends** — повторяющиеся провалы; append-only, dedup по подстроке.
- **Decisions** — однострочный changelog (интеграции, паузы, policy-выборы).
- **Anti-cheat log** — рассинхрон TSV/report, foreign writes, события целостности.

**LEADS.md** (churns, перерабатывается по мере подтверждения/опровержения; это аггрегация информации из отчетов researcher):
- **Emerging** — предварительные утверждения из research, ждут подтверждения экспериментом.
- **Domain context** — Аггрегация знаний из researcher.
- **Open questions** — вопросы без гипотезы.
- **Heuristics** — спекулятивные паттерны ("кажется, X коррелирует с Y").

**ATLAS.md** (rewrites, снимок, ничего load-bearing):
- **Now** — best (метрика, exp id, commit), running sub-agents, флаги `paused` / `recommend_resetup`.
- **Recent signal** — кольцевой буфер 5 последних интеграционных событий.
- **Hot topics** — 2–4 топ-тега по активности из backlog + последних 10 экспериментов.

> **Кратко.** ATLAS = что сейчас, затухает. FACTS = что доказано, накапливается. LEADS = что прочитано и заподозрено, перерабатывается. У каждого своя динамика старения. Начальный набор секций не закрытый — main свободно заводит emergent-секции (Invariants, Calibrations, …), когда это помогает.

### CONFIG.md — замороженный контракт

```
goal              одна строка: что оптимизируем и зачем
metric            val_loss
direction         min | max
eval_command      bash scripts/eval.sh
parse_method      regex:^val_loss=([0-9.]+)$ | json_path:… | exit_code
timeout_sec       1800
scope             globs, которые experimenter может править
seed_policy       fixed:N | sampled:K-runs | none
reflect_every     10
max_parallel_experimenters  1
max_parallel_researchers    2
custom_tsv_columns          список (добавляются в experiments.tsv в порядке)

## Context            3–6 bullets: форма репо, target, как выглядит хороший прогон
## Constraints        жёсткие правила: held-out, лицензии, детерминизм, wall-clock
## Integrations       на каждую: имя, env vars, команда health
```

### backlog.tsv — очередь работы

9 колонок, append-only. Mutation in-place по id через атомарный `read → edit → temp → rename`.

```
id	kind	status	claim	source	created	consumed_by	outcome	notes
H-019	hypothesis	pending	apply Muon to 2D params	research/008-muon-digest.md#H-019	2026-04-20	-	-	top of queue
H-017	hypothesis	consumed	cosine warmup 10% beats linear	research/007-warmup-sweep.md#H-017	2026-04-15	exp/042	keep	-0.012 val_bpb
```

- `kind` ∈ {hypothesis, question, deferred, tooling}
- `status` ∈ {pending, blocked, running, consumed, done, dropped}
- Колонки 1, 2, 4, 5, 6 неизменны после append; 3, 7, 8, 9 мутабельны.

### experiments/experiments.tsv — судовой журнал

8 фиксированных колонок + `custom_tsv_columns` из CONFIG в порядке.

```
id	status	metric	delta	hypothesis	commit	timestamp	note
000	keep	3.074	0	-	a0b1c2d	2026-04-10T08:00Z	experiments/000-baseline.md
042	keep	3.041	-0.012	H-017	a1b2c3d	2026-04-22T12:30Z	experiments/042-warmup-cosine.md
043	discard	3.089	+0.048	-	e4f5g6h	2026-04-22T13:05Z	-
```

- `status` ∈ {keep, discard, crash, timeout, invalid}
- `metric` = NaN при crash / timeout / нераспарсенном
- `commit` — 7-char SHA record-коммита (commit B), **не** коммита с кодом
- `delta`: отрицательное улучшает при `direction=min`; положительное — при `max`

### experiments/NNN-<slug>.md — запись эксперимента

Write-once. Создаётся только при status ∈ {keep, invalid}.

```yaml
---
id: NNN
slug: <slug>
kind: experiment
date: <ISO8601>
status: keep | invalid
parent: <NNN родителя>
source_hypothesis: H-NNN | -
commit: <SHA commit B>
metric: <число | NaN>
delta: <signed | NaN>
---

## Hypothesis        один абзац
## Changes           bullets: file:line — зачем
## Result            метрика, delta, проверка направления, wall time, сюрпризы
## Log excerpt       последние ~20 сигнальных строк
## Notes             оговорки, связанные FACTS/LEADS-bullets
```

### research/research.tsv

5 колонок, одна строка на завершённую сессию.

```
id	type	date	report	one_line
R-008	digest	2026-04-20	research/008-muon-digest.md	Muon optimizer; H-019, H-020
R-009	reflect	2026-04-22	research/009-reflect-cycle-42.md	reflect after 10 exps; H-021 added
```

`type` ∈ {digest, sweep, eda, broader-tooling, reflect}.

### research/NNN-<slug>.md — дайджест сессии

Write-once.

```yaml
---
id: R-NNN
slug: <slug>
type: digest | sweep | eda | broader-tooling | reflect
date: <YYYY-MM-DD>
trigger: <backlog id или prompt>
hypotheses_produced: [H-NNN, H-NNN]
---

## Context
## Findings
## Hypotheses produced

### H-NNN: <one-liner>
- **Claim:** …
- **Rationale:** … (цитирует источники)
- **Method:** edit <file:line>, <kind of change>
- **Predicted Δmetric:** <direction + rough magnitude>
- **Risks:** …
- **Falsifier:** <конкретный численный порог>

## Recommendations   # только для type=reflect
## Notes
```

### knowledge/<topic>.md

Emergent. Создаётся только когда тема накопила ≥2 keep-эксперимента или reflect её явно продвинул. Проверенные факты, точные данные, load-bearing эвристики. Не перемешивается.

### Алфавит ID

NNN — эксперимент · R-NNN — research · H-NNN / Q-NNN / D-NNN / T-NNN — backlog (hypothesis / question / deferred / tooling). Zero-padded три цифры. Монотонные. Никогда не переиспользуются.

### Поток гипотез

Default: backlog (`kind=hypothesis`) → researcher (обосновать, уточнить falsifier) → experimenter (измерить). Острая, обоснованная идея может скипнуть researcher; размытая — зациклиться обратно на researcher. Отклонения — решения по суждению, не нарушения.

---

## Протоколы суб-агентов

Полные протоколы лежат в `agents/experimenter.md` и `agents/researcher.md` (копируются при сетапе в `.claude/agents/` проекта под именами `experimenter.md` и `researcher.md`; адаптируются только секции Mission и Common failure modes — остальное не трогаем). Ниже — только цели и ключевые рамки.

**experimenter** — дисциплинированный senior-инженер. Цель: ровно один эксперимент end-to-end. Входит в пред-созданный main'ом worktree на ветке `exp/NNN-<slug>`, применяет change_plan (минимальный diff, одна переменная, ничего вне scope), запускает eval с таймаутом, парсит метрику, решает `keep/discard/crash/timeout/invalid`, делает два коммита (A: код, B: TSV+note), возвращает compact report. **Записанное число — ground truth:** ни фабрикаций, ни retry-to-success, ни best-of-N, ни молчаливых крутилок флагов. Пишет только в `autoresearch/experiments/` и в target-файлы из scope. На `keep`/`invalid` пишет note; на `discard/crash/timeout` — нет. Подробности — `agents/experimenter.md`.

**researcher** — PhD-уровня коллаборатор. Цель: ровно одна research-задача одного из типов:

- **digest** — один источник, глубокое чтение.
- **sweep** — 3–5 целевых запросов, синтез; первичные источники предпочтительнее агрегаций.
- **eda** — короткие скрипты в `/tmp/research-<id>/` (вне репо), ≤ 60 с, без GPU, без сети за пределами URL из брифа.
- **broader-tooling** — оценка инструментов вне пути метрики; никогда не модифицирует eval.
- **reflect** — анализ недавних экспериментов + FACTS/LEADS → гипотезы + секция `## Recommendations`, которую main применяет механически.

Предлагает 1–3 гипотезы с **численным** фальсификатором, target-файлами, предсказанной амплитудой. Цитирует load-bearing утверждения. Пишет только в `research/` (плюс `/tmp/research-<id>/` scratch). Не правит `experiments.tsv`, CONFIG, target-файлы, eval, FACTS.md, LEADS.md, backlog.tsv. Подробности — `agents/researcher.md`.

Общий стиль: брифы самодостаточны (не дозапрашивают контекст); отчёт — insights first, metadata last.

---

## 4 фазы

| Фаза | Артефакт | Exit gate |
|---|---|---|
| 1. Setup | CLAUDE.md, CONFIG.md, дерево, оба агента установлены | CONFIG валиден, scaffold создан |
| 2. Prepare | `bootstrap.{sh,md}`, интеграции verified | bootstrap exit 0, все green |
| 3. Baseline | row 000 в experiments.tsv, ATLAS инициализирован | row 000 парсится → CONFIG + bootstrap замораживаются |
| 4. Loop | endless dispatch/integrate | выход по прерыванию пользователя |

### Фаза 1 — Setup (совместно с пользователем)

**Шаг 1. Картография репозитория → CLAUDE.md.** Исследуй entry points, билд, target-файлы, eval-флоу. Напиши CLAUDE.md в корне репо со всей архитектурой и контекстом, который ты понял.

**Шаг 2. Интервью через блоки AskUserQuestion.** Один вызов на блок; заранее набросай опции из репо, затем задавай.

- **A · Цель, метрика, направление.** Target-файл(ы) · метрика · min/max · seed policy (`fixed:N` / `sampled:K-runs` / `none`).
- **B · Предложи варианты метрик.** Каталог: val_loss, pass_at_k, f1_macro, auroc, judge_score, latency_p99_ms, bundle_kb, hbm_peak_gb и т. д. (не закрытый список).
- **C · Eval-флоу.** Команда · парсинг (`regex:…` / `json_path:…` / `exit_code`) · таймаут · кастомные TSV-колонки.
- **D · Контекст исследования.** Домен · известные потолки / SOTA · prior art · ограничения.
- **E · Интеграции.** Грепни W&B, MLflow, Docker, LLM-судьи. Один вызов AskUserQuestion с одним под-вопросом на каждую обнаруженную интеграцию (максимум 4): scope + env vars + команда health.

**Шаг 3. Scaffold.** Построй дерево под `autoresearch/`. Напиши CONFIG.md из ответов Шага 2. Создай TSV только с заголовками. Напиши FACTS.md и LEADS.md с пустыми секциями. Засей backlog 2–4 строками `hypothesis/pending` + 1–3 `deferred/pending`. Скопируй `agents/experimenter.md` и `agents/researcher.md` этого скила в `.claude/agents/` проекта; при необходимости адаптируй Mission и Common failure modes под домен. Не трогай frontmatter, секцию Protocol и схемы.

### Фаза 2 — Prepare

Напиши `bootstrap.sh` (или `bootstrap.md` для мульти-скриптового / computer-use / ручной аутентификации сетапа) — идемпотентный, повторно-запускаемый, артефакты в `.gitignore`. Перед скачиванием > 100 МБ или записью в общую систему — подтверждение у пользователя. Запусти до exit 0. Запусти health-check каждой интеграции. Запиши `YYYY-MM-DD — integrations verified: <names>` в FACTS.md Decisions.

### Фаза 3 — Baseline

Диспатчь experimenter против немодифицированного target. Бриф: эксперимент 000, slug `baseline`, без гипотезы, без change plan; worktree `../autoresearch-wt/exp-000-baseline`, ветка `exp/000-baseline` от HEAD; `eval / parse / timeout / direction / seed policy / custom columns` из CONFIG; current best = NaN. Main создаёт worktree перед dispatch. Experimenter пропускает commit A (нет change plan → нет правки), прогоняет eval, пишет row 000 и `000-baseline.md`, делает commit B `"exp 000: baseline"`. Main fast-forward'ит в `main`.

Инициализируй ATLAS Now с `000` как best; prepend `000` в Recent signal.

Если метрика NaN — итерируй по `eval_command` / `parse_method` / `timeout_sec`. CONFIG редактируем до тех пор, пока row 000 не распарсился. После — CONFIG и bootstrap **замораживаются**; любое дальнейшее изменение ⇒ re-setup.

### Фаза 4 — Loop

Main становится event-driven координатором. Смотри в следующий раздел

---

## Координация (фаза 4)

**Main никогда не простаивает.** Главный однопоточный — он не думает параллельно, но между dispatch и возвратом он готовит и диспатчит следующий бриф (до лимита concurrency), верифицирует последний возврат, сжимает ATLAS/FACTS/LEADS при подходе к ~400 строк, переупорядочивает или урезает `backlog.tsv`. Простаивать нормально, только если ничего не подходит — просыпается на следующем Agent-complete.

**Concurrency** (override в CONFIG) Базовый вариант:

- 1 experimenter (тяжёлые GPU/disk evals сериализуются).
- 3 researcher (дешёвые, I/O-bound).

Перед dispatch experimenter main создаёт worktree:

```sh
git worktree add ../autoresearch-wt/exp-NNN-<slug> -b exp/NNN-<slug> <parent_commit>
```

`worktree_path` и `branch` идут в брифе; суб-агент `cd`'ится внутрь и работает там.

### Делегирование (main → суб-агент): task brief

Проза, самодостаточно. Пиши как короткое сообщение коллеге: что нужно сделать + конкретные факты, которые суб-агент не угадает. Деталь включай только если без неё он гадал бы.

**experimenter brief** должен содержать: гипотезу (одно-два предложения с направлением и **численным** фальсификатором); change plan (пути файлов с номерами строк где важно, точные значения); worktree path + branch + parent commit; scope (подмножество `CONFIG.scope`); eval + parse + timeout; direction + текущий best; seed policy; пути для TSV-строки и заметки; `custom_tsv_columns` в порядке.

**researcher brief** должен содержать: односложную задачу; `type` (digest / sweep / eda / broader-tooling / reflect); `trigger` (backlog id или prompt); research id + slug. Inline-контекст, экономящий перечитывание: релевантные недавние эксперименты, конкретные bullets из FACTS/LEADS, URL / arxiv ids / пути файлов. Для `reflect`: inline последние N экспериментов и релевантный срез FACTS/LEADS. Пути для TSV-строки и отчёта.

### Возврат (суб-агент → main): compact report
Структура ответа: 
1. Sentinel: `EXPERIMENT_DONE` или `RESEARCH_DONE`.
2. Одно предложение со статусом и ключевым числом.
3. Тело — что *реально* узнали: числа, что удивило, как переформулируется гипотеза, очевидный follow-up.
4. В конце `refs:` с путями и SHA. Всё остальное main читает из TSV.

**Правило.** Если удаление тела не изменит ни одного решения main — перепиши тело с реальной находкой. Суб-агент потратил compute и контекст на то, чтобы узнать *что-то*; задача отчёта — передать это, а не перечислить id, которые main и так знает.

Мини-пример:

```
EXPERIMENT_DONE
042 warmup-cosine: keep. val_loss 3.041 (-0.012 vs best), H-017.

Cosine warmup 10% обходит linear-2% по всем осям; улучшение сосредоточено
в первых 3k шагах (графики сходятся с 5k) — выигрыш про форму ранней lr,
не асимптотическую. Стоит протестить warmup_ratio ∈ {5%, 15%}.

refs: commit a1b2c3d · note experiments/042-warmup-cosine.md
```

### Verification (после каждого возврата)

Дешёвый disk-check, не gate:

1. `tail -1 <referenced_tsv>` начинается с заявленного id.
2. Если status требует note — файл существует на диске.
3. Mismatch → trust TSV, log в FACTS Anti-cheat log (`YYYY-MM-DD — <id> report/tsv mismatch, trusting TSV`), пропустить интеграцию этого возврата.

### Интеграция по типу возврата

**Experiment keep:**

```sh
git merge --ff-only exp/NNN-<slug>
git worktree remove ../autoresearch-wt/exp-NNN-<slug>
git branch -d exp/NNN-<slug>
```

Затем: продвинь соответствующий bullet из LEADS Emerging в FACTS Established, цитируя `exp/NNN`; пометь backlog-строку `consumed/keep`; обнови ATLAS Now новым best; prepend в Recent signal.

**discard / crash / timeout:** изменение кода в main *не* попадает, только record-коммит.

```sh
git cherry-pick <record_commit>
git worktree remove ../autoresearch-wt/exp-NNN-<slug>
git branch -D exp/NNN-<slug>
```

Закрой backlog-строку `outcome=<status>`; отметь в ATLAS Recent signal. Повторяющийся паттерн → запись в FACTS Dead ends.

**invalid**: cherry-pick record-коммита, если он есть, иначе дропни worktree. Закрой backlog `outcome=invalid`. Два подряд invalid → `recommend_resetup=true` в ATLAS Now, пауза experimenter; researcher продолжают.

**Research digest / sweep / eda / broader-tooling**: гипотезы → в backlog как pending `H-NNN`; поддержанные утверждения → LEADS Emerging или Domain context.

**Research reflect**: секция Recommendations применяется к FACTS / LEADS / backlog механически.

### Когда что-то идёт не так

Логируй, восстанавливайся, продолжай. Эскалируй, только когда цикл не может двигаться.

- **TSV/report mismatch** → trust TSV, log в FACTS Anti-cheat, skip.
- **Два подряд invalid** → `recommend_resetup=true`, пауза experimenter.
- **ff-only конфликт** (не должен случаться при concurrency=1) → abort, пауза, notify пользователя.
- **Foreign write суб-агента** → `git checkout HEAD -- <path>`, log в Anti-cheat, пометь шаблон агента на ревью.
- **Orphan worktree** после упавшей интеграции → `git worktree remove --force` + `git branch -D`, реконструкция состояния из TSV.

### Остановка

Только по прерыванию пользователя: записать `paused` в ATLAS Now, дать running суб-агентам завершиться, интегрировать их возвраты, остановиться.

### Re-setup

Триггер — когда CONFIG, bootstrap или eval должны измениться после baseline. Крайняя мера. Большинство «re-setup»-ощущений — повод завести `question` в backlog.

1. Остановить цикл (прерывание пользователя).
2. Очистить orphan'ы: `git worktree list` → `git worktree remove --force` всех `autoresearch-wt/*`; `git branch -D exp/*`.
3. Архив: `git mv autoresearch autoresearch.archive-<date>`.
4. Перезапустить Фазы 1–3.
5. Вручную портировать релевантные bullets из старых FACTS.md и LEADS.md в новые файлы. **История `experiments.tsv` не переносится** — baseline'ы разные.
