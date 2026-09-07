---
name: darwin
description: Darwin, the self-evolution loop for an agent configuration repository. Knowledge notes, skills and guidance files can be edited freely because every change becomes one atomic revertable commit instead of a pre-approved one. USE WHEN a knowledge note or skill gave guidance that turned out wrong or outdated, when an upstream skill needs adapting to this environment, when recording user-directed rules, or before editing anything in the agent config repo.
---

# Darwin: Change Freely, Keep the Undo

WikiSkill can let a model rewrite its own skills because it gates every change on a validation
split: the edit runs against held-out tasks and is kept only if the score improves. In personal
development environments, there is no validation set, no repeatable scored task, and no automated
scorer.

Darwin inverts the trade: **nothing blocks a change in advance, and every change sits exactly one
atomic `git revert` away.**

That trade only holds while changes are genuinely atomic. The logging step is not bookkeeping;
it is the safety mechanism.

## The Dual Pathways: Silent vs User-Directed

Darwin supports two operational pathways:

1. **Silent / Ambient Path (`src=auto`)**:
   Autonomous end-of-session reflection. Triggered automatically without prompting the user when:
   - You had to bypass an upstream skill's documented steps to succeed -> `adapt`.
   - A knowledge card or skill gave wrong/outdated guidance -> pickaxe blame -> `revert`, `scope`, `fix`, or `retract`.
   - You solved a problem after >= 2 failed attempts with non-obvious knowledge -> capture a new card.
   Run: `darwin.sh <action> <file...> <one-line-why> < /dev/null`.
2. **User-Directed Path (`src=user`)**:
   Explicitly commanded by the user ("remember this", "this card is wrong", "update this rule").
   Run: `darwin.sh --user <action> <file...> <one-line-why> < /dev/null`.
   **The Authority Rule**: Future agents are strictly forbidden from reverting a `src=user` commit
   without explicit human consent.

---

## 1. Blame the Line

Gather two historical facts before modifying any file:

```bash
git -C ~/.agents log -S'<the wrong sentence, verbatim>' --oneline -- <file>
grep '<file>' ~/.agents/DARWIN.md | tail -5
```

Pickaxe search (`-S`) finds the commit that *introduced* the text, not the one that last touched the
line. The grep command reveals whether a prior revert touched this file.

**Done when:** you can name the commit that introduced the claim, and you know whether a prior
revert touched this file. Without both facts you cannot classify accurately.

## 2. Classify

| What blame shows | Action | Policy |
|---|---|---|
| Introduced by one of the last few edits | `revert` | A recent change was made on bad information |
| Present since creation, environment moved | `scope` | Add a version or date boundary, keep existing content |
| Present since creation, wrong when written | `fix` | Correct the inaccurate claim |
| Upstream wording does not fit this host | `adapt` | Adjust for local platform differences |
| History shows this was already reverted | **Stop** | Read why. Someone tried this and undid it. Escalate to user |

**Done when:** you have picked exactly one action and can explain why adjacent actions were rejected.

## 3. Edit

### Knowledge Notes
A wrong knowledge note receives a paragraph-level `retract`:
- Keep the file, keep its `INDEX.md` line.
- Rewrite only the inaccurate paragraph as: *"previously claimed X, which does not hold, because Y"*.
- **Always keep the symptom description**: The symptom is the retrieval key. Deleting the entire note
  destroys the record of the failure and guarantees future agents will fall into the same pitfall again.
- **Anti-fragmentation**: Before creating a new card, run `grep -i <topic> INDEX.md`. Extend or
  refine an existing card instead of scattering fragmented notes.

### Skills
A wrong skill gets reverted in preference to being edited. A bad edit alters behavior across every
future session. Edit a skill directly only when the entire procedure is fundamentally inapplicable to
the local host.

**Done when:** the edit stays strictly inside what the chosen action allows.

## 4. Log

```bash
~/.agents/darwin.sh [--user] <action> <file> [more files...] <one line explaining why> < /dev/null
```

> [!NOTE]
> Always pipe `< /dev/null` or verify stdin when executing in non-interactive agent subshells to
> ensure the command never blocks.

Darwin stages only the files you explicitly name and commits them alone.
**Pass every file belonging to one logical change in a single call.**
Adding a knowledge note requires both the note file and its line in `INDEX.md`; committing them
separately allows a future revert of the note to leave behind a dangling index entry.

`sync-guard.sh` protects this invariant: it rejects batch commits if governed files bypassed
`darwin.sh`.

## What the One-Line Reason Must Carry

`DARWIN.md` maintains an append-only, 6-column log (`date / commit / src / action / target / one-line reason`).
Each action requires a specific question to be answered in its one-line reason:

- `fix`: What the claim got wrong, preventing a later agent from reintroducing the error.
- `revert`: Which commit hash was undone, and why its evidence was false. Recording only "reverted X"
  invites the next agent to repeat the edit using the same misleading symptoms.
- `adapt`: What environment fact forced the change, so it can be re-applied after upstream updates.
- `scope`: What the new boundary or condition is.
- `retract`: Which paragraph was withdrawn and why.

## Thrash Detection

Editing frequently remains safe only when changes converge. Inspect the log for thrashing:

```bash
grep -cE "  (revert|fix)  <file> " ~/.agents/DARWIN.md
```

Two `revert`s on one file, or three `fix`es with the problem still present, indicates that the root
cause has not been found and further editing will cause circular churn. Stop and escalate to the user.

`adapt` entries do not count toward this threshold: adjusting upstream skills to local environment
differences is normal ongoing maintenance.
