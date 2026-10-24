# Ficha: Cruce de Bosques y combate v2 (0.3 "El Bosque recuerda")

> Dueño: `game-designer`. Estado: v2, **vigente desde la 0.3** (PR 1). Sustituye a `cruce-y-combate-v1.md`, que queda como historial (feedback, propuestas de ajuste y decisiones anteriores).
> **Valores PROVISIONALES**, en `data/combat/balance.json`. Implementación: `rpg-systems-dev`.
> Fuentes: ADR 0013 (el Bosque recuerda), ADR 0010 (Luz, ofrendas, curación), ADR 0012 (tiempo), ADR 0004 (fatales), `monstruos.md`, `ofrendas-v1.md`, `progresion-adoc.md`, `mision-ofomni.md`.

## Objetivo
Cruzar entre Bosques con una decisión clara: **pagar** (más barato a la larga, el Bosque te tolera) o **pelear** (ganas XP, pero el Bosque te recuerda).

Palabras del dueño: "una vez vencido al botarrama los demas botarramas deberian volver a exigir un pago si esan en el mismo bosque. el bosque recuerda, mira observa. ser hostil con sus Únicos es peligroso." Y: "ofrecer luz hace 8 de daño en vez de terminar con la lucha."

## Pilares
- **Pilar 1 (dos capas)**: la Luz y las ofrendas que dan las villas compran el paso. La XP del combate te hace más fuerte.
- **Pilar 3 (legibilidad)**: un menú de 4 opciones en el borde y 5 acciones en combate.
- **Pilar 4**: cada Bosque guarda su propia memoria (hostilidad y relación).

## Presión de supervivencia
- **Añade**:
  - Cada victoria contra un Botarramas encarece el Bosque (+2 de peaje), hace que te vea desde más lejos (+2 de visión) y empeora la relación (−10).
  - La Luz sigue siendo escasa (límite de 10).
- **Alivia**: pagar deja el Bosque tranquilo (todos sus Botarramas pasivos). Perder contra un monstruo no fatal te devuelve a la villa.

## Reglas

### Encuentro
- Los **Botarramas** (`monstruos.md`) ven al jugador en su `vision_radius`, renquean hacia él y, a `engage_distance`, abren el **menú del borde**.
- Sin máscara no se puede colarse: tocar la frontera de un Bosque cerrado abre el mismo menú.

### Menú del borde
1. **"Ofrecer N Luz"**: paga con Luz suelta.
2. **"Ofrecer <ofrenda>"**: paga con una ofrenda entera, completada con Luz suelta si hace falta (`ofrendas-v1.md`).
3. **"Enfrentar"**: combate contra ese Botarramas.
4. **"Retroceder"**: vuelves 2 casillas y el Botarramas no te ve durante 3 s.

**N = 3 + d + 2 × hostilidad del Bosque** (hostilidad con tope en `balance.json`; d: distancia en saltos desde el Bosque natal hasta el Bosque al que se entra, con tope `d_max` = 6).

### Estados de un Bosque respecto al jugador
| Estado | Cómo se llega | Efecto |
|---|---|---|
| **cerrado** | Inicial | Sus Botarramas interceptan. |
| **forzado** | Vencer a uno de sus Botarramas | Ese Botarramas desaparece y se puede cruzar por su tramo. **Los demás siguen activos y exigen pago.** |
| **pagado** | Pagar (en el borde o en combate) | **Todos** sus Botarramas, pasivos. |

- El **Bosque natal** siempre está abierto.
- Más adelante (PR 2 de la 0.3), el pago **caduca** salvo amistad alta (`bosques-y-relacion.md`).

### Memoria del Bosque
| Variable (por Bosque) | Cambio | Efecto |
|---|---|---|
| **hostilidad** | +1 por Botarramas vencido; +1 por robo de fruto; **−1 por cada pago con ofrenda** (sin bajar de 0) | Peaje +2 por nivel; `vision_radius` de sus Botarramas +2 por nivel (tope +6) |
| **relación** (−100…100) | −10 por victoria; −20 por robo de fruto; +1 al pagar | Base de los umbrales de amistad (PR 3) |

- **El Bosque olvida con ofrendas** (dueño, #147: "el bosque olvida con ofrendas, si pagas pues bien"):
  - Pagar con una **ofrenda** baja la hostilidad 1.
  - Pagar con **Luz** deja el Bosque pagado, pero **no borra** la hostilidad.
- **Los Botarramas disueltos no reaparecen** (#147).
- Pagar el peaje también permite tomar **1 fruto por Momento** en ese Bosque (`bosques-y-relacion.md`, "Fruto").

### Combate (1 contra 1; los grupos llegan en el PR 6 de la 0.3)
- Por turnos, **primero el jugador**. Narración mensaje a mensaje, estilo Pokémon.
- **Acciones**:
  | Acción | Efecto |
  |---|---|
  | **Atacar** | Daño = max(1, ATQ − DEF + aleatorio de −1 a +2). |
  | **Defender** | El daño que recibes en el turno siguiente se reduce a la mitad. |
  | **Ofrecer Luz** | **Pagas el peaje N actual con Luz suelta.** El Único se va y el Bosque queda **pagado**. Sin XP ni Luz de victoria. Desactivada si no tienes N de Luz o contra el Ofomni. |
  | **Ofrecer ofrenda** | Igual que Ofrecer Luz, con una ofrenda (más Luz suelta para completar). Desactivada contra el Ofomni. |
  | **Huir** | 75% de éxito. Vuelves a tu lado; el Único recupera todos sus PV. |
- **El Único** ataca con la misma fórmula. Ataques especiales: `special_every` y `special_factor` (Ofomni: Latigazo múltiple).
- **Victoria**: XP = 4 + 3·d (`progresion-adoc.md`), +1 de Luz (hasta el límite). Ese Botarramas se disuelve, el Bosque queda **forzado**, su **hostilidad sube 1** y su **relación baja 10**.
- **Derrota**: según `fatal_at` (`monstruos.md`).
  - **Fatal**: game over.
  - **No fatal: reaparición** (dueño, sobre los garelinos: "te vas a respawunear recuperado parcialmente cerca al nujio aliado mas cercano o el ultimo que pagaste peaje o en caso no se cumpla ninguno a tu villa original"). Se aplica a **todas** las derrotas no fatales; esto es interpretación de `game-designer` y del coordinador.
    - **Dónde**: junto al Nujio más cercano entre los **aliados** (Bosques con relación ≥ 30, y el Bosque natal) y el **último Nujio al que pagaste peaje**. Si no hay ninguno, en la **villa natal**.
    - **Con cuánto**: el **50% de los PV máximos** (provisional), en lugar de todos.
    - **Luz**: se pierde **la mitad de la Luz suelta** (sin cambios; a revisar en playtest, porque ya no hay curación completa).
  - Sustituye al anterior "despiertas en la villa natal con todos los PV".

### Stats
- **Adoc**: según su nivel (`progresion-adoc.md`; nivel 1: 30 PV / 6 ATQ / 3 DEF). Luz inicial 10, límite 10.
- **Botarramas** (fórmula `unico`): PV 18 + 4·d, ATQ 4 + d, DEF 1 + ⌊d/2⌋ (tope 4).

### Curación
- **En una villa** (plaza o junto a su Nujio): todos los PV.
- **Riutash en refugio**: 50% de los PV que faltan. **Expuesto**: −30% de los PV máximos, sin bajar de 1 (`tiempo-y-riutash.md`).

## Tabla de peaje (N) según d y hostilidad
| d | Hostilidad 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| 1 | 4 | 6 | 8 | 10 |
| 2 | 5 | 7 | 9 | 11 |
| 3 | 6 | 8 | 10 | 12 |

Con el límite de Luz suelta en 10, a partir de hostilidad 2–3 solo se puede pagar con una ofrenda grande más Luz, o peleando.

## Inputs / outputs
- **Inputs:** grafo de Bosques, d, hostilidad y relación por Bosque, posición de los Botarramas, Luz, ofrendas, acciones.
- **Outputs:** estado del Bosque (cerrado, forzado o pagado), hostilidad, relación, Luz, PV, XP, Botarramas disueltos.

## Interacción con otros sistemas
- `monstruos.md`: Botarramas y su visión con la hostilidad.
- `bosques-y-relacion.md`: la relación completa, la caducidad del pago, los estados de Bosque y cómo modifican N.
- `ofrendas-v1.md`: pagar con ofrendas.
- `progresion-adoc.md`: XP.
- Guardado: estado, hostilidad y relación por Bosque, y Botarramas disueltos.

## Casos límite
- **Bosque forzado al que vuelves por otro tramo**: el Botarramas de ese tramo te intercepta y te pide N (con la hostilidad ya subida).
- **Pagar con hostilidad alta**: N puede superar tu Luz suelta. Solo te quedan la ofrenda (+ Luz), pelear o retroceder.
- **Vencer a todos los Botarramas de un Bosque**: el Bosque queda sin guardias activos y se cruza libre, pero con hostilidad y relación muy malas. Los Botarramas disueltos **no reaparecen** (#147). Para tomar fruto sin robar hay que pagar igualmente.
- **Ofrecer Luz con justo N**: te quedas sin Luz suelta; el pago es válido.
- **Ofrecer Luz contra el Ofomni**: desactivada (mensaje `battle_ofrenda_blocked_ofomni` o equivalente).
- **Huir de un Botarramas**: no cambia la hostilidad ni la relación.
- **Derrota contra un Botarramas**: no cambia la hostilidad (no lo has vencido).

## Criterios de éxito para playtest
Propuestas, a confirmar con el dueño:
- El jugador nota que, tras vencer a un Botarramas, el siguiente del mismo Bosque le pide más (pregunta: "¿por qué te pidió más?").
- En una sesión de 30 minutos, el jugador paga al menos una vez y pelea al menos una vez por decisión propia.
- El dueño siente que "el Bosque recuerda" (pregunta directa).

## Preguntas abiertas
- ~~¿La hostilidad baja? ¿Reaparecen los Botarramas?~~ Resuelta (#147): baja con ofrendas (−1 por pago con ofrenda) y los disueltos no reaparecen. **Sigue abierto**: ¿el estado "forzado" caduca? (Lo cubre en parte la caducidad del pago del PR 3.)
- Ajuste del Ofomni (#148).
- Combinación de N con los estados de Bosque y la relación (PR 2 y 3; `bosques-y-relacion.md`).
