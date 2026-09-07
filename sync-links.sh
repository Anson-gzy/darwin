#!/bin/sh
# sync-links.sh: automatically distribute AGENTS.md and skills to all AI agent clients.
#
# One central configuration repository, multiple agent consumers.
# Each AI coding agent expects its entry instructions and skills in its own configuration
# directory. This script creates idempotent symlinks so an evolved rule or skill takes effect
# across every tool simultaneously without drift.
#
# Governs:
#   1. Entry guidance (AGENTS.md / CLAUDE.md)
#   2. Skills directory (as dir-level symlinks or individual skill symlinks)
#
# Supported Clients:
#   - Claude Code       (~/.claude)
#   - Codex             (~/.codex)
#   - Antigravity/Gemini (~/.gemini)
#   - Cursor            (~/.cursor)
#   - Grok              (~/.grok)
#   - Cline             (~/.cline)
set -e

CONFIG_REPO="${DARWIN_ROOT:-$HOME/.agents}"
GUIDANCE_SRC="${DARWIN_GUIDANCE:-$CONFIG_REPO/AGENTS.md}"
SKILLS_SRC="${DARWIN_SKILLS:-$CONFIG_REPO/skills}"
DRY_RUN="${DRY_RUN:-0}"

if [ ! -d "$CONFIG_REPO" ]; then
  echo "Error: configuration repository does not exist at: $CONFIG_REPO" >&2
  echo "Set DARWIN_ROOT=/path/to/repo to use an alternate location." >&2
  exit 1
fi

log() {
  printf "\033[36m[darwin:link]\033[0m %s\n" "$*"
}

warn() {
  printf "\033[33m[darwin:link]\033[0m %s\n" "$*" >&2
}

link_file() {
  src="$1"
  dst="$2"

  if [ ! -e "$src" ]; then
    warn "Skipping: source file missing ($src)"
    return 0
  fi

  # Already correctly symlinked
  if [ -L "$dst" ]; then
    current_target=$(readlink "$dst" 2>/dev/null || true)
    if [ "$current_target" = "$src" ]; then
      return 0
    fi
  fi

  # Real file in the way -> backup
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    bak="${dst}.bak.$(date +%s)"
    if [ "$DRY_RUN" = "1" ]; then
      echo "  (dry-run) backup real file: $dst -> $bak"
    else
      mv "$dst" "$bak"
      log "Backed up existing file: $dst -> $bak"
    fi
  fi

  if [ "$DRY_RUN" = "1" ]; then
    echo "  (dry-run) link: $dst -> $src"
  else
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    log "Linked guidance: $dst -> $src"
  fi
}

link_dir() {
  src="$1"
  dst="$2"

  if [ ! -d "$src" ]; then
    warn "Skipping: source directory missing ($src)"
    return 0
  fi

  if [ -L "$dst" ]; then
    current_target=$(readlink "$dst" 2>/dev/null || true)
    if [ "$current_target" = "$src" ]; then
      return 0
    fi
  fi

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    bak="${dst}.bak.$(date +%s)"
    if [ "$DRY_RUN" = "1" ]; then
      echo "  (dry-run) backup real dir: $dst -> $bak"
    else
      mv "$dst" "$bak"
      log "Backed up existing directory: $dst -> $bak"
    fi
  fi

  if [ "$DRY_RUN" = "1" ]; then
    echo "  (dry-run) link dir: $dst -> $src"
  else
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    log "Linked skills directory: $dst -> $src"
  fi
}

link_skills_each() {
  src_dir="$1"
  target_dir="$2"

  if [ ! -d "$src_dir" ]; then
    return 0
  fi

  if [ "$DRY_RUN" != "1" ]; then
    mkdir -p "$target_dir"
  fi

  for s in "$src_dir"/*/; do
    [ -d "$s" ] || continue
    name=$(basename "$s")
    [ "$name" = "_sources" ] && continue
    [ -f "${s}SKILL.md" ] || continue

    link_file "$s" "$target_dir/$name"
  done

  # Clean dangling symlinks in target directory
  if [ -d "$target_dir" ] && [ "$DRY_RUN" != "1" ]; then
    for item in "$target_dir"/*; do
      if [ -L "$item" ] && [ ! -e "$item" ]; then
        rm -f "$item"
        log "Cleaned dangling symlink: $item"
      fi
    done
  fi
}

log "Distributing configuration from: $CONFIG_REPO"

# 1. Claude Code (~/.claude)
if [ -d "$HOME/.claude" ] || [ -f "$GUIDANCE_SRC" ]; then
  link_file "$GUIDANCE_SRC" "$HOME/.claude/CLAUDE.md"
  link_dir "$SKILLS_SRC" "$HOME/.claude/skills"
fi

# 2. Codex (~/.codex)
if [ -d "$HOME/.codex" ] || [ -f "$GUIDANCE_SRC" ]; then
  link_file "$GUIDANCE_SRC" "$HOME/.codex/AGENTS.md"
  link_dir "$SKILLS_SRC" "$HOME/.codex/skills"
fi

# 3. Gemini / Antigravity (~/.gemini)
if [ -d "$HOME/.gemini" ] || [ -d "$HOME/.gemini/config" ]; then
  link_file "$GUIDANCE_SRC" "$HOME/.gemini/config/AGENTS.md"
  if [ -d "$HOME/.gemini/antigravity" ]; then
    link_skills_each "$SKILLS_SRC" "$HOME/.gemini/antigravity/skills"
  else
    link_skills_each "$SKILLS_SRC" "$HOME/.gemini/config/skills"
  fi
fi

# 4. Cursor (~/.cursor)
if [ -d "$HOME/.cursor" ]; then
  link_skills_each "$SKILLS_SRC" "$HOME/.cursor/skills"
fi

# 5. Grok (~/.grok)
if [ -d "$HOME/.grok" ]; then
  link_skills_each "$SKILLS_SRC" "$HOME/.grok/skills"
fi

# 6. Cline (~/.cline)
if [ -d "$HOME/.cline" ]; then
  link_skills_each "$SKILLS_SRC" "$HOME/.cline/skills"
fi

log "Distribution complete. All agent environments linked."
