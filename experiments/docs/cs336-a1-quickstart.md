# CS336 A1 leaderboard — quickstart

Minimize OpenWebText val_loss, ctx=512, ≤2700 s on one B200.

## 1. In the RunPod shell

```sh
npm i -g @anthropic-ai/claude-code && claude login

git clone https://github.com/kuncevichandrew2/autoresearch-extended.git ~/.claude/skills/experiment-loop-repo
ln -s ~/.claude/skills/experiment-loop-repo/experiment-loop ~/.claude/skills/experiment-loop

git clone https://github.com/stanford-cs336/assignment1-basics.git ~/a1
cd ~/a1 && uv sync
# download OpenWebText into ~/a1/data/ per the assignment README

claude
```

## 2. Paste into Claude Code

```
run autoresearch
```

The skill explores the repo first, then opens an `AskUserQuestion` panel
with four questions. Answer as below.

## 3. Answer the four setup questions

| # | Question | Pick |
|---|---|---|
| Q1 | Target file(s) + objective | **Scaffold `train.py` — minimize OpenWebText `val_loss`** (pick the "scaffold" option; `cs336_basics/` stays read-only) |
| Q2 | Eval flow | **Single command prints metric as last line** — `uv run train.py` emits `val_loss: <float>` |
| Q3 | Research context | **Paste constraints inline now**, then paste the block in §4 |
| Q4 | Auxiliary tools | **None** for a first run (or **Weights & Biases** if you want curves) |

## 4. When Claude asks "anything I misread?", paste

```
Hard constraints:
- Only OpenWebText training data.
- Eval at ctx=512; do not change val split, eval routine, or tokenizer.
- Training + eval ≤ 2700 s on one B200.
- GPU memory < 170 GB.
- No external LMs — only cs336_basics/ and train.py.
- Do not edit cs336_basics/*, data download/tokenization, or anything outside train.py.
- Do not disable the val loop, shrink the val set, or change the val_loss print format.
- No pip install / uv add / new imports outside pyproject.toml.
- val_loss < 3.3 is hard — flag sudden drops as gaming.

Loop caps: max_experiments=40, stop_after_plateau=8, reflect_every=5, reflect_on_plateau=3.
```

## 5. Expected `./autoresearch/config.md`

Claude should print approximately this before asking "Approve? (yes/no)":

```markdown
# config — cs336 A1 leaderboard

## Fix

- target: `train.py`
- eval_command: `uv run train.py`
- timeout_sec: 2700
- metric_name: `val_loss`
- metric_direction: `min`
- metric_source: `code`
- parse_method: `regex: val_loss:\s+([0-9.]+)`
- bootstrap_artifacts:
  - `./autoresearch/data/owt_train.bin`    # tokenized OpenWebText train
  - `./autoresearch/data/owt_val.bin`      # tokenized OpenWebText val (ctx=512)
  - `./autoresearch/data/tokenizer.json`   # pinned tokenizer
  - `./autoresearch/data/.bootstrap.ok`    # sentinel

## Changeable

- reflect_every: 5
- reflect_on_plateau: 3
- max_experiments: 40
- stop_after_plateau: 8
```

Approve when the printed config matches.

## 4. Monitor (in another shell)

```sh
tail -f ~/a1/autoresearch/results.tsv
cat  ~/a1/autoresearch/state.md
```

## 5. When done — submit

```sh
cd ~/a1
BEST_SHA=$(grep -E '^best' autoresearch/state.md | awk '{print $NF}')
git checkout $BEST_SHA
uv run train.py   # verify reproducibility
# then package as a uv project and open a PR to assignment1-basics-leaderboard
```
