# Ficha: Senda (moralidad) y puntos de stats y skills

> Dueño: `game-designer`. **Propuesta para la 0.4 "Los otros adoc"**. Valores **provisionales**.
> Fuentes: palabras del dueño (abajo); `progresion-adoc.md` (tabla de niveles), `cruce-y-combate-v2.md` y ADR 0013 (hostilidad, relación), `bosques-y-relacion.md` (relación, robo, fruto, salvoconducto), `monstruos.md` (fatales, Iserald), ADR 0004 (regla de no matar), `npcs-y-villas.md`, `otros-adoc.md`.

## Objetivo
Que el jugador elija cómo ser adoc y que esa elección se note. Palabras del dueño (2026-10-24): "poder ser un adoc malo y poderoso o uno que se apega a las reglas y avanza con calma. podemos incluir puntos de stats o skills."

## Pilares
- **Pilar 1 (dos capas)**: tu forma de actuar en el Bosque cambia cómo te reciben las villas.
- **Pilar 2**: cada nivel da una elección visible (un punto de stat y, en los pares, un punto de skill).
- **Pilar 4**: dos partidas pueden jugarse de formas opuestas.

## Presión de supervivencia
- **Senda violenta**: más poder rápido (XP, botín, golpes fuertes), pero Bosques hostiles, villas que desconfían y riesgo de atraer peligros mayores.
- **Senda respetuosa**: más lenta en XP, pero más barata y con más ayuda (relación, salvoconductos, frutos, aliados, mejores precios).

## Senda
- Valor por partida, de **−100 (violenta)** a **+100 (respetuosa)**. Empieza en **0**. Se guarda con la partida y se reinicia con un game over o una partida nueva.
- La Senda mide el trato con **los Bosques y sus Únicos**. La regla de no matar gente (ADR 0004) sigue valiendo en cualquier Senda: un adoc "malo" no mata personas.

### Qué la mueve
| Acción | Cambio |
|---|---|
| Vencer a un Botarramas (Bosque forzado) | −3 |
| Robar (fruto extra, fruto de un Bosque no pagado; más adelante, objetos) | −10 |
| Sacar un fruto guardado de su Bosque | −1 |
| Pagar el peaje con Luz | +1 |
| Pagar con ofrenda | +2 |
| Dejar una ofrenda voluntaria junto a un Nujio | +1 |
| Completar un favor de Sarua sin violencia | +3 |
| Ayudar a otro adoc en combate | +2 |
| Salvar un Bosque (incendio o ataque) | +5 |

Vencer al Ofomni descarriado de una misión **no** mueve la Senda: es un encargo legítimo.

### Efectos (umbrales provisionales)
| Senda | Efectos |
|---|---|
| **≤ −60**, violenta | XP de victoria **+25%**. Al entrar por primera vez en un Bosque, su hostilidad empieza en **1**. Villas: precios **×1,5**; los Sarua solo dan favores de "llevar algo"; los adoc NPC no proponen encargos compartidos. |
| **−59 … −30** | XP +10%. Villas: precios ×1,25. |
| **−29 … +29**, neutra | Sin efectos. |
| **+30 … +59** | Ganancias de relación **+50%**. Villas: precios ×0,85; recompensas de Sarua +1. |
| **≥ +60**, respetuosa | Además: peaje **−1** en todos los Bosques (mín. 1); las visiones de Pensamiento al dormir pasan de 1/2 a **2/3**; los Bosques en necesidad de ayuda dan **2** aliados en vez de 1. |

- Que la Senda muy violenta (≤ −80) atraiga a **Iserald** (fatal) es una idea pendiente del dueño (#152).
- **Visibilidad**: propuesta de un icono de Senda en la pantalla de estado (de 5 tramos) sin mostrar el número (#151).

## Puntos de stats y skills al subir de nivel
Coherente con la tabla de `progresion-adoc.md`: hoy cada nivel da +4 PV y +1 ATQ o +1 DEF de forma fija. La propuesta mantiene el mismo poder total y convierte el +1 en elección.

### Stats
- **Automático por nivel**: **+4 PV máx.** (como ahora).
- **1 punto de stat por nivel** (desde el nivel 2), a elegir:

| Opción | Efecto |
|---|---|
| ATQ | +1 |
| DEF | +1 |
| Vigor | +4 PV máx. (además de los automáticos) |
| Luz | +2 al límite de Luz suelta (`luz_max`) |

- **Reparto recomendado** (el que sugiere la UI por defecto): el de la tabla actual (ATQ en los niveles no múltiplos de 3, DEF en los múltiplos de 3). Así, los valores de la tabla siguen siendo una referencia válida.
- **Comprobación contra el Ofomni** (d = 4, PV ×0,7 = 24/8/3, Latigazo múltiple), con los 2 puntos hasta el nivel 3:
  - todo a ATQ (8/3): gana con unos 33 de daño recibido de 38;
  - reparto recomendado (7/4): gana con unos 32;
  - todo a DEF (6/5): gana con unos 35.
  - Ningún reparto rompe la dificultad confirmada.

### Skills
- **1 punto de skill en los niveles 2, 4, 6, 8 y 10** (5 en total).
- **2 ramas de 3 skills** en cadena (hay que tener la anterior de la rama). La tercera de cada rama exige un mínimo de Senda. Con 5 puntos no se pueden completar las dos ramas.

| Rama | Skill | Efecto (provisional) | Requisito |
|---|---|---|---|
| **Golpe** | G1 Golpe fuerte | Acción nueva: daño ×1,5. Una vez cada 3 turnos | — |
| | G2 Botín | Al vencer a un Único, 25% de dejar una ofrenda de 3–4 | G1 |
| | G3 Imponerse | Opción en el menú del borde: si tu nivel ≥ d + 2, el Botarramas se aparta sin pelear. Cuenta como vencerlo (Bosque forzado, hostilidad +1, relación −10), sin XP | G2, Senda ≤ −30 |
| **Apaciguar** | A1 Palabra suave | Peaje −1 (mín. 1) | — |
| | A2 Descanso del Nujio | El riutash en refugio dentro de un Bosque pagado cura el 75% de lo que falta (en vez del 50%) | A1 |
| | A3 Llamada del Bosque | En Bosques con relación ≥ 30, un Único del Bosque pelea a tu lado (aliado, necesita el combate en grupo) | A2, Senda ≥ +30 |

## Conexión con lo que ya existe
- **Hostilidad y relación** (ADR 0013): siguen siendo por Bosque. La Senda es global y las modifica (hostilidad inicial, ganancias de relación).
- **Fama** (`progresion-adoc.md`): no depende de la Senda. Un adoc violento también puede ser famoso.
- **Robo**: baja la Senda, la relación y sube la hostilidad.
- **Fatales**: la Senda no cambia `fatal_at`. Atraer a Iserald queda pendiente (#152).

## Inputs / outputs
- **Inputs:** acciones del jugador (tabla), subida de nivel, elección de puntos.
- **Outputs:** Senda, stats del adoc, skills desbloqueadas, modificadores en villas, Bosques y combate.

## Casos límite
- **Partida de la 0.3 sin puntos**: al cargarla, se asignan los puntos según el reparto recomendado (mismos stats que antes) y se dan los puntos de skill que correspondan al nivel.
- **Senda en el límite**: −100 y +100 son topes.
- **Imponerse contra un Botarramas de un Bosque enojado**: no funciona (`bosques-y-relacion.md`: allí hay que vencer o colarse).

## Criterios de éxito para playtest
- Dos testers juegan la misma seed con Sendas opuestas y describen partidas distintas.
- El jugador entiende por qué una villa le cobra más (pregunta directa).
- Ningún reparto de puntos hace imposible la misión del Ofomni.

## Preguntas abiertas
- **#151**: ¿la Senda se ve (icono, barra, número) o es oculta?
- **#152**: ¿una Senda muy violenta atrae a Iserald (fatal) o cambia los fatales?
- **#156**: ¿se confirman 1 punto de stat por nivel y 1 de skill cada 2 niveles, o se prefiere un sistema más grande?
