#!/usr/bin/env bash
# Installiert die Custom Agents persönlich für GitHub Copilot (App und CLI).
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/agents"
DEST="${COPILOT_AGENTS_DIR:-$HOME/.copilot/agents}"

mkdir -p "$DEST"
for f in "$SRC"/*.agent.md; do
  name="$(basename "$f")"
  if [ -e "$DEST/$name" ] && ! cmp -s "$f" "$DEST/$name"; then
    cp "$DEST/$name" "$DEST/$name.bak"
    echo "Sicherung: $DEST/$name.bak"
  fi
  cp "$f" "$DEST/$name"
  echo "Installiert: $name"
done

echo "Fertig. Neue Copilot-Session starten, dann den Agenten 'orchestrator' oder 'orchestrator-lite' wählen."
