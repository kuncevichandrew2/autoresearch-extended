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

`train.py` ends with a `---` divider followed by `val_bpb:
<float>` (6 decimal places). The regex picks up the first match on that
line. Training is expected to finish in ~5 min; the 600 s timeout matches
Karpathy's hard-kill threshold.

Hard constraints to paste into `./autoresearch/context.md`:
- Do not modify `prepare.py` or the `evaluate_bpb` harness.
- Do not install new packages or add dependencies.
- Training must finish within ~5 min wallclock; the run is killed at
  10 min.
- VRAM may rise modestly for a real val_bpb gain, but must not blow up.
- All else being equal, simpler wins. Code removals with equal-or-better
  val_bpb are a clear keep.

## Changeable

- reflect_every: 5
- reflect_on_plateau: 3
- max_experiments: unlimited
- stop_after_plateau: never
