# Knowledge index

One line per note. If a line matches the task, open that one file. No match means move on:
there is no further search step in this index. Adding a note means writing `cards/<slug>.md`
plus one line here.

**Notes are one layer, so no match here does not mean nothing is known:**

- **Skills** are the procedural layer, "how this is done". Their descriptions are loaded by the
  agent harness, so they are not listed again here. The boundary: notes record facts and
  pitfalls, skills record procedures, and the same thing is written on one side only. A
  procedure you keep restating in notes is a skill that has not been written yet.
- **Refs** hold identifiers you cannot derive (machines, hosts, account and device ids). They
  belong in a private repository.
- All three layers are maintained by the agent itself, one revertable commit per change. See
  [Darwin](../README.md).

## Notes

This file is the template. Your own notes go below, one line each, and the line has to carry the
symptom rather than the topic, because the symptom is what a future agent will recognise.

- [<slug>](cards/<slug>.md): <what goes wrong, in the words someone would hit it with>. <the one
  thing to do instead>
- [<slug>](cards/<slug>.md): <symptom>. <fix>

A line naming only the topic never matches anything. A line that opens with the error text, the
wrong guess it invites, and the one thing to do instead matches the moment someone hits it.
