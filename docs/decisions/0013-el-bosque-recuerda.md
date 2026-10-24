# ADR 0013 — El Bosque recuerda: vencer frente a pagar, hostilidad y Ofrecer Luz

> Versión 0.3 "El Bosque recuerda", PR 1. **Sustituye** lo que dicen ADR 0009 y `docs/design/mechanics/cruce-y-combate-v1.md` sobre la apertura de Bosques al vencer y sobre la acción "Ofrecer Luz". Reglas vigentes en `docs/design/mechanics/cruce-y-combate-v2.md`.

## Contexto
Hasta la 0.2.0, vencer al Único (o Botarramas) de un borde abría el Bosque entero para siempre, y "Ofrecer Luz" hacía 8 de daño. El dueño dio dos reglas (2026-10-24):

> "una vez vencido al botarrama los demas botarramas deberian volver a exigir un pago si esan en el mismo bosque. el bosque recuerda, mira observa. ser hostil con sus Únicos es peligroso."

> "ofrecer luz hace 8 de daño en vez de terminar con la lucha."

Lectura: hoy Ofrecer Luz hace 8 de daño, y debería **terminar la pelea**.

## Decisión (valores provisionales, ya en implementación por `rpg-systems-dev`)

### Vencer frente a pagar
| Acción | Efecto |
|---|---|
| **Pagar** el peaje (Luz u ofrenda, en el borde o en combate) | El Bosque queda **pagado**: todos sus Botarramas pasan a **pasivos**. |
| **Vencer** a un Botarramas | **Solo ese** se disuelve ("vuelve a la Luz del Bosque"). El Bosque queda **forzado**: se puede cruzar por ese tramo, pero **sus otros Botarramas siguen activos y exigen pago**. |

### Hostilidad y relación
- **Hostilidad** por Bosque: **+1 por cada Botarramas vencido**.
  - **Peaje**: N = 3 + d + **2 × hostilidad**, con tope de hostilidad en `balance.json`.
  - **Visión**: `vision_radius` de sus Botarramas **+2 por nivel** de hostilidad (tope +6).
- **Relación** por Bosque, de −100 a 100: **−10 por victoria** contra sus Botarramas y **+1 al pagar**. Es la base de la relación completa de `bosques-y-relacion.md` (PR 2 de la 0.3).

### Ofrecer Luz
- **Ofrecer Luz** en combate = **pagar el peaje N actual con Luz suelta**. El Único **se va** y el Bosque queda pagado. **Sin XP** ni Luz de victoria.
- **Se elimina** el "8 de daño" (`offer_luz.damage`).
- Contra el **Ofomni** está **desactivado** (la misión es vencerlo).
- "Ofrecer ofrenda" en combate funciona igual, con una ofrenda (`ofrendas-v1.md`).

### Ajuste del Ofomni
Sin el daño de Ofrecer Luz, el Ofomni de la misión era imposible para un nivel 3. Se reducen sus PV (detalle y números en `mision-ofomni.md`). El coordinador propuso −15%; `game-designer` recomienda −30% para mantener la dificultad que confirmó el dueño ("ganable desde nivel 3").

## Consecuencias
- `open_bosques` pasa a distinguir **pagado** y **forzado** por Bosque, y se guarda la hostilidad y la relación por Bosque (formato: `engine-architect` / `rpg-systems-dev`).
- Pelear da XP pero vuelve el Bosque más caro y más atento. Pagar es más barato a la larga. Es la tensión que pidió el dueño ("ser hostil con sus Únicos es peligroso").
- La progresión (`progresion-adoc.md`) ya no puede contar con "Ofrecer Luz" para bajar el umbral de nivel.
- Abiertas: si la hostilidad baja con el tiempo, si el estado "forzado" caduca y si reaparecen los Botarramas disueltos (#147); confirmar el ajuste del Ofomni (#148).
