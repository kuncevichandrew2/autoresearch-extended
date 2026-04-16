# config — 03-prompt-eval

## Fix

- target: `prompts/assistant.md`
- read_only_context: `promptfoo.yaml`, `tests/cases.jsonl`
- eval_command: `npx promptfoo eval -c promptfoo.yaml --output out.json`
- timeout_sec: 600
- metric_name: `pass_rate`
- metric_direction: `max`
- metric_source: `code`
- parse_method: `json_path: $.results.stats.successes`

Divide `successes` by `results.stats.total` during parse to get a rate.
Promptfoo writes `out.json` in the project root; the loop reads it from
there.

## Changeable

- reflect_every: 4
- reflect_on_plateau: 2
- max_experiments: 80
- stop_after_plateau: 6
