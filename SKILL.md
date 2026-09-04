---
name: darwin
description: Darwin, the self-evolution loop for this machine's agent config. Knowledge notes, skills and guidance files can be edited freely because every change becomes one atomic revertable commit instead of a pre-approved one. USE WHEN a knowledge note or skill just gave guidance that turned out wrong or outdated, when an upstream skill needs adapting to this environment, or before editing anything in the agent config repo.
---

# Darwin: change it freely, keep the undo

WikiSkill can let a model rewrite its own skills because it gates every change on a validation
split: the edit runs against held-out tasks and is kept only if the score improves. There is no
validation set here, no repeatable scored task, no scorer. So Darwin inverts the trade. Nothing
blocks a change, and every change sits one revert away.

That trade only holds while changes are genuinely atomic. The logging step is not bookkeeping,
it is the safety mechanism.

## 1. Blame the line

Two facts before touching anything:

```bash
git -C ~/.agents log -S'<the wrong sentence, verbatim>' --oneline -- <file>
grep '<file>' ~/.agents/DARWIN.md | tail -5
```

Pickaxe search finds the commit that *introduced* the text, not the one that last touched the
line. The grep says whether this file has already been reverted before.

**Done when:** you can name the commit that introduced the claim, and you know whether a prior
revert touched this file. Without both facts you cannot classify, and classifying is what
decides whether editing is even the right move.

## 2. Classify

| What blame shows | Action |
|---|---|
| Introduced by one of the last few edits | `revert` the commit. A recent change was made on bad information |
| Present since creation, environment moved | `scope`: add a version or date boundary, keep the content |
| Present since creation, wrong then too | `fix` the claim |
| Upstream wording does not fit this machine | `adapt` it |
| The log shows this was already reverted | **stop.** Read why. Someone tried this and undid it |

**Done when:** you have picked exactly one action and can say why it is not the neighbouring one.

## 3. Edit

A wrong **knowledge note** gets a paragraph-level `retract`: keep the file, keep its index line,
rewrite the wrong part as "previously claimed X, which does not hold, because Y". Keep the
symptom description. The symptom is the retrieval key, and deleting the whole note hands back
the chance to hit the same problem again. Symptoms are observations and are usually right; root
causes are inferences and are what turn out wrong. Default to editing the root cause alone.

A wrong **skill** gets reverted in preference to being edited. There are many skills here, and a
bad edit to one changes behaviour across every future session. Edit directly only when the whole
skill is wrong for this environment.

**Done when:** the edit stays inside what the chosen action allows.

## 4. Log

```bash
~/.agents/darwin.sh <action> <file> [more files...] <one line explaining why>
```

It stages only the files you name and commits them alone, which is what makes `git revert`
atomic. **Pass every file belonging to one logical change in a single call.** Adding a knowledge
note means the note plus its index line; committing those separately lets a revert leave a
dangling index entry.

`sync.sh` refuses any evolution change that bypassed `darwin.sh`, because it commits with
`git add -A` and would sweep unrelated files into the same commit, making a later revert take
them along.

**Done when:** the command printed a hash and its log line.

## What the one line has to carry

One line in the log, grepped before editing. The full account goes in the commit body and is
read with `git show <hash>` only when someone goes looking. Each action answers a different
question:

- `fix`: what the claim got wrong, so a later agent does not restore it
- `revert`: which hash was undone, and why the evidence behind it was false. "Reverted it" alone
  means the next agent acts on the same false evidence again
- `adapt`: which environment fact forced the change, so it can be reapplied after an upstream
  update overwrites it
- `scope`: what the new boundary is
- `retract`: which paragraph was withdrawn

The commit body answers four questions: what changed, what evidence it rested on, where the
previous judgement went wrong, and how far the change reaches. For `adapt` the fourth becomes
how to replay it after an upstream overwrite, because `adapt` serves recovery rather than
rollback.

## Thrash

The one real risk of editing often is the same spot being changed back and forth. Check during
review rather than every time:

```bash
grep -cE "  (revert|fix)  <file> " ~/.agents/DARWIN.md
```

Two `revert`s on one file, or three `fix`es with the problem still present, means the root cause
has not been found and another edit continues the loop. Stop and escalate to the user.

`adapt` does not count. Most skills come from upstream repositories and need local adjustment
repeatedly, which is the system working rather than thrashing.
