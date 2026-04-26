#!/usr/bin/env bash
# Идемпотентно. Перезапускаемо. Артефакты в .gitignore.
# Перед загрузкой > 100 МБ или системной правкой — спросить пользователя.
# Заморожен после прохода experiments/000.

set -euo pipefail

# python -m venv .venv
# source .venv/bin/activate
# pip install -r requirements.txt
# python scripts/download_data.py

# health-check каждой интеграции из CONFIG.md
# python -c "import wandb, os; wandb.login(key=os.environ['WANDB_API_KEY'])"

echo "bootstrap complete"
