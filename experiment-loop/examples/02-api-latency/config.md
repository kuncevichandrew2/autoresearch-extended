# config — 02-api-latency

## Fix

- target: `src/api/search.py`
- read_only_context: `src/api/bench.py`, `src/api/fixtures/`
- eval_command: `pytest src/api/bench.py -q`
- timeout_sec: 120
- metric_name: `p50_ms`
- metric_direction: `min`
- metric_source: `code`
- parse_method: `regex: p50=([0-9.]+)ms`

`bench.py` warms the cache for 5s, runs 2000 requests against a local
fixture, and prints a line like `p50=17.4ms p95=33.1ms p99=58.0ms`. The
regex grabs the `p50` group.

## Changeable

- reflect_every: 5
- reflect_on_plateau: 3
- max_experiments: 200
- stop_after_plateau: 10
