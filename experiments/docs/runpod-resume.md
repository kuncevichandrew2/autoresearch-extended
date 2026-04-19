# RunPod resume — continue autoresearch after pod loss

Pods are ephemeral: if the container is killed, `~/a1/autoresearch/`
(state, results, experiment notes) is gone unless you pushed it.
This doc is the full paste-sequence to bring a fresh pod back to the
point where `run autoresearch` will resume or restart.

## 0. Rent the pod

RunPod → Deploy → **B200**, PyTorch 2.x template, ≥100 GB disk.
Open a web terminal once it's running.

## 1. System bootstrap (one block, copy-paste)

```sh
# Node LTS (RunPod images don't ship npm)
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs git

# Claude Code + interactive login
npm i -g @anthropic-ai/claude-code
claude login   # open the printed URL in your laptop browser, paste the code back

# uv (needed by the assignment repo)
curl -LsSf https://astral.sh/uv/install.sh | sh
. $HOME/.local/bin/env
```

## 2. Install the experiment-loop skill (HTTPS — no SSH key on pod)

```sh
mkdir -p ~/.claude/skills
git clone https://github.com/kuncevichandrew2/autoresearch-extended.git \
  ~/.claude/skills/experiment-loop-repo
ln -s ~/.claude/skills/experiment-loop-repo/experiment-loop \
  ~/.claude/skills/experiment-loop
```

## 3. Clone the assignment and sync deps

```sh
git clone https://github.com/stanford-cs336/assignment1-basics.git ~/a1
cd ~/a1 && uv sync
# download OpenWebText into ~/a1/data/ per the assignment README
```

## 4a. Fresh start (no prior state to restore)

```sh
cd ~/a1
claude
# then in Claude:
#   run autoresearch
# answer the 4 questions per experiments/docs/cs336-a1-quickstart.md §3
# paste the hard-constraints block at the "anything I misread?" prompt
# approve the printed config.md
```

## 4b. Resume from a prior run (state was pushed to a branch)

If you had previously been pushing `~/a1/autoresearch/` to a side
branch (see §5), restore it before launching Claude:

```sh
cd ~/a1
git fetch origin
git checkout autoresearch-state -- autoresearch/   # or whichever branch you used
ls autoresearch/                                    # sanity check: state.md, results.tsv, experiments/
claude
# then in Claude:
#   continue autoresearch        # skill sees config.md + state.md, resumes develop
```

Skill routing (from `experiment-loop/SKILL.md`):

- `config.md` present and no `<FILL IN>` → skips setup, goes straight to develop.
- `state.md` says `baseline not run` → reruns baseline via develop.
- Otherwise loops develop/reflect until `max_experiments` or `stop_after_plateau`.

## 5. Make future pod loss cheap — push state periodically

Run this once to create a parallel branch that tracks only
`autoresearch/` (so you don't pollute the assignment history):

```sh
cd ~/a1
git checkout --orphan autoresearch-state
git rm -rf --cached .
git add autoresearch/
git commit -m "autoresearch: initial state snapshot"
git remote add mine https://github.com/kuncevichandrew2/a1-autoresearch-state.git  # create this repo on GitHub first
git push -u mine autoresearch-state
git checkout main   # back to working branch
```

Then in another shell, snapshot every ~10 minutes while the loop runs:

```sh
cd ~/a1
while true; do
  git checkout autoresearch-state -- autoresearch/ 2>/dev/null || true
  git add autoresearch/
  git -c user.email=bot@local -c user.name=autoresearch commit \
    -m "snapshot $(date -u +%H%MZ)" --allow-empty >/dev/null
  git push mine autoresearch-state >/dev/null 2>&1
  sleep 600
done
```

Alternative: `rsync ~/a1/autoresearch/ user@host:~/backup/` if you have
an always-on machine. Cheaper than a second repo, same effect.

## 6. Monitor (another shell on the same pod)

```sh
tail -f ~/a1/autoresearch/results.tsv
cat  ~/a1/autoresearch/state.md
```

## 7. When done — verify + submit

```sh
cd ~/a1
BEST_SHA=$(grep -E '^best' autoresearch/state.md | awk '{print $NF}')
git checkout $BEST_SHA
uv run train.py   # verify reproducibility
# then package as a uv project and open a PR to assignment1-basics-leaderboard
```

## Gotchas that bit us before

- `npm: command not found` → step 1 installs Node from NodeSource.
- `git@github.com: Permission denied (publickey)` → every clone in this
  doc uses HTTPS; the pod has no GitHub SSH key.
- `uv: command not found` after pod restart → re-source
  `~/.local/bin/env` (step 1) in every new shell, or add it to
  `~/.bashrc`.
- State lost on pod kill → §5. No backups = no recovery.
