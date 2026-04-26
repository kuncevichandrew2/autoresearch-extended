# Bootstrap recipes

bootstrap.sh — one script, idempotent, re-runnable. Artifacts in .gitignore. Before downloading > 100 MB or making system-level changes — ask the user.

bootstrap.md — when multiple scripts or manual steps are needed (computer-use, manual auth).

## Minimal bootstrap.sh template

```bash
#!/usr/bin/env bash
set -euo pipefail

python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

python -c "import wandb, os; wandb.login(key=os.environ['WANDB_API_KEY'])"

echo "bootstrap complete"
```

## What typically goes inside

```
environment       venv / conda / poetry / pnpm
dependencies      requirements.txt / pyproject.toml / package.json
data              scripts/download_data.py with size-check
weights           huggingface-cli download / wget with sha verification
cache             clear stale caches before run
health-check      one command per integration from CONFIG
```

## bootstrap.md (multi-script)

```
1. ./scripts/install_deps.sh
2. ./scripts/fetch_data.sh    (≈ 12 GB, ask user first)
3. Open https://wandb.ai/authorize, copy key to .env
4. ./scripts/health_check.sh
```
