# CS336 A1 — paste-sequence for Claude Code

Three inputs in order. Paste → click → paste.

## 1. Kick-off prompt (paste into Claude)

```
run autoresearch
```

## 2. Answers to the four AskUserQuestion panel

| # | Question | Click |
|---|---|---|
| Q1 | Target file(s) + objective | **Scaffold `train.py` — minimize OpenWebText `val_loss`** (the "scaffold a new training script" option; `cs336_basics/` stays read-only) |
| Q2 | Eval flow | **Single command prints metric as last line** — `uv run train.py` emits `val_loss: <float>` on its final stdout line |
| Q3 | Research context | **Paste constraints inline now** — I'll give them at the next prompt |
| Q4 | Auxiliary tools | **Weights & Biases** (for curves) — or **None** if you want zero side-effects |

If an exact label doesn't appear, pick **Other** and type the wording above.

## 3. Paste at "Any corrections before I scaffold?"

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

Loop caps: max_experiments=40, stop_after_plateau=8, reflect_every=5, reflect_on_plateau=3.

Auxiliary (W&B) must log only — it must not affect loss, seeds, or eval.
Always call wandb.init(save_code=True) so train.py survives pod loss.
```

## 4. Approve the printed config

Claude will print the full `./autoresearch/config.md`, `context.md`,
`auxiliary.md`, and the scaffolded `train.py`, then ask:

> Approve? (yes/no)

If it matches the example in `cs336-a1-quickstart.md §5`, reply:

```
yes
```

After approval the skill runs bootstrap (tokenize OpenWebText), the
baseline, and then loops develop/reflect autonomously until
`max_experiments=40` or `stop_after_plateau=8`.

## 5. Monitor (another shell)

```sh
tail -f ~/a1/autoresearch/results.tsv
cat  ~/a1/autoresearch/state.md
```
