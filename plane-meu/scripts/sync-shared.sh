#!/usr/bin/env bash
# Copy shared/ (projects.json, resolve-project.md) into every skill's references/ folder,
# so each skill is self-contained (Codex and ChatGPT load a skill folder on its own).
# Edit files in shared/ only, then run this script.
#
#   scripts/sync-shared.sh          copy shared files into each skill
#   scripts/sync-shared.sh --check  exit 1 if any copy is missing or stale (for CI / pre-commit)
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHARED_DIR="$PLUGIN_ROOT/shared"
SKILLS_DIR="$PLUGIN_ROOT/skills"
IS_CHECK=false
[[ "${1:-}" == "--check" ]] && IS_CHECK=true

python3 -I -c 'import json,sys; json.load(open(sys.argv[1]))' "$SHARED_DIR/projects.json" \
  || { echo "error: shared/projects.json is not valid JSON" >&2; exit 1; }

stale_count=0
for skill_dir in "$SKILLS_DIR"/*/; do
  refs_dir="${skill_dir}references"
  for shared_file in "$SHARED_DIR"/*; do
    target="$refs_dir/$(basename "$shared_file")"
    if cmp -s "$shared_file" "$target"; then
      continue
    fi
    if $IS_CHECK; then
      echo "stale: ${target#"$PLUGIN_ROOT"/}" >&2
      stale_count=$((stale_count + 1))
    else
      mkdir -p "$refs_dir"
      cp "$shared_file" "$target"
      echo "synced: ${target#"$PLUGIN_ROOT"/}"
    fi
  done
done

if $IS_CHECK && (( stale_count > 0 )); then
  echo "run scripts/sync-shared.sh to fix $stale_count file(s)" >&2
  exit 1
fi
