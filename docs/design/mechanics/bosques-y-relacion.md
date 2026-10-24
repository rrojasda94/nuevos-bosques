# Ficha (backlog): Bosques con carácter y relación con el adoc

> Dueño: `game-designer`. **Backlog, después de la 0.2.0.** El dueño pidió dejarlo pendiente ("algo que quiero que quede pendiente tambien...").
> Sin números cerrados: solo el modelo de datos, cómo se combinaría con el peaje y las preguntas. Fuentes: palabras del dueño (abajo); glosario §3 ("Nujio": "Puede perder la cordura, evolucionar y cansarse de existir"; "Iserald"), §6 ("Salvoconducto"; "Multiplicador de valor" del Ista, de −5 a +5) y §7 ("Nuevos Bosques"); ADR 0004 (garelinos); `cruce-y-combate-v1.md`; `monstruos.md`.

## Objetivo
Que cada Bosque tenga carácter propio y que la relación del adoc con él cambie lo que cuesta cruzarlo. Así no hay una sola ruta óptima: hay rutas buenas según con quién te lleves bien.

Palabras del dueño (2026-10-24):
> "algo que quiero que quede pendiente tambien es el tipo de bosque y cuan agresivo o pacifico es, tambien su nivel de cordura, si está siendo atacado o no. Tambien tener en cuenta los nuevos bosques que no cobran luz y tienen otro tipo de vida silvestre con seres mas similares a mamiferos o reptiles. Aparte si un bosque diferente te llama para una misión, este no te cobra Luz puede ayudarte a tener una ruta de salvoconducto por bosques buenos que no necesariamente es la ruta más corta. Mejorar la relación con algunos bosques puede ayudarte a bajar el precio de Luz por cruzar o estar ahí."

## Pilares
- **Pilar 4 (cada partida es distinta, cada región se reconoce)**: el temperamento y la cordura de cada Bosque cambian con la seed.
- **Pilar 1 (dos capas)**: las misiones para un Bosque mejoran la relación, y eso abarata los viajes.
- **Pilar 3 (legibilidad)**: el carácter del Bosque tiene que poder leerse (color, Botarramas, texto del letrero o del mapa).

## Presión de supervivencia
- **Añade**: hay Bosques agresivos, con poca cordura o bajo ataque, más caros o peligrosos de cruzar.
- **Alivia**: la buena relación, las misiones de un Bosque y los Nuevos Bosques (sin peaje de Luz) abaratan los viajes.

## Lo que dijo el dueño (reglas)
1. Cada Bosque tiene un **tipo** y un grado de **agresivo a pacífico**.
2. Cada Bosque tiene un **nivel de cordura**. Enlaza con el glosario §3: el Nujio "puede perder la cordura", y una teoría sobre Iserald es la pérdida de cordura.
3. Cada Bosque puede estar **siendo atacado o no**. Enlaza con los garelinos (ADR 0004).
4. Los **Nuevos Bosques no cobran Luz** y tienen **otra fauna**: "seres más similares a mamíferos o reptiles" (glosario §7: conciencia mínima, una sola misión, no requieren Luz).
5. Si **un Bosque te llama para una misión**, **no te cobra Luz** y puede darte una **ruta de salvoconducto** por **Bosques buenos**, que **no tiene por qué ser la más corta** (glosario §6: "Salvoconducto: permiso de algunos oficios para viajar entre lugares").
6. **Mejorar la relación** con un Bosque **baja el precio de Luz** por **cruzar** o por **estar ahí**.

## Modelo de datos propuesto (por Bosque)
| Campo | Tipo | Rango propuesto | Origen |
|---|---|---|---|
| `kind` | enum | `nujio`, `nuevo_bosque` (más adelante, `desierto`…) | Generación (seed + región) |
| `temperament` | int | −2 (agresivo) … +2 (pacífico) | Generación |
| `sanity` | int | 0 (sin cordura) … 100 (cuerdo) | Generación. Cambia con eventos (ataques, misiones) |
| `under_attack` | bool (+ `attacker`) | — | Estado del mundo (garelinos) |
| `relation` | int, **guardado por partida** | −100 … +100 (empieza en 0) | Acciones del adoc |

- `relation` es lo único que depende del jugador; el resto es estado del Bosque.
- Como fuente de diseño (no decidido): el glosario §6 tiene un **multiplicador de valor del Ista de −5 a +5**, aplicado como ±1.x sobre el valor nominal. Podría inspirar la escala de `relation` o de `temperament`.

## Cómo se combinaría con el peaje (sin números cerrados)
Peaje actual: **N = base + per_d · d** (`toll` en `balance.json`).

Propuesta de forma:

```
si kind == nuevo_bosque                  -> peaje de Luz = 0 (regla del dueño)
si el Bosque te ha llamado a una misión  -> peaje = 0 en él y en su ruta de salvoconducto
si no:
  N = (base + per_d·d) × f_temperament × f_relation × f_sanity × f_attack
```

| Factor | Idea | Dirección |
|---|---|---|
| `f_temperament` | Agresivo, más caro; pacífico, más barato | Por ejemplo, de ×1,4 a ×0,7 |
| `f_relation` | Buena relación, más barato (regla del dueño) | Por ejemplo, de ×1,3 a ×0,5 |
| `f_sanity` | Poca cordura: el Bosque no acepta pagar, solo combate, o el peaje sube | Por definir |
| `f_attack` | Bajo ataque: ¿más desconfiado (más caro) o pide ayuda (misión)? | Por definir |

- Redondeo y mínimo: N ≥ 1 salvo en los casos de peaje 0.
- **Ruta de salvoconducto**: camino en el grafo de Bosques restringido a Bosques "buenos" (por ejemplo, `relation` ≥ umbral o `temperament` ≥ 1), desde el Bosque que llama hasta la villa o el objetivo de la misión. No tiene por qué ser el más corto. Mientras dure la misión, no se cobra peaje en esos Bosques.

## Cómo cambia la relación (propuesta, sin números)
| Acción del adoc | Efecto en `relation` |
|---|---|
| Completar una misión para ese Bosque | Sube mucho |
| Pagar el peaje (Luz u ofrenda) | Sube poco |
| Vencer a sus Botarramas | Baja poco |
| Robar en él (0.3.0, `sigilo-y-robo.md`) | Baja mucho |
| Entrar con el arma equipada (0.3.0) | Baja poco |

## Otros efectos posibles
- **Temperamento**: modifica el `vision_radius` y la `step_time` de sus Botarramas, y cuántos hay.
- **Cordura baja**: más riesgo de Iserald (fatal). Coherente con el glosario, pero sin decidir.
- **Bajo ataque**: puede generar misiones de "ayuda al Bosque" que dan salvoconducto.
- **Nuevos Bosques**: fauna distinta (mamíferos y reptiles), sin Botarramas ni peaje. ¿Hay peligros?

## Casos límite (para cuando se implemente)
- Un Bosque con buena relación pero agresivo: ¿qué factor manda?
- Una misión termina mientras el jugador está a mitad de la ruta de salvoconducto.
- Un Bosque de la ruta pierde cordura o pasa a estar bajo ataque durante la misión.
- Relación negativa extrema: ¿el Bosque deja de aceptar el peaje?

## Criterios de éxito para playtest (borrador)
- El jugador nota que un Bosque es agresivo o pacífico antes de llegar al borde.
- El jugador elige alguna vez una ruta más larga porque es más barata o más segura.
- Tras una misión para un Bosque, el jugador nota que cruzarlo le cuesta menos.

## Preguntas abiertas
- **#133**: ¿qué tipos de Bosque hay además de Nujio y Nuevo Bosque? ¿Cómo se ven el temperamento y la cordura (color, letrero, mapa)?
- **#134**: "precio de Luz por estar ahí": ¿hay un coste por permanecer en un Bosque (por Momento, por día)? ¿Cuánto y cómo se cobra?
- **#135**: relación: ¿qué acciones la cambian y cuánto? ¿Es por Bosque o por grupo de Bosques? ¿Se guarda entre partidas?
- **#136**: salvoconducto: ¿qué es un "Bosque bueno"? ¿Cuánto dura el salvoconducto (la misión, X días)? ¿Lo da el Bosque que llama o un oficiante (el glosario §6 lo asocia a oficios)?
- **#137**: Nuevos Bosques: ¿qué fauna tienen (mamíferos o reptiles, peligrosos o no) y hay algún coste para cruzarlos que no sea Luz?
- **#138**: cordura y ataque: ¿cómo bajan o suben? ¿Qué efecto de juego tienen (peajes, Iserald, misiones)? ¿Quién ataca, además de los garelinos?
