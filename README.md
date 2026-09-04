![Darwin: Self-Evolution for Agents](assets/banner.png)

# Darwin

Darwin is a self-evolution mechanism that lets AI coding assistants safely modify their own
configuration.

```bash
darwin.sh fix knowledge/cards/foo.md "root cause was wrong, actually shell builtin shadowing"
```

The command stages only this one file, writes one commit, appends one line to the log, and
prints the short hash. Running `git revert <hash>` reverses that specific change without
touching unrelated files.

Safety does not come from pre-approval. It comes from low undo cost: every modification is an
atomic commit that `git revert` can undo precisely. Darwin manages two categories of files, and
both carry equal weight:

1. **Skills**: Workflow definitions that specify how to perform a task. An error in a skill
   immediately alters agent behavior across every subsequent session.
2. **Knowledge notes**: Records of facts and pitfalls that document what is true and what it
   cost to find out. An error here causes silent misdirection without triggering any error
   message.

## Why there is no validation gate

In the Google Research WikiSkill paper (arXiv 2608.27454, August 2026), proposed skill
modifications are applied to a candidate skill set, evaluated against a held-out validation
split, and accepted only when the score exceeds the historical best. Otherwise, the change is
discarded and rolled back. Across five benchmarks, that loop raised average accuracy from 49.5%
to 68.1%.

Operating a validation gate requires three prerequisites: a repeatable task set, an automated
scorer, and sufficient execution budget. Personal development environments lack all three.
Darwin inverts the design: it does not intercept changes in advance, but keeps every
modification exactly one `git revert` away.

## Four-step workflow

Every self-evolution change follows an explicit four-step sequence before touching files:

### 1. Blame the line

Gather two historical facts before modifying any file:

```bash
git log -S'<the wrong sentence, verbatim>' --oneline -- <file>
grep '<file>' DARWIN.md | tail -5
```

The pickaxe search (`-S`) locates the commit that introduced the text instead of the commit that
last touched the line. The grep command checks whether the file was reverted in an earlier
session. Modifying a file without knowing both facts risks repeating an error that was already
diagnosed and undone.

### 2. Classify

Blame output maps to one of five mutually exclusive actions:

| Blame result | Action | Policy |
|---|---|---|
| Introduced by one of the last few edits | `revert` | The previous change relied on incorrect information |
| Present since creation, environment changed | `scope` | Add a version or date boundary; preserve existing content |
| Present since creation, wrong when written | `fix` | Correct the inaccurate claim |
| Upstream wording does not fit this host | `adapt` | Adjust for local platform differences |
| History shows this was previously reverted | Stop | Inspect the prior commit message before taking any action |

### 3. Act

Skills and knowledge notes demand different handling during this step:

- **Skills require revert before direct edits.** A modified skill immediately alters agent
  behavior across all future sessions. When a skill misbehaves, revert the introducing commit.
  Edit a skill directly only when the entire procedure is fundamentally inapplicable to the
  local environment.
- **Knowledge notes receive paragraph-level retractions (`retract`).** Keep the file and keep
  its entry in `INDEX.md`. Rewrite only the inaccurate paragraph: "previously claimed X, which
  does not hold, because Y". The symptom description must remain intact because it serves as the
  retrieval key. Deleting the entire note discards the record of the failure and guarantees that
  future agents will encounter the same pitfall again.

Symptoms represent direct observations and are almost always correct. Root causes represent
inferences and constitute the portion that fails. A practical workaround often succeeds even
when the attributed root cause is mistaken, allowing false diagnoses to persist undetected.
Because an entire note is almost never completely wrong, edits should target only the root cause
paragraph by default.

### 4. Log

Record the modification through `darwin.sh`:

```bash
darwin.sh <action> <file> [more files...] <one-line-why>
```

Pass all files that belong to a single logical change in one invocation. For example, creating a
knowledge note requires both the new note file and its corresponding line in `INDEX.md`.
Committing them separately allows a subsequent revert of the note file to leave behind a
dangling index reference.

Detailed context can be piped through standard input:

```bash
cat << 'EOF' | darwin.sh fix knowledge/cards/foo.md "root cause was wrong, actually shell builtin shadowing"
Investigation showed that /usr/bin/log remained accessible.
The failure occurred because zsh defines a builtin named log.
The previous note incorrectly blamed macOS permissions.
EOF
```

Piped input enters the commit body, keeping the primary log compact while preserving full
diagnostic context for future inspection.

## What gets recorded in the log

`DARWIN.md` maintains an append-only log with five columns per entry: date, commit hash, action,
target path, and a one-line explanation.

```
2026-09-01  a1b2c3d  new     cards/zsh.md +1   zsh builtin shadows /usr/bin/log; note and index line
2026-09-02  d4e5f6a  adapt   skills/deploy.md  upstream assumes GNU coreutils, this host has BSD
2026-09-03  b7c8d9e  fix     cards/zsh.md      root cause was shell builtin shadowing instead of permissions
2026-09-03  c9d0e1f  revert  skills/deploy.md  undoes d4e5f6a: failure was a stale PATH instead of BSD tools
2026-09-04  e2f3a4b  scope   cards/driver.md   empty-tree finding applies to Safari; Chrome untested
```

The one-line reason must answer a specific question depending on the action:

- `fix`: Identify what the original claim got wrong, preventing a later agent from reintroducing
  the error.
- `revert`: Name the undone commit hash and state why the original evidence was false. Recording
  only that a commit was reverted invites the next agent to repeat the same edit using the same
  misleading evidence.
- `adapt`: State the concrete environment discrepancy that required the adjustment.
- `scope`: Define the new boundary or condition.
- `retract`: Identify which paragraph was withdrawn.

Full narratives belong in the commit body, retrieved with `git show <hash>` only when
specifically needed. Darwin adopts one specific mechanism from WikiSkill: rejected modifications
remain permanently recorded in the log so that an identical mistake is not proposed again weeks
later.

## Knowledge notes subsystem

The `knowledge/` directory stores structured records of hard-won facts and operational pitfalls.
A flat index file (`knowledge/INDEX.md`) containing one summary line per note serves as the
entire retrieval mechanism. There are no vector databases, no text embeddings, and no
multi-stage retrieval workflows. The full index loads into the agent context at the start of
each session. If an index line matches the current task, the agent opens that single file; if
nothing matches, execution proceeds immediately without secondary search. Additional
documentation lives in `knowledge/README.md`.

## Skill distribution

Different agent CLIs expect skills in separate directories. The `sync-skills.sh` script symlinks
a single canonical skill repository into each agent location, ensuring that a modification takes
effect everywhere simultaneously while keeping only one file to roll back. The script contains
two safety checks: protecting against a package CLI that empties its source directory while
exiting successfully, and safeguarding against non-atomic bulk upstream updates by verifying
tree integrity against a pre-update checkpoint. Implementation details are documented in the
script comments.

## Protecting atomic history

Standard configuration management scripts often use `git add -A` before pushing updates. That
pattern breaks Darwin silently: an uncommitted evolution edit gets bundled into a batch commit
alongside unrelated files. Later, running `git revert` on that commit forces the unrelated files
to roll back as well.

The `sync-guard.sh` script inspects governed paths before any batch commit runs. If changes
exist in skills, guidance files, or knowledge notes that did not pass through `darwin.sh`, the
script blocks the commit and lists the offending files.

## When to stop

Editing frequently remains safe only when changes converge. Inspect the log for thrashing:

```bash
grep -cE "  (revert|fix)  <file> " DARWIN.md
```

If the log records two reverts on the same file, or three fixes while the issue persists, the
root cause remains unidentified. Continuing to edit at that stage produces circular
modifications. Stop and escalate the issue to a human operator.

The `adapt` action does not count toward this threshold. Adapting upstream skills to local
environment constraints is routine maintenance that occurs repeatedly.

## Installation

Clone the repository and install the helper script into your configuration repository:

```bash
git clone https://github.com/Anson-gzy/darwin.git
cp darwin/darwin.sh ~/.agents/darwin.sh
chmod +x ~/.agents/darwin.sh
cp darwin/SKILL.md ~/.agents/skills/darwin/SKILL.md
```

Add a brief reference to whichever instruction file loads into context on every session:

```markdown
## Self-evolution

Knowledge notes and skills can be corrected on the spot. Load the `darwin` skill
before editing anything in this configuration repository.
```

Keep this entry brief. Detailed classification criteria are necessary only when actively
modifying files, and should not consume context window capacity during routine conversation
turns.

## Limitations

Darwin performs no measurement. It documents what changed and provides an undo path, but cannot
prove that configuration quality improved. While WikiSkill reported average accuracy moving from
49.5% to 68.1% across five benchmarks, Darwin provides no comparable metrics because it never
scores performance.

Darwin also inherits an unresolved problem documented in the WikiSkill research: skills evolved
against one model can degrade the performance of another. The paper measured a case where skills
produced by a smaller model dropped a larger model's spreadsheet accuracy from 50.5% to 18.1%,
because the smaller model's workarounds constrained the capabilities of the larger one. Darwin
cannot detect cross-model degradation; the only available defense is documenting explicit
applicability conditions directly within the rule text.

Environments equipped with repeatable, scored task sets should deploy a genuine validation gate.
The `srlabs/skillforge` project reimplements the WikiSkill evaluation loop for Claude Code, and
its documentation highlights the primary hazard: a weak scorer teaches the self-evolution loop
to produce agents that merely claim success.

## License

MIT
