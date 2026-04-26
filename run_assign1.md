# Запуск autoresearch на cs336-assignment1 (RunPod)

Ты root в NGC-контейнере, `/workspace` уже существует, CUDA/PyTorch есть.
Терминал в JupyterLab переживает закрытие вкладки — tmux не нужен.

## 1. Установить uv и claude

```sh
curl -LsSf https://astral.sh/uv/install.sh | sh
curl -fsSL https://claude.ai/install.sh | bash
export PATH="$HOME/.local/bin:$PATH"
```

## 2. Клонировать репозитории и поставить skill

```sh
cd /workspace
git clone https://github.com/kuncevichandrew2/autoresearch-extended.git
git clone https://github.com/kuncevichandrew2/cs336-assignment1.git
mkdir -p ~/.claude/skills
cp -r autoresearch-extended/.claude/skills/autoresearch ~/.claude/skills/
```

## 3. Зависимости и данные TinyStories (~2GB)

```sh
cd /workspace/cs336-assignment1
uv sync
mkdir -p data && cd data
wget https://huggingface.co/datasets/roneneldan/TinyStories/resolve/main/TinyStoriesV2-GPT4-train.txt
wget https://huggingface.co/datasets/roneneldan/TinyStories/resolve/main/TinyStoriesV2-GPT4-valid.txt
cd ..
```

## 4. Проверить GPU

```sh
nvidia-smi
uv run python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

Если `CUDA driver is too old (found version 12080)` — torch из PyPI собран под cu13, а драйвер pod-а 12.8. Пересобрать torch под cu128:

```sh
uv pip install --reinstall "torch~=2.11.0" --index-url https://download.pytorch.org/whl/cu128
```

Для драйвера 12.6 — замени `cu128` на `cu126`. Проверить версию драйвера: `nvidia-smi` (верхняя строка, `CUDA Version:`).

## 5. Запустить Claude Code

```sh
cd /workspace/cs336-assignment1
claude
```

При первом запуске `/login` — токен сохранится в `~/.claude/`.

## 6. Промпт для вставки

```
run autoresearch

target: train.py (гиперпараметры в блоке # ---- config ----)
metric: val_loss на TinyStories (minimize)
eval_command: uv run python train.py
parse_method: regex:VAL loss ([0-9.]+)   # последнее совпадение = финальный val_loss
scope: только константы в блоке `# ---- config ----` в train.py; model.py/training.py/bpe.py/tokenizer.py не трогать
constraints:
  - MAX_ITERS: подобрать так, чтобы один прогон шёл 5–10 минут на текущей GPU
  - VOCAB_SIZE: не менять после того как токенизатор закэширован (data/vocab.pkl + data/merges.pkl)
  - CONTEXT_LENGTH: менять можно свободно; токенизированный кэш (data/train.npy/valid.npy) от него не зависит
```

Дальше agent сам пройдёт setup → bootstrap → baseline → loop.
