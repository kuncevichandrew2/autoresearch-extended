# Plan: run experiment-loop on CS336 A1 leaderboard

**Target:** minimize OpenWebText validation loss at context length 512 within
45 min on a single B200 GPU.
Refs: [assignment](https://github.com/stanford-cs336/assignment1-basics)
· [leaderboard](https://github.com/stanford-cs336/assignment1-basics-leaderboard)

## A. Setup (one-time, on RunPod)

```sh
# 1. Rent a B200 pod on RunPod (PyTorch 2.x template, ≥ 100 GB disk).
# 2. Install Claude Code.
npm i -g @anthropic-ai/claude-code && claude login

# 3. Install the skill.
git clone git@github.com:kuncevichandrew2/autoresearch-extended.git \
  ~/.claude/skills/experiment-loop-repo
ln -s ~/.claude/skills/experiment-loop-repo/experiment-loop \
  ~/.claude/skills/experiment-loop

# 4. Clone the assignment and sync deps.
git clone https://github.com/stanford-cs336/assignment1-basics.git ~/a1
cd ~/a1 && uv sync

# 5. Download OpenWebText subsample per the assignment README into ~/a1/data/.

# 6. Start Claude, paste prompt1 below.
claude
```

## B. prompt1 (paste into Claude Code inside ~/a1)

```
Run experiment-loop on this repo.

Context: Stanford CS336 A1 leaderboard — minimize OpenWebText val_loss at
context length 512, ≤ 2700 s per run on a single B200.

Analyze the repo (note: no training entrypoint exists yet — you'll need to
scaffold a Karpathy-style train.py that loads cs336_basics/ and prints`val_loss: <float>` as its last line) and propose the setup. I'll give
you hard constraints when you ask.
```

### What the skill does next (no extra prompts required)

1. **Analyze & propose** — reads `README`, `pyproject.toml`, `cs336_basics/`,
   `data/`, prints a proposal: `target=train.py` (to scaffold),
   `metric=val_loss min`, `parse=regex: val_loss:\s+([0-9.]+)`,
   `eval_command=uv run train.py`, `timeout_sec=2800`. Asks for your
   additional context.

2. **You reply with the hard constraints** (copy-paste):
   ```
   Hard constraints:
   - Only OpenWebText training data.
   - Eval at context length 512; do not change val split, eval routine, or tokenizer.
   - Training + eval ≤ 2700 s on a single B200.
   - Keep GPU memory < 170 GB (leave headroom on 192 GB).
   - No external LM implementations — only cs336_basics/ and train.py.
   - Do not edit cs336_basics/*, data download/tokenization, or anything outside train.py.
   - Do not disable the val loop, shrink the val set, or change the val_loss print format.
   - No pip install / uv add / importing packages not in pyproject.toml.
   - val_loss < 3.3 is known to be hard; treat sudden drops below as gaming suspects.

   Loop caps: max_experiments=40, stop_after_plateau=8, reflect_every=5,
   reflect_on_plateau=3.
   ```

3. **Scaffold** — writes `train.py`, `./autoresearch/{config,context,auxiliary}.md`.
   Shows you the full config and asks "Approve?".

4. **Baseline** — runs `uv run train.py` once. Initializes
   `state.md`, `results.tsv`, `experiments/000-baseline.md`.

5. **Loop** — autonomous develop/reflect until a termination condition fires.

## C. Monitor

```sh
tail -n 20 ~/a1/autoresearch/results.tsv
cat ~/a1/autoresearch/state.md
```

## D. Stop and submit

When `max_experiments` hits (or you interrupt):

1. Read `state.md` → best experiment number + commit SHA.
2. `git checkout <sha>` and rerun `uv run train.py` to verify reproducibility.
3. Package that commit as a uv project (`pyproject.toml`, `uv.lock`,
   `main.py`) and open a PR to `assignment1-basics-leaderboard`.

## Watch-outs

- **Metric gaming.** `val_loss < 3.3` is "not easy". Any sudden drop → open
  the experiment note, verify no train/val leakage, context-length cheat,
  or eval-loop bypass. Reflect flags these automatically; trust it.
- **OOM crash loops.** If the agent keeps scaling past 192 GB, tighten the
  GPU-memory hard constraint in `context.md` (re-enter setup).
- **Cost.** B200 on RunPod ≈ $4–6/hr. 40 × 45 min ≈ 30 GPU-hours ≈ $150–180.
  Adjust `max_experiments` to budget.
