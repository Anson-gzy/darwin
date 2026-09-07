#!/bin/sh
# sync-guard.sh: refuse a batch commit while Darwin-governed files have uncommitted changes.
#
# Drop this check into whatever script commits your agent config repo, before its `git add -A`.
# Without it, an evolution edit that skipped darwin.sh gets swept into a batch commit alongside
# unrelated files. `git revert` on that commit then takes the unrelated files with it, and the
# atomic undo is gone with no error shown.
#
# Set SYNC_ALLOW_UNLOGGED=1 to pass anyway, for changes that genuinely are not evolutions
# (a bulk import, a reformat).

ROOT="${DARWIN_ROOT:-$HOME/.agents}"
cd "$ROOT" || exit 1

# Paths Darwin governs. Adjust to match your layout: guidance files, knowledge notes,
# rules, and the skill entry points. Bulk asset directories stay out, since importing content
# into them is not an evolution.
governed() {
  git status --porcelain -- \
    'AGENTS.md' \
    'knowledge/AGENTS.md' \
    'knowledge/INDEX.md' \
    'knowledge/cards' \
    'knowledge/rules' \
    'skills/*/SKILL.md'
}

unlogged=$(governed | wc -l | tr -d ' ')
if [ "$unlogged" -gt 0 ] && [ "${SYNC_ALLOW_UNLOGGED:-0}" != "1" ]; then
  echo "sync: refusing to commit, $unlogged governed files have not gone through darwin.sh:" >&2
  governed >&2
  echo "sync: run darwin.sh [--user] <action> <file> <one-line-why> on each, then sync again." >&2
  echo "sync: not an evolution (bulk import, reformat)? SYNC_ALLOW_UNLOGGED=1 $0" >&2
  exit 1
fi

# ... your existing `git add -A && git commit && git push` follows here.
