![Darwin: Self-Evolution for Agents](assets/banner.png)

# Darwin: self-evolving agent config with atomic rollback

Darwin lets a coding agent edit its own configuration (its skills, its knowledge files, its
guidance documents) and makes every one of those edits a single revertable git commit. When the
agent later discovers that one of its own rules is wrong, it can undo exactly that one change
without touching anything else.

There is no approval step. The safety comes from how cheap it is to undo a change, not from
blocking it in advance.

```bash
darwin.sh fix skills/foo/SKILL.md "the --force flag it recommends eats arguments under zsh"
```

That command stages one file, writes one commit, appends one line to a log, and prints the hash.
`git revert <hash>` reverses it and nothing else.

## The problem this solves

Agent setups accumulate written rules: skill files, memory notes, instruction documents. Those
rules go stale, and some are wrong the day they are written. An agent that notices a wrong rule
has two bad options. It can leave the rule alone, in which case the same mistake repeats. Or it
can edit the rule, in which case it might be acting on bad information and make things worse,
with no record of what it changed or why.

The research answer to this is a validation gate. In
[WikiSkill](https://arxiv.org/abs/2608.27454) (Google Research, August 2026), a proposed skill
edit is applied to a candidate skill set, evaluated on a held-out validation split, and accepted
only if the score beats the previous best. Otherwise it is discarded and the skills roll back.

That gate needs three things most people do not have on a personal machine: a repeatable task
set, an automatic scorer, and enough runs for the score to mean something. Without them, an
agent that rewrites its own rules is overfitting to whatever it saw last.

Darwin inverts the trade. Nothing blocks a change. Every change is one `git revert` away.

## How it works

### 1. Blame the line

Before editing, the agent finds out when the wrong claim entered the file:

```bash
git log -S'<the wrong sentence, verbatim>' --oneline -- <file>
grep '<file>' DARWIN.md | tail -5
```

The first command uses git's pickaxe search to find the commit that *introduced* that text, not
the commit that last touched the line. The second checks whether this file has been reverted
before.

### 2. Classify

When the claim entered decides what to do about it:

| What blame shows | Action | Why |
|---|---|---|
| Introduced by one of the last few edits | `revert` | A recent edit was made on bad information |
| Present since creation, environment changed | `scope` | It was right once. Add a version or date boundary |
| Present since creation, wrong then too | `fix` | Correct the claim |
| Upstream wording does not fit this machine | `adapt` | Local adaptation, expected to recur |
| The log shows this was already reverted | stop | Someone tried this and undid it. Read why first |

That last row is the one idea Darwin takes directly from WikiSkill. In the paper, rejected
proposals stay recorded in `skill-impact.md` so the proposer does not suggest them again. A
failed experiment becomes knowledge instead of being forgotten and repeated.

### 3. Edit

A wrong knowledge note gets a paragraph-level retraction rather than deletion. The symptom
description stays, because the symptom is what makes the note findable later. Deleting the whole
note hands back the chance to hit the same problem again.

A wrong skill gets reverted in preference to being edited, because a skill changes agent
behaviour immediately and across every future session.

### 4. Log

```bash
darwin.sh <action> <file> [more files...] <one line explaining why>
```

Multiple files that form one logical change go in one call. Adding a knowledge note means a new
note file plus a line in the index; splitting those across two commits would let a revert leave
a dangling index entry.

Long explanations go on stdin and land in the commit body, where they stay out of the way until
someone runs `git show`.

## What gets recorded

`DARWIN.md` holds one line per change, and is meant to be grepped rather than read:

```
2026-09-04  a1b2c3d  fix     cards/zsh-log.md       root cause said "permissions", actually a shell builtin
2026-09-04  d4e5f6a  revert  skills/bar/SKILL.md    undoes 9c8b7a: the error it relied on came from the sandbox
2026-09-04  b7c8d9e  adapt   skills/baz/SKILL.md    upstream assumes GNU coreutils, this host has BSD
```

The commit body holds the full account, structured around four questions: what changed, what
evidence it was based on, where the previous judgement went wrong, and how far the change
reaches. For an `adapt` the fourth question becomes how to reapply the change after an upstream
update overwrites it.

The evidence line carries the weight. A skill can be broken by an edit made in good faith on
false information, and the only way to tell that later is to have written down what the
information was.

## Install

```bash
git clone https://github.com/Anson-gzy/darwin.git
cp darwin/darwin.sh ~/.agents/darwin.sh   # or wherever your agent config repo lives
chmod +x ~/.agents/darwin.sh
```

`darwin.sh` assumes your agent configuration is a git repository. It refuses to touch anything
outside that repository root.

To make the procedure available to a Claude Code or compatible agent, copy `SKILL.md` into your
skills directory. Then add a few lines to whatever guidance file your agent reads on every
session, pointing at the skill:

```markdown
## Self-evolution

Knowledge notes and skills can be corrected on the spot. Load the `darwin` skill before
editing anything under the config repo. It gives the two facts to gather first, the
classification table, and the command to finish with.
```

Keep that pointer short. The classification table only matters when something is actually being
changed, so it belongs in the skill rather than in a file that loads on every turn.

## The sync guardrail

The failure mode that breaks all of this is a batch commit. If a script runs `git add -A` and
sweeps an evolution edit into a commit alongside unrelated files, `git revert` on that commit
takes the unrelated files with it, and the atomic undo is gone without any error appearing.

`sync-guard.sh` shows the check to add to whatever script commits your config repo. It refuses
to run while files under Darwin's governance have uncommitted changes, and names them:

```
sync: refusing to commit, 2 governed files have not gone through darwin.sh:
 M AGENTS.md
?? cards/new-note.md
```

## Distributing an evolved skill

An edited skill has to reach the agents that read it. Most setups keep a copy of each skill
inside each agent's own directory, which means an evolution lands in one copy and the others
drift away from it.

`sync-skills.sh` keeps one library and links it everywhere:

```bash
./sync-skills.sh                 # link every skill into each agent directory
./sync-skills.sh --update        # pull upstream updates first, with a restore point
```

Links rather than copies, so an evolution takes effect in every agent at once and there is only
ever one file to revert.

Two warnings are built into it, both learned the hard way.

**Never use `skills add <a path inside your source directory> --global` to distribute.** The
skills CLI counts the parent of your source directory as an agent directory too, so the install
target resolves to the source itself. It clears the target before copying from the source, which
means it empties the source, copies from the now empty source, and leaves an empty directory.
One call destroys one skill and exits 0. This is what deleted 562 files in one run here.

**Bulk upstream updates rewrite the whole tree and are not atomic.** The `--update` path commits
a restore point first, then counts complete skills before and after and refuses to distribute if
the count dropped or if more than twenty tracked files were deleted.

After distributing, the script re-checks that the source itself was not modified, because
distribution should only ever create links. If something copied instead of linking, it says so
and points at the recovery command.

The two sync scripts do different jobs. `sync-guard.sh` protects the atomic history on the way
in. `sync-skills.sh` gets the result out to every agent.

## When to stop

High edit frequency is safe as long as reversal stays cheap. The risk is a file that gets
changed back and forth without converging.

```bash
grep -cE "  (revert|fix)  <file> " DARWIN.md
```

Two reverts on one file, or three fixes with the problem still present, means the root cause has
not been found. Editing again continues the loop. Stop and escalate to a human.

`adapt` does not count toward that. Most skills come from upstream repositories and need local
adjustment repeatedly, which is the system working rather than thrashing.

## Compared to other approaches

| | Darwin | WikiSkill | Manual editing |
|---|---|---|---|
| Gate before a change takes effect | none | validation split score | human review |
| Needs a scored task set | no | yes | no |
| Undo granularity | one commit per change | whole skill set per iteration | whatever git history exists |
| Record of rejected changes | `revert` lines in the log | `skill-impact.md` | none |
| Runs unattended | yes | yes | no |
| Evidence of improvement | none | five benchmarks | none |

## Limits

Darwin has no measurement. It cannot tell you that your skills got better, only what changed and
how to undo it. WikiSkill reports average accuracy going from 49.5% to 68.1% across five
benchmarks; Darwin makes no comparable claim and cannot, because it never scores anything.

It also inherits the problem WikiSkill documents but does not solve. Skills evolved against one
model can hurt another. The paper measures a case where skills from a smaller model drop a
larger model's spreadsheet accuracy from 50.5% to 18.1%, because the smaller model's workarounds
constrain the larger one. Nothing in Darwin detects that. Writing the applicability conditions
into the rule itself is the only defence available here.

If you do have a repeatable scored task set, use a real gate instead. `srlabs/skillforge` is a
reimplementation of the WikiSkill loop for Claude Code, and its README makes the point that
matters: a weak scorer teaches the loop to produce agents that claim success.

## License

MIT
