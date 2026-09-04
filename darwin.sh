#!/bin/sh
# darwin.sh: record one self-evolution change as an atomic, revertable commit.
#
#   darwin.sh <action> <file> [more-files...] <one-line-why>
#
# Writes two commits: the change itself (the revert target), then the log line
# in DARWIN.md that points at it. A longer account can be piped on stdin and
# lands in the commit body.
set -e

# Need at least an action, one file, and the one-line reason.
if [ "$#" -lt 3 ]; then
  echo "Usage: darwin.sh <action> <file> [more-files...] <one-line-why>" >&2
  exit 1
fi

ACTION="$1"
shift

case "$ACTION" in
  new|adapt|fix|revert|scope|retract)
    ;;
  *)
    echo "Error: action invalid: $ACTION (must be one of: new adapt fix revert scope retract)" >&2
    exit 1
    ;;
esac

# Config repo root. Defaults to ~/.agents; point DARWIN_ROOT elsewhere to use another repo.
AGENTS_DIR="${DARWIN_ROOT:-$HOME/.agents}"
if [ ! -d "$AGENTS_DIR" ]; then
  echo "Error: directory $AGENTS_DIR does not exist" >&2
  exit 1
fi

AGENTS_REAL=$(realpath "$AGENTS_DIR" 2>/dev/null)

# Every argument except the last is a file. Validate them all before touching git,
# so a bad path fails the whole call instead of leaving a partial commit.
FILE_COUNT=$(($# - 1))
FIRST_REL_TARGET=""
FILES_STR=""

i=0
while [ "$i" -lt "$FILE_COUNT" ]; do
  TARGET_ARG="$1"
  shift

  case "$TARGET_ARG" in
    /*)
      TARGET_PATH="$TARGET_ARG"
      ;;
    *)
      TARGET_PATH="$AGENTS_DIR/$TARGET_ARG"
      ;;
  esac

  if [ ! -e "$TARGET_PATH" ]; then
    echo "Error: target missing: $TARGET_ARG" >&2
    exit 1
  fi

  # Refuse anything that resolves outside the repo root, symlinks included.
  TARGET_REAL=$(realpath "$TARGET_PATH" 2>/dev/null)

  case "$TARGET_REAL" in
    "$AGENTS_REAL"/*)
      ;;
    *)
      echo "Error: target resolves outside $AGENTS_DIR: $TARGET_ARG" >&2
      exit 1
      ;;
  esac

  REL_TARGET="${TARGET_REAL#"$AGENTS_REAL"/}"

  if [ -z "$FIRST_REL_TARGET" ]; then
    FIRST_REL_TARGET="$REL_TARGET"
    FILES_STR="$REL_TARGET"
  else
    FILES_STR="$FILES_STR, $REL_TARGET"
  fi

  # Rotate the resolved path to the end of the argument list. After the loop the
  # reason sits at $1 and the resolved paths follow it.
  set -- "$@" "$REL_TARGET"

  i=$((i + 1))
done

WHY="$1"
shift

cd "$AGENTS_DIR"

# At least one target must differ from HEAD. Untracked counts as differing.
CHANGES=$(git status --porcelain -- "$@")
if [ -z "$CHANGES" ]; then
  if [ "$FILE_COUNT" -eq 1 ]; then
    echo "Error: target has no changes staged-or-unstaged relative to HEAD: $FIRST_REL_TARGET" >&2
  else
    echo "Error: targets have no changes staged-or-unstaged relative to HEAD: $FILES_STR" >&2
  fi
  exit 1
fi

# Optional long account on stdin.
STDIN_BODY=""
if [ ! -t 0 ]; then
  if [ -p /dev/fd/0 ] || [ -f /dev/fd/0 ] 2>/dev/null; then
    BYTES=$(stat -f "%z" /dev/fd/0 2>/dev/null || stat -c "%s" /dev/stdin 2>/dev/null || echo "")
    if [ "$BYTES" = "0" ]; then
      STDIN_BODY=""
    else
      STDIN_BODY=$(cat)
    fi
  else
    STDIN_BODY=$(cat)
  fi
fi

# Stage only the named files. Never `git add -A`: that is what breaks atomic revert.
git add -- "$@"

if [ "$FILE_COUNT" -gt 1 ]; then
  ADDITIONAL_COUNT=$((FILE_COUNT - 1))
  TARGET_DESC="$FIRST_REL_TARGET (+$ADDITIONAL_COUNT)"
  TARGET_COL="$FIRST_REL_TARGET +$ADDITIONAL_COUNT"
  COMMIT_MSG=$(printf "darwin(%s): %s\n\nfiles: %s\n%s" "$ACTION" "$TARGET_DESC" "$FILES_STR" "$WHY")
else
  TARGET_DESC="$FIRST_REL_TARGET"
  TARGET_COL="$FIRST_REL_TARGET"
  COMMIT_MSG=$(printf "darwin(%s): %s\n\n%s" "$ACTION" "$TARGET_DESC" "$WHY")
fi

if [ -n "$STDIN_BODY" ]; then
  COMMIT_MSG=$(printf "%s\n\n%s" "$COMMIT_MSG" "$STDIN_BODY")
fi
# Evolution commits are attributed to the agent, not to the user.
COMMIT_MSG=$(printf "%s\n\nCo-Authored-By: %s" "$COMMIT_MSG" "${DARWIN_AUTHOR:-Claude Opus 5 <noreply@anthropic.com>}")
git commit -q -m "$COMMIT_MSG"

SHORT_HASH=$(git rev-parse --short HEAD)

if [ ! -f "DARWIN.md" ]; then
  cat > DARWIN.md << 'EOF'
# Darwin self-evolution log

One line per change. Columns: date / commit / action / target / one-line reason.
The full account lives in that commit's body. Read it with `git show <hash>`, not by default.
Actions: new | adapt (fit to this machine) | fix | revert | scope (narrow) | retract (paragraph-level)

EOF
fi

TODAY=$(date +%Y-%m-%d)
DARWIN_LINE=$(printf "%s  %s  %s  %s  %s" "$TODAY" "$SHORT_HASH" "$ACTION" "$TARGET_COL" "$WHY")
printf "%s\n" "$DARWIN_LINE" >> DARWIN.md

# Second commit: the log line only. Kept separate so the hash written above stays valid.
git add -- DARWIN.md
git commit -q -m "darwin(log): $TARGET_DESC"

printf "%s\n" "$SHORT_HASH"
printf "%s\n" "$DARWIN_LINE"
