# Knowledge Base Rules

One note per file. `INDEX.md` is the entire retrieval mechanism.

## Reading

`INDEX.md` is in context already. If a line matches the task, open that one file. If no line
matches, move on. There is no second search step and no fallback scan of `cards/`.

## Writing

Write a note when something cost real effort to work out and would cost it again: a pitfall, a
verified workaround, a fact the model would not already know, or a correction from the user.
Write it when you find it rather than waiting for it to happen a second time.

**Before creating a new card, `grep -i <topic>` `INDEX.md`**:
If an existing card covers the domain or topic, extend or refine that card rather than creating
a fragmented duplicate.

Do not write a note for anything the project itself records (code structure, git history,
project conventions), anything that only matters inside the current conversation, anything the
model already knows, or anything you have not verified.

Capture is one file plus one index line:

```
cards/<slug>.md    frontmatter: title, last_verified, confidence (or created/updated)
INDEX.md           one line carrying the symptom, not just the topic
```

Both belong in the same commit. Split across two commits, reverting the note leaves an index
line pointing at a file that no longer exists.

## Correcting & Retracting

Find out when the wrong claim entered the file before deciding what to do about it:

```bash
git log -S'<the wrong sentence, verbatim>' --oneline -- cards/<slug>.md
```

Pickaxe search (`-S`) finds the commit that introduced the text, not the one that last touched the
line. Three cases follow, and they need different responses:

- **Stale.** It was right and the environment moved. Add a version or date boundary (`scope`) and
  keep the content.
- **Misjudged.** It was wrong when written. Apply a paragraph-level retraction (`retract`):
  rewrite that paragraph as "previously claimed X, which does not hold, because Y".
  **Keep the file, keep the index line, keep the symptom description.**
  The symptom is the retrieval key; deleting the note removes the only thing that would catch the
  same problem next time, causing future agents to research and write the same wrong note again.
- **Broken by an edit.** A later change turned a correct note wrong. Revert that change (`revert`)
  instead of editing on top of it.

Symptoms are observations and are usually right. Root causes are inferences and are what turn
out wrong. Fixes sometimes keep working even when the root cause is wrong, which is how a bad
diagnosis survives. A whole note is rarely wrong, so default to correcting the root cause alone.

## Logging

Log changes via `darwin.sh`:

```bash
darwin.sh [--user] <action> <file> [more-files...] <one-line-why> < /dev/null
```

Use `--user` when the change was explicitly commanded by the human user.

## Never

No credentials, no API keys, no tokens. Take care with identifiers too: device IDs, internal
hostnames, account IDs, zone IDs, and private paths are what keeps a knowledge base private.
