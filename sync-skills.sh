#!/bin/bash
# sync-skills.sh: distribute one skill library to every agent directory as symlinks.
#
# One source of truth, many consumers. Each agent CLI wants its skills in its own
# directory; keeping real copies in each means they drift. This links instead, so an
# evolved skill takes effect everywhere at once.
#
# NEVER use `skills add <path under your source dir> --global` for distribution.
# The skills CLI treats the parent of your source as an agent directory too, so the
# install target resolves to the source directory itself. It clears the target before
# copying from the source: empty the source, copy from the empty source, leave an empty
# directory. One call destroys one skill, and it exits 0. Distribution only needs ln -s.
#
# Bulk upstream upgrades (--update) still shell out to `skills update -g`, which rewrites
# the whole tree non-atomically, so that path takes a restore point first and verifies
# integrity afterwards.
set -euo pipefail

SOURCE_DIR="${SKILLS_SOURCE:-$HOME/.agents/skills}"
CONFIG_REPO="${DARWIN_ROOT:-$HOME/.agents}"

# Agent skill directories to link into. Absolute link targets throughout, because these
# paths sit at different depths and some are themselves symlinks.
TARGETS="${SKILLS_TARGETS:-$HOME/.claude/skills $HOME/.codex/skills $HOME/.cursor/skills}"

DO_UPDATE=0
[ "${1:-}" = "--update" ] && DO_UPDATE=1

[ -d "$SOURCE_DIR" ] || { echo "source directory missing: $SOURCE_DIR" >&2; exit 1; }

# Count complete skills (directories holding a SKILL.md) to compare before and after.
count_ok() {
  local n=0 d
  for d in "$SOURCE_DIR"/*/; do
    [ -f "${d}SKILL.md" ] && n=$((n + 1))
  done
  echo "$n"
}

if [ "$DO_UPDATE" = 1 ]; then
  command -v skills >/dev/null 2>&1 || { echo "skills CLI not found" >&2; exit 1; }

  echo "restore point: committing current state..."
  git -C "$CONFIG_REPO" add -A
  git -C "$CONFIG_REPO" commit -q -m "checkpoint before skills update" || true

  before=$(count_ok)
  echo "updating installed skills (complete skills before: $before)..."
  if ! skills update -g -y; then
    echo "warning: skills update exited non-zero, verifying integrity now." >&2
  fi

  after=$(count_ok)
  if [ "$after" -lt "$before" ]; then
    echo "complete skills fell from $before to $after. Tree damaged, aborting." >&2
    echo "   recover: git -C $CONFIG_REPO checkout -- skills/" >&2
    exit 1
  fi
  dels=$(git -C "$CONFIG_REPO" status --porcelain -- skills/ | awk 'substr($0,1,2) ~ /D/' | wc -l | tr -d ' ')
  if [ "$dels" -gt 20 ]; then
    echo "update deleted $dels tracked files, beyond a normal upgrade. Aborting." >&2
    echo "   recover: git -C $CONFIG_REPO checkout -- skills/" >&2
    exit 1
  fi
  echo "integrity check passed (complete skills: $after, deleted files: $dels)."
fi

echo "linking from $SOURCE_DIR into agent directories..."
# Snapshot first: the self-check below must compare what THIS run changed, not
# whatever was already uncommitted in the working tree.
before_state=$(git -C "$CONFIG_REPO" status --porcelain -- skills/ || true)
linked=0
conflict=0

for target in $TARGETS; do
  [ -d "$target" ] || { echo "  skipping (no such directory): $target"; continue; }
  for skill_dir in "$SOURCE_DIR"/*/; do
    name="$(basename "$skill_dir")"
    [ -f "${skill_dir}SKILL.md" ] || continue
    link="$target/$name"
    if [ -e "$link" ] && [ ! -L "$link" ]; then
      echo "  real directory in the way, not overwritten: $link" >&2
      conflict=$((conflict + 1))
      continue
    fi
    # -n replaces the symlink itself rather than writing through it into its target.
    ln -sfn "$SOURCE_DIR/$name" "$link"
    linked=$((linked + 1))
  done
  # Drop links pointing at skills that no longer exist.
  for e in "$target"/*; do
    [ -L "$e" ] || continue
    [ -e "$e" ] || { echo "  removing dangling link: $(basename "$e")"; rm "$e"; }
  done
done

echo "done: $linked links created or refreshed."
[ "$conflict" -gt 0 ] && echo "$conflict real directories blocked a link (drift risk), confirm and remove them." >&2

# Distribution creates links and nothing else. Any change to the source means something
# went wrong, most likely a CLI that copied instead of linking.
after_state=$(git -C "$CONFIG_REPO" status --porcelain -- skills/ || true)
if [ "$before_state" != "$after_state" ]; then
  echo "distribution modified the source, which should never happen. New differences:" >&2
  diff <(printf '%s\n' "$before_state") <(printf '%s\n' "$after_state") | sed 's/^/   /' >&2
  echo "   recover: git -C $CONFIG_REPO checkout -- skills/" >&2
  exit 1
fi
echo "source intact. Single source of truth: $SOURCE_DIR"
