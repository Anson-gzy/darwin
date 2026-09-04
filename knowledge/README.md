# Agent knowledge base

This directory defines the note format and storage rules for the knowledge subsystem. While
Darwin manages change lifecycle through atomic git commits, this subsystem defines how facts are
organized and located. Correcting a note is covered in the repository README.

## Files in this directory

Three files ship at this path:

- `README.md`: reference documentation for the knowledge subsystem.
- `AGENTS.md`: operational rules an agent follows when inspecting, creating, or editing notes.
- `INDEX.md`: the index template.

This directory provides templates and rules. Storage locations such as `cards/` and `refs/` are
created and populated by the user as facts accumulate.

## Three layers and storage boundaries

Information is divided across three locations according to what kind of data it represents:

| Layer | Holds | Retrieval mechanism |
|---|---|---|
| `refs/` | Identifiers that cannot be deduced: machines, hosts, account and device IDs | Matched by an index line. Stored in a private repository |
| `cards/` | Facts and pitfalls: what is true, and the cost paid to find out | Matched by an index line |
| `skills/` | Procedures: how to perform a task | Loaded directly by the agent harness |

The division between notes and skills prevents duplicated documentation. Notes record facts and
pitfalls. Skills record procedures. Each piece of information belongs on one side only. If a
procedure is repeatedly restated in notes, it should be extracted into a dedicated skill.

Skills are omitted from `INDEX.md` because the agent harness loads their descriptions
automatically. An index miss means only that no card or reference file matches the current task.
It does not indicate an absence of knowledge, because an active skill may handle the task
entirely.

## Index lookup without search

Retrieval operates through a single flat file, `INDEX.md`, containing one line per note. This
file is loaded into context at the start of every session.

When an incoming task matches a specific index line, the agent opens only that file. When no
line matches, the agent moves on immediately without searching. The system contains no separate
retrieval step: no query embeddings, no vector database, and no candidate ranking.

Standard agent memory implementations insert an explicit search step: embed the query, rank
candidates, and inject top results. That approach adds a network round trip to every task and
selects files based on proximity in vector space, which often diverges from actual relevance.

For a collection of dozens of notes, the full index fits directly in the context window as a
list of one-line summaries. The agent reads it like a table of contents. Matching relies on
model judgment, which functions more reliably than tuning similarity score thresholds.

This design involves an explicit trade-off. Once a knowledge base expands into several hundred
notes, the index becomes too large to carry in context, and a dedicated retrieval system becomes
necessary. Below that scale, search infrastructure is pure overhead.

## Note structure and index entries

Individual cards follow a standardized template:

```markdown
---
title: <claim or finding, stated as a proposition rather than a topic>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD, added when revised>
---

Symptom: <observed behavior, including verbatim error text and misleading initial appearances>

Root cause: <underlying mechanism. This is an inference, and the part most likely to fail later>

Fix: <remediation steps or commands>

    <command or code modification>

Verify: <concrete test confirming the issue is resolved>
```

Each card maps to one line in `INDEX.md`:

```markdown
- [<slug>](cards/<slug>.md): <symptom in recognisable words>. <the fix, in a clause>
```

Index lines must describe the symptom rather than an abstract topic. A line reading 'notes about
logging' never matches an incoming task. A line that includes the error message, the intuitive
misinterpretation, and the direct fix matches immediately when an agent hits the problem.

## Reliability asymmetry across sections

The sections of a card fail at different rates.

The symptom records an observation, which is almost always correct. The root cause records an
inference, which is where errors originate. The fix can remain effective even when the
attributed root cause is incorrect, allowing flawed explanations to persist.

Because of this asymmetry, a note is rarely wrong in its entirety. When editing an existing
entry, default to revising the root cause while leaving the symptom intact. The mechanics of
classifying, editing, and logging these corrections are covered in the repository README.

## What to record and what to omit

Notes capture hard-won facts, pitfalls, and verified workarounds that would otherwise require
repeated investigation.

Exclude the following categories:

- Information already recorded by the target project: source layout, commit history, and
  instructions stored in project documentation.
- Ephemeral context relevant only to the current conversation.
- Information the model already knows.
- Speculative claims that lack verification.

Credentials, tokens, and secret keys must never enter the repository.

Identifiers require equal caution. Device IDs, internal hostnames, account numbers, and private
directory paths frequently accumulate in technical notes. These identifiers are the primary
reason a working knowledge base should remain in a private repository.

If you export or publish a subset of notes, verify every file by scanning for identifiers
instead of relying on an exclusion list compiled from memory. Memory-based lists and automated
scans produce different selections, and the scan is the reliable method.
