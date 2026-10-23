# Ficha: Progresión del adoc (XP y niveles)

> Dueño: `game-designer`. Versión 0.2.0 "Primer encargo". Fuentes: ADR 0004 (en Aventura el personaje "va subiendo experiencia, aprendiendo habilidades, ganando objetos y fama"), `cruce-y-combate-v1.md`.
> **Valores PROVISIONALES**, en `data/combat/balance.json` (estructura: `rpg-systems-dev`). Implementación: PR 7.

## Objetivo
Que vencer Únicos haga más fuerte al adoc y que el progreso se vea en cada sesión. La curva está pensada para que el **Ofomni** de la primera misión (`mision-ofomni.md`) sea **difícil pero ganable** para un adoc de nivel 2–3 que use bien "Ofrecer Luz" y "Defender".

## Pilares
- **Pilar 2 (progreso visible)**: el nivel 2 llega tras 2 victorias, y el mensaje "¡Subes a nivel N!" aparece en el combate.
- **Pilar 1 (dos capas)**: lo que ganas en combate te permite llegar más lejos en el mapa.

## Presión de supervivencia
- **Alivia**: más PV, ATQ y DEF hacen viables los Bosques lejanos.
- **Añade**: la XP solo se gana **venciendo**. Pagar el peaje (con Luz u ofrendas), huir o hacer que el Único se vaya con una ofrenda no da XP. Cada cruce obliga a elegir entre gastar Luz y arriesgar PV para ganar fuerza.

## Reglas

### XP por victoria
**XP = 4 + 3·d**, donde d es la distancia del combate (la misma que en `cruce-y-combate-v1.md`, con el tope `d_max` = 6).

| d | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| XP | 7 | 10 | 13 | 16 | 19 | 22 |

- Solo da XP una **victoria** (PV del rival a 0). Pagar, huir, retroceder, perder o usar una ofrenda en combate no dan XP.
- El Ofomni da la XP de su d **más** la XP de la recompensa de la misión (`mision-ofomni.md`).

### Niveles 1–10
| Nivel | XP acumulada | PV máx. | ATQ | DEF | Sube |
|---|---|---|---|---|---|
| 1 | 0 | 30 | 6 | 3 | — (valores de v1) |
| 2 | 10 | 34 | 7 | 3 | PV, ATQ |
| 3 | 25 | 38 | 7 | 4 | PV, DEF |
| 4 | 45 | 42 | 8 | 4 | PV, ATQ |
| 5 | 70 | 46 | 9 | 4 | PV, ATQ |
| 6 | 100 | 50 | 9 | 5 | PV, DEF |
| 7 | 140 | 54 | 10 | 5 | PV, ATQ |
| 8 | 190 | 58 | 11 | 5 | PV, ATQ |
| 9 | 250 | 62 | 11 | 6 | PV, DEF |
| 10 | 320 | 66 | 12 | 6 | PV, ATQ |

Regla compacta: cada nivel da **+4 PV máx.**; en los niveles múltiplos de 3 sube **+1 DEF** y en los demás **+1 ATQ**.

- **Al subir de nivel**, los PV actuales suben lo mismo que los máximos (+4). No es una curación completa.
- Se pueden subir varios niveles con una sola victoria; se aplica cada uno y se muestra un mensaje por nivel.
- **Nivel 10 es el tope** en la 0.2.0. La XP sigue acumulándose, pero no da más niveles.
- `BattleLogic` recibe los stats del adoc ya calculados para su nivel (plan, PR 7).

### Fama
- Contador entero, empieza en 0.
- **+1 al cobrar la recompensa de una misión** (en la 0.2.0, solo la del Ofomni).
- En la 0.2.0 solo se ve en la pantalla de estado. No tiene efectos todavía (#33).
- No se pierde.

## Tabla de referencia: nivel recomendado por d (Únicos normales, sin Luz)
Valores medios: daño del adoc = ATQ − DEF del Único + 0,5; daño del Único = su ATQ − DEF del adoc + 0,5. Únicos con las fórmulas de v1 y `def_max` = 4.

| d | Único (PV/ATQ/DEF) | Nivel 1 | Nivel 2 | Nivel 3 | Nivel 4 | Nivel 5 |
|---|---|---|---|---|---|---|
| 1 | 22/5/1 | gana (~8 de daño) | gana (~8) | gana (~5) | gana | gana |
| 2 | 26/6/2 | gana (~18 de 30) | gana (~14 de 34) | gana (~10) | gana | gana |
| 3 | 30/7/2 | justo (~27 de 30) | gana (~23 de 34) | gana (~18 de 38) | gana (~14) | gana |
| 4 | 34/8/3 | pierde (~50) | pierde (~39 de 34) | justo (~32 de 38) | gana (~27 de 42) | gana |
| 5 | 38/9/3 | pierde | pierde | pierde (~44 de 38) | gana (~33 de 42) | gana (~28 de 46) |
| 6 | 42/10/4 | pierde | pierde | pierde | pierde (~58 de 42) | justo (~46 de 46) |

Cada "Ofrecer Luz" (2 de Luz) quita 8 PV y acorta la pelea, así que con Luz el umbral baja más o menos un nivel.

### Camino típico hasta el Ofomni
El Ofomni aparece a 3–4 saltos (`mision-ofomni.md`). Si el jugador vence a los Únicos de d = 1, 2 y 3 por el camino, suma 7 + 10 + 13 = **30 XP → nivel 3**. Si paga uno de los peajes, llega a nivel 2 pero con menos Luz. Esa es la decisión central de la misión.

## Inputs / outputs
- **Inputs:** resultado del combate, d, XP actual.
- **Outputs:** XP, nivel, stats del adoc (PV máx., ATQ, DEF), PV actuales ajustados, señal `character_leveled_up`, mensaje en el combate, fama.

## Interacción con otros sistemas
- **Combate** (`cruce-y-combate-v1.md`): stats del adoc por nivel.
- **Misión del Ofomni**: XP y fama de la recompensa.
- **Guardado**: XP, nivel y fama.
- **UI**: pantalla de estado (tecla I o en el mapa) con nivel, XP para el siguiente nivel, stats y fama.

## Casos límite
- **Victoria con la XP justo en el umbral**: se sube de nivel (umbral inclusivo).
- **Varios niveles de golpe** (por ejemplo, la recompensa de misión más la victoria): se aplican en orden, con un mensaje por nivel.
- **Nivel 10**: no se sube más. Se puede mostrar la XP, pero sin barra al siguiente nivel.
- **Derrota**: no se pierde XP ni nivel (solo la mitad de la Luz suelta, como en v1).
- **Cargar una partida de la 0.1.0** (sin XP): empieza en nivel 1 con 0 XP.

## Criterios de éxito para playtest
Propuestas, a confirmar con el dueño:
- El jugador sube al nivel 2 en sus primeros 10–15 minutos.
- El jugador llega al Ofomni con nivel 2 o 3 en la mayoría de partidas.
- El dueño nota que subir de nivel cambia las peleas (pregunta directa).
- Ningún combate contra un Único de d ≤ 2 se percibe como imposible con nivel 1.

## Decisiones a confirmar con el dueño
- Solo las victorias dan XP: no la dan pagar, huir ni usar una ofrenda (#123).
- Subir de nivel no cura por completo (+4 PV actuales).
- Fama +1 por misión, sin efectos todavía.
- Tope en nivel 10 para la 0.2.0.

## Preguntas abiertas
- Habilidades: el dueño dijo "aprendiendo habilidades" (ADR 0004). Fuera de la 0.2.0.
- Efectos de la fama (#33).
