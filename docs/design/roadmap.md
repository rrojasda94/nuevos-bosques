# Hoja de ruta general

> Versión por versión: qué se hace y qué verá el jugador. El detalle de los PR está en la hoja de cada versión.
> Orden fijado por el dueño (2026-10-24): "continúa con lo que tienes pendiente y las dinámicas del juego, luego arreglamos mapa y jugabilidad. crea una lista de pasos a futuro y en qué versión veríamos esos cambios."
> **Cambio de orden (dueño, 2026-10-25):** el Mundo 2.0 iba a ir antes de cerrar lo que quedaba de la 0.3. Ese mismo día entró el último PR de la 0.3 (dormir, PR #49) y se publicó la 0.3.0 (PR #52), así que la 0.4 empieza ya.
> Versionado: `MINOR` sube con cada hito jugable (`CONTRIBUTING.md`). La 1.0.0 es la primera versión en Steam.

| Versión | Nombre | Estado | Hoja de ruta |
|---|---|---|---|
| 0.2.0 | Primer encargo | Publicada | `CHANGELOG.md` |
| 0.3.0 | El Bosque recuerda | Publicada | [`roadmap-0.3.md`](roadmap-0.3.md) |
| **0.4** | Mundo 2.0 | **En curso** | [`roadmap-mundo-2.md`](roadmap-mundo-2.md) |
| **0.5** | Dos caminos (antes "Los otros adoc") | Planificada; nombre y orden confirmados (ADR 0015) | [`roadmap-0.5.md`](roadmap-0.5.md) |
| 0.6 – 0.9 | Hacia Steam | Por planificar | Este documento ("Después") |
| 1.0 | Lanzamiento en Steam | — | Este documento ("Después") |

## 0.2.0 "Primer encargo" (publicada)
Misión del Ofomni, tiempo real con pausa y riutash, caminos, letreros, refugios, mapa y brújula, niveles del adoc, ofrendas y primeros sprites y sonidos.

## 0.3.0 "El Bosque recuerda" (publicada)
**Hecho**: el Bosque recuerda (vencer o pagar, hostilidad, Ofrecer Luz), frutos, inventario de 12 casillas y 3 ranuras, relación con los Bosques y peaje que caduca, reaparición tras una derrota y tileset con arte real.

**Hecho después**: Únicos en el mundo (PR #39), estados de Bosque (PR #41), sigilo y robo (PR #42), combate en grupo (PR #44) y dormir, Pensamiento y salvoconducto (PR #49).

**Qué verá el jugador**: Bosques que se comportan distinto según cómo los trates, Únicos que te buscan por el mundo (y de noche, Aledra), poder colarte sin ser visto o robar con consecuencias, peleas contra grupos con aliados, y dormir para saltar el tiempo y emprender viajes largos.

## 0.4 "Mundo 2.0"
ADR 0014. **En curso** desde el 2026-10-25.

**Pasos** (detalle y paralelismo en `roadmap-mundo-2.md`):
1. Ficha de diseño y spec de arte del mundo nuevo.
2. Formato de autoría para el dueño (PNG por capas + tabla de lugares) con validador y vista previa.
3. Generador nuevo: geografía de la región, relieve, puntos de interés, red de senderos, formas grandes y decoración variada.
4. Movimiento libre en 8 direcciones.
5. Caché y pregeneración en hilos; mundo continuo con carga por sectores.
6. Interacción, frutales, refugios, monstruos, mapa y brújula sobre el mundo nuevo.
7. Cambio al mundo nuevo y arte del relieve.
8. **Tarea del dueño**: pintar el Valle del Sara y poner sus villas y lugares.

**Qué verá el jugador**: un mundo con relieve (mesetas, riscos, escaleras, cascadas), moverse libre y fluido en 8 direcciones, sin parpadeos al cruzar chunks, villas con nombre y lugares fijos sobre el mapa del dueño, Bosques con árboles grandes, claros, lagunas y caminos que se notan, y mucha más variedad visual. Las partidas de la 0.3 no se pueden continuar.

## 0.5 "Dos caminos" (confirmada, ADR 0015)
> Confirmado por el dueño. Historia en pausa: primero mecánicas. La 0.5 combina "Los otros adoc" con el **camino garelino dentro de Aventura**: Senda y bando, encuentro de historia, grupo, persuasión de villas, siembra de Piedras, redención y finales. Orden propuesto en `roadmap-0.5.md`; los favores de Sarua, los artesanos y el Iserald pasarían a la 0.6. La lista siguiente es la anterior.

**Pasos** (detalle en `roadmap-0.5.md`):
1. NPC por oficio en las villas, con diálogos.
2. Senda (violenta, neutral, respetuosa) y puntos de stat y skills (ramas Sombra y Confianza).
3. Favores de los Sarua a cambio de ofrendas.
4. Artesanos (Paruas, Sarua) y materiales (madera, piedra, fibra, obsidiana, metal).
5. Encargos compartidos con otros adoc.
6. Salvar los Bosques: incendios, ataques y cordura.
7. Garelinos (enemigo humano, no letal).
8. Iserald y el estado Miedo (hacen falta 6–8 adoc).
9. Personalización del adoc (ropa y cabello), si no pasa a la 1.0 con el menú de inicio.

**Qué verá el jugador**: villas vivas con gente que te pide cosas, un adoc que crece según su forma de actuar, equipo hecho por artesanos con materiales del mundo, otros adoc con los que viajar y amenazas grandes (garelinos, Iserald) contra las que hay que unirse.

## Después: hacia la 1.0 en Steam
Sin orden cerrado. Se planificará al terminar la 0.5 (versiones 0.6 a 0.9 y 1.0):
- **Menú de inicio**: nueva partida, continuar, opciones y salir; elegir región y área de origen (ADR 0005); personalización del adoc si no entró en la 0.5.
- **Opciones**: volumen por bus, controles (reasignar acciones), pantalla completa y escala, accesibilidad (texto, contraste, velocidad de los mensajes).
- **Guardado múltiple**: varios slots con resumen (Bosque, día, nivel) y autoguardado.
- **Música** chiptune por Momento y por tipo de Bosque (`audio-designer`).
- **Steam**: GodotSteam, logros, Steam Cloud (solo los guardados; la caché del mundo no), Steam Input, página de la tienda y builds por tag (`release-manager`).
- **Modos Supervivencia y Garelino** (ADR 0004 y 0005): gestión de villa por días y el modo de los fanáticos. Son la parte más grande de este bloque y probablemente se repartan en varias versiones.
- **Interiores y lugares especiales** (propuesta para la 0.6): casas y refugios por dentro, tarcas y **sicabis** (lugares sagrados sin armas que regeneran Luz) (`mechanics/lugares-e-interiores.md`). Con la 0.6, también los favores de Sarua, los artesanos y el Iserald (ver `roadmap-0.5.md`).
- **Más regiones** del Sur Lenfi, pintadas por el dueño con el formato de autoría de la 0.4.
- Pulido y equilibrio por playtest; inglés queda para la 1.x (GDD).
