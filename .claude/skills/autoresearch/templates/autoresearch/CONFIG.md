# CONFIG

Frozen contract. Editable until experiment 000 passes; frozen after. If something must change — that is re-setup, not an edit.

# Goal

One line: what we are optimizing and why this metric.

# Metric

```
name             e.g. val_loss
direction        min | max
eval_command     bash scripts/eval.sh
parse_method     regex:^val_loss=([0-9.]+)$ | json_path:result.metric | exit_code
timeout_sec      1800
seed_policy      fixed:N | sampled:K-runs | none
```

# Scope

Globs that experimenter may edit. Everything else is out of bounds.

```
src/**/*.py
configs/*.yaml
```

# Custom TSV columns

Columns appended after the 8 fixed columns in sub-agents/experiments/log.tsv, in this order.

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

Cadences; state is shown in current/MEMORY.md Status.

```
exploration_every       10
analysis_every          10
consolidation_every     25
coldstart_check_every   25
```

# Brief budgets (tokens)

```
experimenter      2000
deep_research     4000
analysis          6000
exploration       2000
```

# Return budgets (tokens)

```
experimenter_body   500
researcher_body     800
```

# Constraints

Hard rules: held-out, licenses, determinism, wall-clock.

# Integrations

Per integration: name, env, health command.

```
- name: wandb
  env: WANDB_API_KEY
  health: python -c "import wandb, os; wandb.login(key=os.environ['WANDB_API_KEY'])"
```
