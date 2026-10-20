#!/usr/bin/env bash
# Install the plane-meu skills for a tool other than the Claude Code plugin.
#
#   scripts/install.sh codex    symlink each skill into ${CODEX_HOME:-~/.codex}/skills/
#   scripts/install.sh claude   symlink each skill into ~/.claude/skills/ (only if you do NOT use the plugin)
#   scripts/install.sh zip      build dist/<skill>.zip for uploading to ChatGPT (or claude.ai)
#
# Symlinks mean `git pull` updates the installed skills. Existing real folders are never overwritten.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$PLUGIN_ROOT/skills"
DIST_DIR="$PLUGIN_ROOT/dist"

usage() {
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

link_skills() {
  local dest_dir="$1"
  mkdir -p "$dest_dir"
  for skill_dir in "$SKILLS_DIR"/*/; do
    local name target
    name="$(basename "$skill_dir")"
    target="$dest_dir/$name"
    if [[ -e "$target" && ! -L "$target" ]]; then
      echo "skip: $target exists and is not a symlink (remove it yourself to install)" >&2
      continue
    fi
    ln -sfn "${skill_dir%/}" "$target"
    echo "linked: $target -> ${skill_dir%/}"
  done
}

zip_skills() {
  command -v zip >/dev/null || { echo "error: 'zip' is not installed" >&2; exit 1; }
  mkdir -p "$DIST_DIR"
  for skill_dir in "$SKILLS_DIR"/*/; do
    local name
    name="$(basename "$skill_dir")"
    rm -f "$DIST_DIR/$name.zip"
    (cd "$SKILLS_DIR" && zip -qr "$DIST_DIR/$name.zip" "$name" -x '*.DS_Store')
    echo "built: dist/$name.zip"
  done
}

[[ $# -eq 1 ]] || usage
"$PLUGIN_ROOT/scripts/sync-shared.sh"

case "$1" in
  codex)  link_skills "${CODEX_HOME:-$HOME/.codex}/skills" ;;
  claude) link_skills "$HOME/.claude/skills" ;;
  zip)    zip_skills ;;
  *)      usage ;;
esac
