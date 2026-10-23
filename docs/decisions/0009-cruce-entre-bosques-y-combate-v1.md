# ADR 0009 — Cruce entre Bosques y primer combate por turnos (implementación)

> Diseño: `docs/design/mechanics/cruce-y-combate-v1.md` (game-designer). Este ADR recoge solo las decisiones técnicas.

## Contexto
El slice de Aventura bloqueaba el paso a otros Bosques. El dueño eligió:
- Un menú en el borde: pagar Luz al Nujio, enfrentar a su Único o retroceder.
- Un combate clásico por menú, en una escena aparte superpuesta a la exploración.
- PV que se mantienen entre combates y se recuperan en una villa.
- Un Bosque inicial que siempre tiene villa (el lugar natal del Adoc).
- Un tope de Luz suelta.

## Decisión

### Archivos y responsabilidades
| Pieza | Archivo | Qué hace |
|---|---|---|
| Lógica de combate | `scripts/rpg/battle_logic.gd` (`BattleLogic`) | Clase pura. No toca GameState ni nodos. `play_turn(action)` devuelve eventos para narrar. |
| Reglas del Adoc | `scripts/rpg/adventure_rules.gd` (`AdventureRules`) | Funciones estáticas: balance, peaje, stats del Único, semilla del combate, aplicar el resultado a GameState, descanso en la villa. Escribe en GameState y emite en EventBus. |
| Menú del borde | `scenes/rpg/crossing.tscn` + `scripts/rpg/crossing.gd` | Escucha `bosque_border_reached`, pausa el árbol, abre el combate y emite `crossing_resolved`. No conoce la exploración. |
| Combate (UI) | `scenes/rpg/battle.tscn` + `scripts/rpg/battle.gd` | Solo dibuja un `BattleLogic` y le pasa las acciones. |
| Menú con cursor | `scripts/rpg/option_menu.gd` (`OptionMenu`) | Lista vertical que comparten los dos menús. Se maneja con `ui_up`, `ui_down`, `ui_accept` y `ui_cancel` (teclado y mando sin configurar nada). Salta las opciones desactivadas. |
| Números | `data/combat/balance.json` | Adoc, fórmulas del Único (con topes de d y de DEF), ataque, Defender, Ofrecer Luz, Huir, peaje, Luz de victoria, factor de derrota y `luz_max`. |

### Pausa y superposición
- Mientras están abiertos el menú o el combate, `get_tree().paused = true`.
- `Crossing` tiene `process_mode = ALWAYS` y el combate lo hereda. La exploración se congela sin destruirse.
- De paso se bloquea el `ui_accept` = "terminar día" de `main.gd` (que está en pausa).
- Los dos menús consumen la entrada con `set_input_as_handled`.

### Flujo con la exploración (cambios mínimos en `exploration.gd`)
- **Bosques transitables**: el inicial y los de `GameState.open_bosques` (`AdventureRules.is_passable`).
- **Borde cerrado**: `exploration.gd` guarda la dirección y emite `bosque_border_reached(id)`, igual que antes.
- **Resultado** (`crossing_resolved(id, outcome)`):
  - `paid` o `won`: cruza.
  - `retreated` o `fled`: un paso atrás.
  - `defeated`: despierta en la villa natal.
- **Aparición** (partida nueva) y **despertar** tras una derrota: en el chunk de la villa del Bosque inicial, en la casilla justo al sur del Nujio (o en el hub si no fuera transitable).
- **Descanso**: al pisar una casilla `PLAZA` de una villa, o una casilla adyacente (también en diagonal) al Nujio de un chunk con villa → PV al máximo y `rested_in_villa`.
  - Se avisa una vez por entrada en la zona.
  - Un Nujio sin villa no cura.
- `chunk_entered` pasa a emitir el Bosque del chunk actual (antes, siempre el inicial).

### Villa natal garantizada
- `BosqueMap.build(seed, size, home_chunk)` marca `has_villa = true` en el Bosque de `home_chunk` después del sorteo.
  - El sorteo y el resto de rasgos no cambian; un test comprueba que los demás Bosques quedan igual que sin `home_chunk` y mantienen ~1/5.
- `BosqueMap.for_region(seed, region)` es el atajo que usan la exploración y el menú del borde.
- Sin `home_chunk`, `build` da exactamente el reparto anterior.

### Distancia y aleatoriedad
- **Distancia**: `BosqueMap.distance(a, b)` hace un BFS sobre la adyacencia de Bosques. `d` es la distancia del Bosque inicial al Bosque al que se intenta entrar (un vecino del inicial tiene d = 1 y cuesta 4 de Luz).
- **RNG del combate**: un `RandomNumberGenerator` propio, sembrado con `hash_ints([seed, bosque_id, intento, SALT_BATTLE])`.
  - El número de intento por Bosque se guarda en `GameState.battle_attempts`, así que repetir un combate no repite la tirada, ni siquiera tras cargar la partida.
  - No se usa `GameState.rng` ni `randi()` global (corrige para el combate la línea "combate" de ADR 0006).
- **Único**: cada combate crea uno nuevo con todos sus PV. Huir o retroceder no conserva el daño hecho.

### Estado y guardado
- **`GameState`**: `luz`, `hp`, `open_bosques: Array[int]` y `battle_attempts: Dictionary`.
- **`SAVE_VERSION`** = 3. Las partidas v1 y v2 se cargan con los valores iniciales del balance y sin Bosques abiertos.
- **Luz**: se limita a `[0, luz_max]` en `AdventureRules.set_luz` y al cargar.

### Señales nuevas (EventBus)
- `battle_started(bosque_id)` y `battle_ended(bosque_id, result)`: sustituyen a `combat_started` y `combat_ended`, que no usaba nadie.
- `crossing_resolved(bosque_id, outcome)`.
- `luz_changed(luz)`.
- `hp_changed(hp, max_hp)`.
- `rested_in_villa`.

## Consecuencias
- Los textos del menú y del combate son placeholder en constantes de `crossing.gd` y `battle.gd`, y los tiene que revisar `narrative-writer`.
  - El nombre del Único usa `PlaceholderTileset.SHAPE_NAMES`, lo que da "Único de espinoso".
- El Único se dibuja con `PlaceholderTileset.nujio_texture` más ojos y un aura punteada. Lo sustituirá el arte de `pixel-artist`.
- El HUD de depuración muestra "PV x/30   Luz x/10". Ya no avisa en los bordes de Bosques con Nujio (lo hace el menú); sí en el límite de la región.
- `ui_accept` sigue significando "terminar día" en exploración (`main.gd`). Con los menús no choca porque el árbol está en pausa, pero conviene revisarlo cuando haya día y noche.
- Las ofrendas, el inventario, las misiones y el riutash quedan fuera de esta iteración.
