# config — 01-ml-training (Karpathy autoresearch)

Reproduces the contract of
[karpathy/autoresearch](https://github.com/karpathy/autoresearch): a
single `train.py` trained for ~5 minutes, evaluated via `evaluate_bpb`
in `prepare.py`, with `val_bpb` printed to stdout.

## Fix

- target: `train.py`
- eval_command: `uv run train.py`
- timeout_sec: 600
- metric_name: `val_bpb`
- metric_direction: `min`
- metric_source: `code`
- parse_method: `regex: val_bpb:\s+([0-9.]+)`
- bootstrap_artifacts:
  - `./autoresearch/data/train.bin`       # tokenized train split
  - `./autoresearch/data/val.bin`         # tokenized val split
  - `./autoresearch/data/tokenizer.json`  # frozen tokenizer
  - `./autoresearch/data/.bootstrap.ok`   # sentinel written on success

## One-time bootstrap (phase 3 of setup)

`./autoresearch/bootstrap.sh` runs these exactly once and never again:

1. Download the dataset (e.g. FineWeb-Edu 10B sample).
2. Train the tokenizer (or load a pinned one) and save `tokenizer.json`.
3. Tokenize train + val splits into `train.bin` / `val.bin`.
4. Touch `.bootstrap.ok` so the script is a no-op on re-runs.

Everything above is **frozen** once setup exits. `train.py` reads these
files; it must never regenerate them.

## Hard constraints (paste into `./autoresearch/context.md`)

- Do not modify `prepare.py` or the `evaluate_bpb` harness.
- Do not modify `bootstrap.sh` or any file in `./autoresearch/data/`.
- Do not install new packages or add dependencies.
- Training must finish within ~5 min wallclock; killed at 10 min.
- VRAM may rise modestly for a real val_bpb gain, but must not blow up.
- All else equal, simpler wins. Code removals with equal-or-better
  `val_bpb` are a clear keep.

## Changeable

- reflect_every: 5
- reflect_on_plateau: 3
- max_experiments: unlimited
- stop_after_plateau: never
