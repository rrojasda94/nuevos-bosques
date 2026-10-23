#!/usr/bin/env bash
# Instala GUT si falta y corre todos los tests en headless.
# Uso: tools/test.sh [args extra de GUT, ej. -gselect=test_game_state]
# Godot: usa $GODOT si está definido; si no, lo busca en PATH o en la instalación de winget.
set -euo pipefail

GUT_VERSION="9.7.1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -z "${GODOT:-}" ]]; then
  GODOT="$(command -v godot_console || command -v godot || command -v godot4 || true)"
fi
if [[ -z "$GODOT" && -n "${LOCALAPPDATA:-}" ]]; then
  GODOT="$(ls "$(cygpath -u "$LOCALAPPDATA")"/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot_v*_console.exe 2>/dev/null | tail -1 || true)"
fi
[[ -n "$GODOT" ]] || { echo "No encuentro Godot. Instala con: winget install GodotEngine.GodotEngine (o define \$GODOT)"; exit 1; }

if ! grep -q "version=\"$GUT_VERSION\"" "$ROOT/addons/gut/plugin.cfg" 2>/dev/null; then
  echo "Instalando GUT $GUT_VERSION..."
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/bitwes/Gut/archive/refs/tags/v$GUT_VERSION.zip" -o "$tmp/gut.zip"
  unzip -q "$tmp/gut.zip" -d "$tmp"
  rm -rf "$ROOT/addons/gut"
  cp -r "$tmp/Gut-$GUT_VERSION/addons/gut" "$ROOT/addons/"
  rm -rf "$tmp"
fi

# Import registra class_name y recursos; sin esto los tests fallan en un clon limpio.
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT" -s addons/gut/gut_cmdln.gd "$@"
