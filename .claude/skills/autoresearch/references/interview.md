# Interview

One AskUserQuestion block — one question. Options are pre-drafted from the repo: the user selects, not types.

```
A. Goal, metric, direction
   target file(s) · metric · min/max · seed_policy (fixed:N | sampled:K-runs | none)

B. Metric suggestions
   val_loss, pass_at_k, f1_macro, auroc, judge_score, latency_p99_ms,
   bundle_kb, hbm_peak_gb. List is open.

C. Eval flow
   command · parser (regex:… | json_path:… | exit_code) · timeout ·
   custom TSV columns

D. Context
   domain · known ceilings / SOTA · prior art · constraints
   (held-out, licenses, determinism, wall-clock)

E. Integrations
   grep for wandb, MLflow, Docker, LLM judges. One AskUserQuestion block,
   one sub-question per integration (≤ 4): scope + env vars + health command
```
