# examples

Four fully-worked `config.md` files. Copy the closest match into
`./autoresearch/config.md` during setup and adapt.

| # | Domain | Target | Eval | Metric | Source | Parse |
|---|---|---|---|---|---|---|
| 01 | ML training | `train.py` | `uv run train.py` | `val_loss` min | code | `summary_block` |
| 02 | API latency | `src/api/search.py` | `pytest bench.py -q` | `p50_ms` min | code | `regex: p50=([0-9.]+)ms` |
| 03 | Prompt eval | `prompts/assistant.md` | `npx promptfoo eval -c promptfoo.yaml --output out.json` | `pass_rate` max | code | `json_path: $.results.stats.successes` |
| 04 | Docker + screenshot + LLM judge | `src/ui/Landing.tsx` | `bash eval.sh` | `design_score` max | llm-judge | `file:metric.txt` |

Example 04 is the hardest case and demonstrates "eval can be a pipeline."
Its `eval.sh` sketch:

```sh
#!/usr/bin/env bash
set -euo pipefail
docker build -t landing-eval .
docker run --rm -d --name landing -p 3000:3000 landing-eval
trap 'docker rm -f landing >/dev/null 2>&1 || true' EXIT
sleep 3
npx playwright screenshot http://localhost:3000 /tmp/landing.png
python3 judge.py /tmp/landing.png > /tmp/judge.json
jq '.design_score' /tmp/judge.json > metric.txt
```

The judge (`judge.py`) posts the screenshot to the Anthropic API with a
rubric prompt and returns JSON with a `design_score` field. `metric.txt`
is what develop parses; everything else is plumbing.
