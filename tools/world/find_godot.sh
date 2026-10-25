#!/usr/bin/env bash
# Se carga con `source` desde los scripts de tools/world/ (necesita $ROOT): deja en $GODOT el
# ejecutable de Godot (igual que tools/test.sh: $GODOT, PATH o la instalación de winget) e importa
# el proyecto para que existan las class_name en un clon limpio.
if [[ -z "${GODOT:-}" ]]; then
  GODOT="$(command -v godot_console || command -v godot || command -v godot4 || true)"
fi
if [[ -z "$GODOT" && -n "${LOCALAPPDATA:-}" ]]; then
  GODOT="$(ls "$(cygpath -u "$LOCALAPPDATA")"/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot_v*_console.exe 2>/dev/null | tail -1 || true)"
fi
[[ -n "$GODOT" ]] || { echo "No encuentro Godot. Instala con: winget install GodotEngine.GodotEngine (o define \$GODOT)"; exit 1; }
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
