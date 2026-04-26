# Интервью

Один блок AskUserQuestion — один вопрос. Опции пред-набрасываются из репо: пользователь выбирает, а не печатает.

```
A. Цель, метрика, направление
   target file(s) · metric · min/max · seed_policy (fixed:N | sampled:K-runs | none)

B. Подсказки по метрике
   val_loss, pass_at_k, f1_macro, auroc, judge_score, latency_p99_ms,
   bundle_kb, hbm_peak_gb. Список открыт.

C. Eval flow
   command · parser (regex:… | json_path:… | exit_code) · timeout ·
   custom TSV columns

D. Контекст
   домен · известные потолки / SOTA · prior art · ограничения
   (held-out, лицензии, детерминизм, wall-clock)

E. Интеграции
   grep по wandb, MLflow, Docker, LLM judges. Один блок AskUserQuestion,
   один под-вопрос на интеграцию (≤ 4): scope + env vars + health
```
