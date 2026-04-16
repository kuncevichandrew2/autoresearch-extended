# config — 01-ml-training

## Fix

- target: `train.py`
- read_only_context: `prepare.py`, `data/`
- eval_command: `uv run train.py`
- timeout_sec: 330
- metric_name: `val_loss`
- metric_direction: `min`
- metric_source: `code`
- parse_method: `summary_block`

`train.py` is expected to print a final fenced JSON block of the form:

```json
{"val_loss": 3.142, "train_loss": 2.718, "steps": 2000}
```

## Changeable

- reflect_every: 5
- reflect_on_plateau: 3
- max_experiments: unlimited
- stop_after_plateau: never
