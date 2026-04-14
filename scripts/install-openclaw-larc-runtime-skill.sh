#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$SCRIPT_DIR/openclaw-larc-runtime"
TARGET_DIR="$HOME/.openclaw/skills/larc-runtime"
MODE="link"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy) MODE="copy"; shift ;;
    --link) MODE="link"; shift ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$SOURCE_DIR/SKILL.md" ]]; then
  echo "Skill source not found: $SOURCE_DIR/SKILL.md" >&2
  exit 1
fi

mkdir -p "$HOME/.openclaw/skills"

if [[ -e "$TARGET_DIR" || -L "$TARGET_DIR" ]]; then
  rm -rf "$TARGET_DIR"
fi

if [[ "$MODE" == "copy" ]]; then
  cp -R "$SOURCE_DIR" "$TARGET_DIR"
  echo "Installed OpenClaw skill by copy: $TARGET_DIR"
else
  ln -s "$SOURCE_DIR" "$TARGET_DIR"
  echo "Installed OpenClaw skill by symlink: $TARGET_DIR -> $SOURCE_DIR"
fi

echo ""
echo "Next:"
echo "  openclaw skills list | rg larc-runtime"
echo "  bin/larc ingress openclaw --agent main --days 14"
