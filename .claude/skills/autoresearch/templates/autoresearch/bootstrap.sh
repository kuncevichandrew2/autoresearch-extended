#!/usr/bin/env bash
# Idempotent. Re-runnable. Artifacts in .gitignore.
# Before downloading > 100 MB or making system-level changes — ask the user.
# Frozen after experiment 000 passes.

set -euo pipefail

# python -m venv .venv
# source .venv/bin/activate
# pip install -r requirements.txt
# python scripts/download_data.py

# health-check each integration from CONFIG.md
# python -c "import wandb, os; wandb.login(key=os.environ['WANDB_API_KEY'])"

echo "bootstrap complete"
