# CONFIG

Замороженный контракт. Редактируется до прохода experiments/000; после — заморожен. Если что-то всё-таки должно измениться — это re-setup, не edit.

# Goal

Одна строка: что оптимизируем и почему именно эта метрика.

# Metric

```
name             например, val_loss
direction        min | max
eval_command     bash scripts/eval.sh
parse_method     regex:^val_loss=([0-9.]+)$ | json_path:result.metric | exit_code
timeout_sec      1800
seed_policy      fixed:N | sampled:K-runs | none
```

# Scope

Globs, которые experimenter может править. Всё остальное — вне зоны.

```
src/**/*.py
configs/*.yaml
```

# Custom TSV columns

Дополнения после 8 фиксированных колонок в sub-agents/experiments/log.tsv, в этом порядке.

```
wallclock_min
peak_vram_gb
```

# Concurrency

```
max_parallel_experimenters   1
max_parallel_researchers     2
```

# Scheduler

Каденции; состояние выводится в current/MEMORY.md Status.

```
exploration_every       10
analysis_every          10
consolidation_every     25
coldstart_check_every   25
```

# Brief budgets (токены)

```
experimenter      2000
deep_research     4000
analysis          6000
exploration       2000
```

# Return budgets (токены)

```
experimenter_body   500
researcher_body     800
```

# Constraints

Жёсткие правила: held-out, лицензии, детерминизм, wall-clock.

# Integrations

На каждую: name, env, health.

```
- name: wandb
  env: WANDB_API_KEY
  health: python -c "import wandb, os; wandb.login(key=os.environ['WANDB_API_KEY'])"
```
