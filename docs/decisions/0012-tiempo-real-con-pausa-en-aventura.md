# ADR 0012 — Tiempo real con pausa en Aventura

## Contexto
ADR 0002 fijó: "Ciudad por **días (turnos)**. El jugador termina el día y la simulación avanza un paso. Sin tiempo real." En la 0.1.0 el tiempo no avanza en Aventura, y el dueño lo pidió para la 0.2.0 ("el tiempo no está avanzando"). Al preguntarle cómo, respondió (2026-10-23):

> "manejalo como dungeon keeper. Solo recuerda que entre dia y noche esta el riutash. debe haber una alerta para buscar refugio antes del riutash porque puede causar daño."

Lectura: **tiempo real con pausa**, como Dungeon Keeper. Lectura del coordinador, aprobada en el plan de la 0.2.0.

## Decisión
- **Modo Aventura**:
  - El tiempo corre en **tiempo real** mientras se explora.
  - Se **detiene** con cualquier pausa: menú de pausa, mapa (M), diálogo, menú del borde y combate.
  - El reloj alterna el **Momento de Gietos** (día) y el **Momento de Riumna** (noche) (glosario §1). Entre uno y otro ocurre el **riutash** (glosario §2).
- Antes de cada riutash hay **avisos** para buscar refugio. Exponerse al riutash daña y refugiarse cura en parte.
- Duraciones, avisos y efectos: provisionales, en `data/world/time.json`. Las reglas están en `docs/design/mechanics/tiempo-y-riutash.md`.
- El contador de **día** avanza en el riutash del amanecer (Riumna → Gietos).
- El "sin tiempo real" de ADR 0002 queda **acotado a la gestión de villa** (modo Supervivencia, fuera del MVP). Si Supervivencia usará también tiempo real con pausa queda abierto (#121).

## Consecuencias
- Nuevo autoload `WorldClock` (implementación: `engine-architect`, PR 4 de la 0.2.0).
- `DayManager` deja de depender de "terminar el día" en Aventura.
- Las mecánicas temporales que dependían del ciclo día/noche se activan:
  - curación y daño del riutash (ADR 0010);
  - avance del Ofomni (`mision-ofomni.md`).
  - Quedan para después: regeneración de Únicos (#120), estamina (#73) y peligros de la noche (#75).
- ADR 0002 se anota con este cambio.
