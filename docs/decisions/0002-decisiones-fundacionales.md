# ADR 0002 — Decisiones fundacionales de diseño

## Contexto
Respuestas del dueño del proyecto a las preguntas abiertas (2026-10-21).

## Decisiones
| Tema | Decisión |
|---|---|
| Nombre | **Nardaram: Los Nuevos Bosques** |
| Combate | Por turnos, por menú (Atacar / Habilidad / Objeto / Huir). Sin grid táctico. **Sustituido por ADR 0016**: combate táctico en cuadrícula estilo Final Fantasy Tactics Advance. |
| Ciudad | Por **días (turnos)**. El jugador termina el día y la simulación avanza un paso. Sin tiempo real. **Acotado por ADR 0012**: vale para la gestión de villa (Supervivencia). En Aventura el tiempo corre en tiempo real con pausa. |
| Vista | **Top-down** (estilo Zelda 2D) en exploración y ciudad. |
| Arte | Artista humano + placeholders generados por specs mientras llega el arte final. |
| Idioma | Solo **español**. Sin sistema de localización en MVP (strings en español directo; se centralizan en `data/` para poder traducir después). |
| Objetivo de partida | ~~**Supervivencia**: no hay final fijo; la partida dura mientras el pueblo sobreviva.~~ **Modificado por ADR 0004**: el objetivo lo fija el modo de partida (Supervivencia, Garelino, Aventura); la derrota es fallar la misión de la partida. |
| Steam | Sin cuenta aún. `release-manager` prepara checklist; no bloquea desarrollo. |

## Consecuencias
- `TickTimer` se reemplaza por `DayManager`: la señal es `EventBus.day_ended(day)`, emitida por acción del jugador.
- La capa RPG (expediciones) consume días: una expedición = N días de ciudad.
- ~~Condición de derrota explícita (ej. población 0 o hambruna X días). La define `game-designer`.~~ Sustituido por ADR 0004: derrota = fallar la misión de la partida.
- `pixel-artist` fija perspectiva top-down 3/4 en la guía de estilo.
