# setup

One-time collaborative setup. Runs the first time the skill is invoked in
a project. Exit this phase only after a baseline has been run and logged.

> If `./autoresearch/config.md` already exists with no `<FILL IN>` tokens,
> skip setup and go to **develop**.

## Working principle

Do not assume and do not hide confusion. If multiple interpretations of the
target, eval, or metric exist, **present them and ask** — never pick
silently. Surface tradeoffs. Simpler framings first. This is the one phase
where questions are cheaper than wrong defaults.

## Protocol

1. **Elicit target files and scalar metric.** Ask: "Which file(s) should I
   edit?" and "Which scalar are we optimizing, and should it go up or
   down?" Record verbatim.

2. **Write `./autoresearch/context.md` collaboratively.** Propose this
   structure if the user is vague:
   - Project overview (2–4 sentences).
   - What we're optimizing and why.
   - **Hard constraints** — rules the agent must never break (e.g. "do
     not disable safety tests", "never hard-code the eval split",
     "model params stay under 10M"). These are the primary defense
     against metric gaming.
   - What's already been tried.
   - Domain knowledge and pointers.

3. **Decide metric source.** One of:
   - `human` — user writes the value into a file.
   - `code` — the eval program prints / emits it.
   - `llm-judge` — a judge model scores output; parse its JSON.

4. **Design the eval pipeline together.** Walk through each step out loud:
   what runs, where the scalar comes from, how failures surface. Collapse
   to ONE shell command. If multi-step, scaffold `eval.sh` (or
   `eval.py`) at the project root WITH the user. Typical shapes:
   - `uv run train.py` (single command, prints summary).
   - `pytest bench.py -q` (single command, regex the line).
   - `bash eval.sh` (multi-step: build → run → screenshot → judge →
     write `metric.txt`).

5. **Pick the parse method.** Defaults by source:
   - `code` → `summary_block` (a fenced JSON block) or `regex:<pattern>`.
   - `llm-judge` → `json_path:$.score` on judge output.
   - `human` → `file:<path>`.
   - Any source can fall back to `exit_code` (0 = pass, nonzero = fail).
   Run the eval once on current code and verify the parser against real
   output before proceeding.

6. **Identify auxiliary integrations.** Fill `./autoresearch/auxiliary.md`.
   Per integration: name, purpose, files involved, how it's invoked
   (usually from `eval.sh`), required **API key names and where to set
   them** (never store values). Include one worked example (W&B, ~20
   lines) in the template.

7. **Draft `./autoresearch/config.md`.** Two sections:
   - `## Fix` (frozen after setup): `target:`, `eval_command:`,
     `timeout_sec:`, `metric_name:`, `metric_direction: min|max`,
     `metric_source: human|code|llm-judge`,
     `parse_method: summary_block|regex:...|json_path:...|file:...|exit_code`.
     Every file not listed in `target` is implicitly read-only and may
     not be modified.
   - `## Changeable` (mutable between runs): `reflect_every: 5`,
     `reflect_on_plateau: 3`, `max_experiments: unlimited`,
     `stop_after_plateau: never`.

8. **Show everything and get explicit approval.** Print the full
   `config.md`, the `eval_command`, the metric direction, and the parser.
   Ask: "Approve? (yes/no)". Do not proceed on silence.

9. **Run the baseline.** Execute the eval command once unmodified. Parse
   failure → stop, show stderr, fix with the user, try again. Success →
   capture the metric as `best` and `last`.

10. **Initialize project state.** Create:
    - `./autoresearch/state.md` with empty strategy sections, mechanical
      sections seeded: `best = <baseline>`, `last = <baseline>`,
      `experiments_since_reflection = 0`, `no_improvement_streak = 0`,
      first idea: `Run baseline.` (already done — mark it).
    - `./autoresearch/results.tsv` with header
      `experiment\tcommit\tmetric\tdelta\tstatus\tdescription\ttimestamp\ttags`
      and row `000`.
    - `./autoresearch/experiments/000-baseline.md` (hypothesis: none;
      changes: none; result: baseline value).

11. **Print** `Setup complete. Baseline <metric_name>=<value>.` and hand
    control to the develop phase on the next invocation.

## After setup

Everything outside `config.target` is **read-only**. That includes the
`## Fix` section of `config.md`, any scaffolded `eval.sh` / `eval.py` /
eval folder, `context.md`, `auxiliary.md`, and every other file in the
repo. Edits to them are scope violations. If the user needs to change
the eval, they must re-enter setup explicitly.
