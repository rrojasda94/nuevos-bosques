#!/usr/bin/env bash
# Valida la autoría de una región y escribe build/preview_<region>_<seed>.png (1 px = 1 tile).
# Uso: tools/world/preview_region.sh [region_id] [seed]   (por defecto: valle_del_sara 42)
# Sale con código 1 si la autoría tiene errores (la vista previa se escribe igual, con los
# errores marcados en rojo).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/tools/world/find_godot.sh"
"$GODOT" --headless --path "$ROOT" -s tools/world/preview_region.gd -- "$@"
