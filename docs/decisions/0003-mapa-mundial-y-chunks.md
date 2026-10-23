# ADR 0003 — Mapa mundial diseñado + chunks procedurales con seed

## Contexto
El dueño del proyecto diseñará a mano un mapa general del mundo (Nardaram). Las partidas no ocurren en ese mapa directamente: ocurren en **chunks** generados proceduralmente con seed. El mapa mundial es la guía de clima, geografía general y contexto geopolítico de cada chunk.

> **Aviso (2026-10-23):** posible conflicto con lo que el dueño dijo en ADR 0004 ("el mapa se genera similar a minecraft o dwarf fortress"; en Aventura el personaje "viaja de lugar en lugar"). No está resuelto: ver preguntas #27 y #30 en `0000-preguntas-abiertas.md`. Este ADR sigue vigente hasta que se decida.

## Decisión
- **Mapa mundial** (`data/world/world_map.json` + imagen de referencia en `docs/design/world/`): grid de regiones. Cada región define bioma/clima, relieve dominante, facción/contexto político, recursos típicos y nivel de peligro.
- **Chunk**: área jugable de una partida (ciudad + bosque explorable), de 64×64 tiles (ADR 0004). Se genera con `seed + region_id`. La región fija las reglas (qué tiles, qué recursos, qué enemigos); la seed fija la disposición.
- Generación determinista: mismo `seed + region` = mismo chunk. Toda aleatoriedad pasa por `GameState.rng`.
- Nuevo agente **`world-gen-dev`** dueño de la generación; `narrative-writer` y `game-designer` son dueños del contenido del mapa mundial (regiones, facciones, clima).

## Consecuencias
- `GameState` guarda `seed`, `region_id` y el chunk generado (o lo regenera al cargar).
- La exploración RPG y el grid de ciudad reciben el chunk ya generado; no generan nada por su cuenta.
- El mapa mundial es la primera pieza de contenido que necesita el proyecto: bloquea biomas, tilesets y tabla de enemigos.
