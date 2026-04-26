# Структуры файлов

Справочник: дерево, назначение каждого файла, поля и заполненные примеры. Адресация по путям.

## Дерево

```
autoresearch/
├── CONFIG.md                    замороженный контракт
├── bootstrap.sh | bootstrap.md  замороженный setup
│
├── current/                     зона main
│   ├── MEMORY.md                cold-startable память main
│   ├── log.tsv                  лог активности main
│   └── workbench/               черновики
│
├── knowledge/                   общая база (пишет main)
│   ├── KNOWLEDGE.md             индекс/агрегатор, не журнал
│   └── <topic>.md               propositions + evidence
│
└── sub-agents/
    ├── experiments/             зона experimenter
    │   ├── MEMORY.md            память experimenter
    │   ├── log.tsv              журнал experimenter
    │   └── NNN-<slug>.md        запись эксперимента (на keep / invalid)
    └── research/                зона researcher
        ├── MEMORY.md            память researcher
        ├── log.tsv              журнал researcher
        └── NNN-<slug>.md        отчёт сессии
```

## CONFIG.md

Замороженный контракт. Поля:

```
Goal              одна строка: что оптимизируем и почему
Metric.name              имя метрики (например, val_loss)
Metric.direction         min или max
Metric.eval_command      shell-команда, печатающая одно число
Metric.parse_method      regex:… | json_path:… | exit_code
Metric.timeout_sec       таймаут одного прогона
Metric.seed_policy       fixed:N | sampled:K-runs | none
Scope                    globs, которые experimenter может править
Custom TSV columns       колонки, дописанные после 8 фиксированных
                         в sub-agents/experiments/log.tsv
Concurrency              max_parallel_experimenters,
                         max_parallel_researchers
Scheduler                exploration_every, analysis_every,
                         consolidation_every, coldstart_check_every
Brief budgets (токены)   experimenter, deep_research, analysis,
                         exploration
Return budgets (токены)  experimenter_body, researcher_body
Constraints              held-out, лицензии, детерминизм, wall-clock
Integrations             на каждую: name, env, health-команда
```

## current/MEMORY.md

Cold-startable память main. Описание секций — в самом шаблоне (templates/autoresearch/current/MEMORY.md). Универсальный скелет (Status, Queue, Recent, Patterns, Avoid + опциональные) описан в SKILL.md.

Заполненный пример:

```
## Status
- Best metric: val_bpb 3.041 from experiments/042-warmup-cosine (a1b2c3d)
- Active sub-agents: experimenter on 079, researcher on 015
- Flags: none
- Scheduler: exploration in 4 · analysis in 4 · consolidation in 19 · coldstart-check in 23
- Phase: loop

## Queue
- Применить Muon к 2D-параметрам, источник research/008-muon-digest.
- Попробовать grad-clip 0.5 в low-LR режиме — knowledge/gradient-clipping.md (contested).
- Проверить val на отсутствие утечки — отложено до цикла 50.

## Recent
- experiments/078 keep -0.008 — повторили cosine warmup при batch=64
- experiments/077 discard +0.003 — warmup_ratio=15% null
- research/014 analysis — формализовали P2 в warmup-schedules

## Patterns
- LR-schedule идеи стабильно дают keep (3 keep из последних 10).
- Eval шумный ниже |Δ|=0.004 — falsifier-ы туже этого приходят invalid.

## Avoid
- LR > 1e-3 — расходится всегда (031, 044, 061).
- LayerNorm → RMSNorm не предлагать — research/009.
```

## current/log.tsv

Полный журнал действий main. Ведёт сам main по факту интеграции. Колонки:

```
timestamp    UTC ISO-время записи
action       experiment | research | consolidate | compress | integrity
target       путь объекта (experiments/NNN-<slug>, research/NNN-<slug>, knowledge/<topic>.md, ...)
outcome      experiment: keep | discard | crash | timeout | invalid
             research:   done
             прочее:     updated | recorded
delta        для experiment — знаковое изменение метрики; иначе "-"
notes        короткая ремарка
```

Пример:

```
2026-04-22T12:30Z	experiment	experiments/042-warmup-cosine	keep	-0.012	new best
2026-04-22T13:05Z	experiment	experiments/043	discard	+0.048	-
2026-04-22T14:00Z	research	research/008-muon-digest	done	-	queued 2 ideas
2026-04-25T10:15Z	consolidate	knowledge/warmup-schedules.md	updated	-	exp/058 added; P2 confirmed
2026-04-22T13:55Z	integrity	experiments/044	recorded	-	report/tsv mismatch; trusted TSV
```

## knowledge/KNOWLEDGE.md

Индекс. Пишет main. Секции описаны в шаблоне. Заполненный пример:

```
## Current best
val_bpb 3.041 from experiments/042-warmup-cosine.

## Confirmed topics
- warmup-schedules — cosine 10% бьёт linear 2% при LR ∈ [1e-4, 5e-4]; выигрыш в начале. → warmup-schedules.md
- data-integrity — held-out eval подтверждён без утечек на data/v3. → data-integrity.md

## Watch list
- batch-size scaling (experiments/067) — batch=128 лучше 64 при LR=3e-4.

## Contested
- gradient-clipping — clip=1.0 выигрывает при LR ∈ [1e-4, 5e-4] (experiments/063); проигрывает при LR=8e-5 (experiments/079). → gradient-clipping.md

## Integrity events
- 2026-04-15 — integrations verified: wandb, docker
- 2026-04-22 — experiments/044 report/tsv mismatch, trusted TSV
```

## knowledge/<topic>.md

Создаётся, когда по теме набралось ≥ 2 keep. Стабильные propositions сверху, evidence-аппендикс append-only снизу. Пишет main.

Frontmatter:

```
topic              имя темы (slug)
created            дата первого подтверждения
last_evidence      дата + ссылка на последнее evidence
related_topics     список связанных тем
```

Тело:

```
## Propositions (stable)
   ### Pn. <утверждение>
   - Scope:           условия применимости
   - Falsifier:       численное правило, опровергающее утверждение
   - Established by:  список experiments/NNN, подтвердивших
   - Status:          confirmed | contested

## Evidence appendix (append-only)
   - experiments/NNN keep|discard ±delta — комментарий
   - research/NNN — комментарий
```

Контрадикция: новое evidence в пересекающемся scope флипает Status в contested; исходные данные не удаляются.

Пример:

```
---
topic: warmup-schedules
created: 2026-04-22
last_evidence: 2026-04-30 (experiments/078)
related_topics: [optimizers, lr-schedules]
---

# Warmup schedules

## Propositions (stable)

### P1. Cosine warmup at 10% beats linear warmup at 2% on val_bpb
- Scope: lr ∈ [1e-4, 5e-4], batch ≤ 64
- Falsifier: любой эксперимент в scope, где linear ≤ cosine на ≥ 0.005
- Established by: experiments/042, experiments/058
- Status: confirmed

### P2. Выигрыш концентрируется в шагах 0–3k; кривые сходятся к 5k
- Scope: как у P1
- Falsifier: разрыв расширяется после шага 5k
- Established by: experiments/042 (анализ кривой), experiments/058
- Status: confirmed

## Evidence appendix
- experiments/042 keep -0.012 — первое подтверждение P1, P2
- experiments/058 keep -0.008 — реплика на batch=64
- experiments/077 discard +0.003 — warmup_ratio=15% null
- research/007 — обзор литературы по warmup
- research/014 — анализ после experiments/058, формализация P2
```

## sub-agents/experiments/MEMORY.md

Память experimenter. Описание секций — в самом шаблоне.

## sub-agents/experiments/log.tsv

Журнал experimenter. Дописывает сам experimenter после каждого прогона. 8 фиксированных колонок плюс custom_tsv_columns из CONFIG в порядке.

```
id           NNN, монотонно растущий
status       keep | discard | crash | timeout | invalid
metric       значение метрики; NaN при crash, timeout, parse-fail
delta        знаковое изменение от current_best; NaN при crash/timeout/parse-fail
description  одна строка по сути изменения
commit       7-символьный SHA коммита B (record)
timestamp    UTC ISO-время записи
note         путь NNN-<slug>.md если есть, иначе "-"
... custom   значения custom_tsv_columns в порядке из CONFIG
```

Пример:

```
000	keep	3.074	0	baseline	a0b1c2d	2026-04-10T08:00Z	000-baseline.md
042	keep	3.041	-0.012	cosine warmup 10% vs linear 2%	a1b2c3d	2026-04-22T12:30Z	042-warmup-cosine.md
043	discard	3.089	+0.048	cosine warmup 25%	e4f5g6h	2026-04-22T13:05Z	-
044	crash	NaN	NaN	swap tokenizer to BPE	b7c8d9e	2026-04-22T13:40Z	-
```

## sub-agents/experiments/NNN-<slug>.md

Write-once. Создаётся только на keep или invalid. Пишет experimenter. Frontmatter:

```
id, slug, kind                    идентификация
date                              UTC ISO-время
status                            keep | invalid
parent                            NNN, на котором был current_best
source                            research/NNN-<slug> или "-"
commit                            SHA коммита B
metric, delta                     значения
```

Тело: Hypothesis, Changes (file:line — почему), Result (метрика, delta, проверка falsifier-а, wall time, сюрпризы), Log excerpt (~20 значимых строк), Notes (caveats, ссылки на затронутые knowledge/<topic>.md).

## sub-agents/research/MEMORY.md

Память researcher. Описание секций — в самом шаблоне.

## sub-agents/research/log.tsv

Журнал researcher. Дописывает сам researcher по итогам сессии. Колонки:

```
id          NNN, монотонно растущий
type        deep-research | analysis | broader-tooling | exploration
date        дата YYYY-MM-DD
report      путь NNN-<slug>.md
outcome     queued:N (сколько идей пошло в Queue main)
            informational (полезный контекст без новых гипотез)
            null (ничего не дало)
one_line    однострочное резюме (≤ 80 символов)
```

Пример:

```
007	deep-research	2026-04-15	007-warmup-sweep.md	queued:2	cosine warmup grounded
008	deep-research	2026-04-20	008-muon-digest.md	queued:2	Muon optimizer
009	exploration	2026-04-21	009-norm-survey.md	null	RMSNorm не оправдан
014	analysis	2026-04-26	014-cycle-50-review.md	queued:1	formalised warmup P2
```

## sub-agents/research/NNN-<slug>.md

Write-once. Пишет researcher. Свободная проза, лёгкий каркас. Frontmatter: id, slug, type, date, trigger.

Тело: Topic (одно предложение, что и почему), Findings (свободно — что выяснено), Hypotheses produced (по 1–3 — с целевыми файлами и численным falsifier-ом), Sources (URL / arxiv id / file path — одна строка о значимости), Recommendations (только для analysis), Notes (caveats, тупики).
