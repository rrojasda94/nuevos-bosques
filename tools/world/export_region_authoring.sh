#!/usr/bin/env bash
# Exporta las PNG y lugares.csv iniciales de una región desde el generador actual (ADR 0014 §4).
# Uso: tools/world/export_region_authoring.sh [region_id] [seed] [--force]
#   Sin seed, usa la primera cuya villa natal cae en start_chunk.
# OJO: sobrescribe data/world/regions/<region_id>/. Es para el punto de partida, no para el día a día.
# Si la región ya tiene agua.png, se niega salvo con --force (autoria.md §8).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/tools/world/find_godot.sh"
"$GODOT" --headless --path "$ROOT" -s tools/world/export_region_authoring.gd -- "$@"
