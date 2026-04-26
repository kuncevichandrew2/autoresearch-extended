# Bootstrap recipes

bootstrap.sh — один скрипт, идемпотентный, перезапускаемый. Артефакты в .gitignore. Перед загрузкой > 100 МБ или системной правкой — спросить пользователя.

bootstrap.md — когда нужно несколько скриптов или ручные шаги (computer-use, manual auth).

# Минимальный шаблон bootstrap.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

python -c "import wandb, os; wandb.login(key=os.environ['WANDB_API_KEY'])"

echo "bootstrap complete"
```

# Что обычно лежит внутри

```
окружение         venv / conda / poetry / pnpm
зависимости       requirements.txt / pyproject.toml / package.json
данные            scripts/download_data.py с size-check
веса              huggingface-cli download / wget с проверкой sha
кэш               очистка stale кэшей перед прогоном
health-check      по одной команде на каждую интеграцию из CONFIG
```

# bootstrap.md (мульти-скрипт)

```
1. ./scripts/install_deps.sh
2. ./scripts/fetch_data.sh    (≈ 12 ГБ, спросить пользователя)
3. Открыть https://wandb.ai/authorize, скопировать ключ в .env
4. ./scripts/health_check.sh
```
