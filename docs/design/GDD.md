# GDD — Nardaram: Los Nuevos Bosques

> Dueño: `game-designer`. Estado: borrador v0.3 (incorpora ADR 0002, 0003 y 0004).

## Visión
Refundar un pueblo en un bosque arrasado de Nardaram y cumplir la **misión de la partida**, que depende del modo elegido (Supervivencia, Garelino o Aventura; ver ADR 0004). Cada partida ocurre en un chunk del mundo generado con seed; el mapa mundial diseñado a mano dicta clima, geografía y contexto político. Exploras el bosque como aventurero (RPG por turnos) y gestionas el pueblo día a día. Pixel art 8-bit top-down, sesiones cortas, progreso visible. Solo español.

## Pilares
1. Dos capas, un mundo.
2. Sesiones cortas con progreso visible (15 min = algo nuevo).
3. Legibilidad 8-bit.
4. **Cada partida es distinta, cada región se reconoce**: la seed cambia la disposición, la región mantiene su identidad.

## Loop principal (por días)
```
Inicio del día: ver estado del pueblo (comida, gente, amenazas) y de la misión
   ↓
Fase de ciudad: construir, asignar trabajos, gestionar almacén
   ↓
(opcional) Expedición: elegir destino en el chunk → explorar → combates por menú → loot/supervivientes
            Consume 1–3 días (pendiente #12); el pueblo sigue simulándose mientras tanto.
   ↓
Fin del día: producción → consumo → necesidades → eventos → chequeo de misión
```

## Modos de partida (ADR 0004)
Cada partida tiene una misión. **Derrota = fallar la misión de la partida.**

| Modo | Misión | Victoria | Qué significa fallar |
|---|---|---|---|
| **Supervivencia** | Mantener con vida al Nujio (gran árbol). | Por definir (#16) | Por definir (#17) |
| **Garelino** | Expandir la influencia de los Nuevos Bosques a la región. | Por definir (#16, #18) | Por definir (#18) |
| **Aventura** | Se generan misiones para derrotar Únicos. Las villas suelen llamar al adoc para combatirlos. | Por definir (#16) | Por definir (#21) |

- Cómo se elige el modo: por definir (#15).
- Presiones de supervivencia que añade cada modo: por definir (se documentarán en una ficha por modo en `docs/design/mechanics/`).
- Presiones generales ya previstas: comida, clima de la región, eventos de facción, enemigos del bosque.
- Progreso = más gente, mejores edificios, zonas del chunk desbloqueadas.

## Mundo (ADR 0003, ADR 0004)
- Mapa mundial en `data/world/world_map.json` + arte de referencia en `docs/design/world/`.
- Región → bioma, clima, relieve, facción, recursos, peligro.
- Chunk = ciudad + bosque explorable. **64×64 tiles.** Ubicación y tamaño de la ciudad dentro del chunk: por definir (#14).

## Capa ciudad (MVP)
- Grid 16×16 top-down (por revisar junto con #14).
- Recursos: madera, piedra, comida, oro.
- Edificios iniciales: hoguera (centro), cabaña, aserradero, cantera, huerto, herrería.
- Ciudadanos: llegan por expediciones; necesitan cabaña y comida; trabajan en un edificio.
- Producción/consumo **por día** en `data/buildings/`.

## Capa RPG (MVP)
- Party de hasta 3. Stats: HP, ATK, DEF, SPD.
- Combate por turnos, menú: Atacar / Habilidad / Objeto / Huir.
- Exploración top-down del chunk; encuentros según bioma de la región.
- Inventario 12 slots. Equipo: arma, armadura, accesorio.

## Glosario
Solo contiene lo dicho por el dueño del proyecto. Lo demás está por definir (dueño del lore: `narrative-writer`).

| Término | Definición |
|---|---|
| **Nujio** | Gran árbol. En el modo Supervivencia la misión es mantenerlo con vida. Resto: por definir (#17, #26). |
| **Garelino** | Nombre del modo cuya misión es expandir la influencia de los Nuevos Bosques a la región. Significado del término: por definir (#25). |
| **Únicos** | Monstruos defensores de bosques que se han descarriado y entrado en modo berserk. Hay muchos tipos. Son el objetivo de las misiones del modo Aventura. Tipos, número y reglas: por definir (#20, #22). |
| **adoc** | Al que las villas suelen llamar para combatir a los Únicos. Qué es exactamente: por definir (#23). |
| **villas** | Llaman al adoc para combatir a los Únicos. Qué villas son: por definir (#24). |

## Fuera de alcance del MVP
Multijugador, mods, más de una región jugable, localización (inglés en v1.x).

## Métricas de playtest
- Tiempo hasta el primer edificio construido: < 3 min.
- Tiempo hasta la primera expedición: < 8 min.
- Jugador describe el loop sin ayuda tras 15 min.
- Duración media de partida antes de la primera derrota: 20–40 días (valor previo a ADR 0004; por revisar por modo cuando se definan las misiones).

## Pendiente
Ver `docs/decisions/0000-preguntas-abiertas.md`.
