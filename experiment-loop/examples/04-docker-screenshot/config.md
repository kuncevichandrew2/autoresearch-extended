# config — 04-docker-screenshot

## Fix

- target: `src/ui/Landing.tsx`
- eval_command: `bash eval.sh`
- timeout_sec: 300
- metric_name: `design_score`
- metric_direction: `max`
- metric_source: `llm-judge`
- parse_method: `file:metric.txt`

`eval.sh` is user-written and covers: `docker build` → `docker run` →
`playwright screenshot` → `judge.py` (Claude API with `rubric.md`) →
`jq` the score into `metric.txt`. See `../README.md` for the sketch.

Hard constraints to encode in `context.md`:
- Do not edit `rubric.md`, `judge.py`, or `eval.sh`.
- Do not change routes, copy, or features mentioned in `rubric.md`.
- Do not disable screenshot viewport or wait conditions.

## Changeable

- reflect_every: 3
- reflect_on_plateau: 2
- max_experiments: 40
- stop_after_plateau: 5
