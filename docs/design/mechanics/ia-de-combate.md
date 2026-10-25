# Ficha: IA de combate (iniciativa, formación, roles y órdenes)

> Dueño: `game-designer`. **Versión 0.5 "Dos caminos"**, PR propio antes del grupo garelino (`roadmap-0.5.md`). Valores **provisionales**.
> Fuentes: palabras del dueño (abajo); `monstruos.md` (combate en grupo, reparep, garelinos, Ofomni descarriado), `otros-adoc.md` (aliados), `dos-caminos.md` (grupo garelino de hasta 5), `cruce-y-combate-v2.md` (acciones y fórmula de daño), `moralidad-y-progresion.md` (stats, skills).

## Objetivo
Que los combates en grupo sean tácticos: quién actúa antes, quién va delante, y aliados y enemigos que actúan con sentido.

Palabras del dueño (2026-10-25, sobre el grupo garelino): "Aqui deberiamos tener NPC inteligentes que tengan formaciones o sepan como atacar, defender, adelantar turnos, etc."

## Pilares
- **Pilar 3 (legibilidad 8-bit)**: dos filas (delante y detrás), un icono de rol por miembro y un orden de turnos visible en una línea.
- **Pilar 1**: el grupo que reúnes en el mundo (aliados, garelinos) se nota en el combate.

## Presión de supervivencia
- **Añade**: enemigos en grupo que se cubren, rematan al herido y se adelantan en el turno.
- **Alivia**: aliados que defienden al jugador herido y obedecen órdenes simples.

## Alcance
Escala desde el combate en grupo que ya existe: **1–4 enemigos** y **0–2 aliados**, y hasta **5 miembros** en el grupo garelino (más el jugador). El combate 1 contra 1 sigue igual: con un solo combatiente por lado, no hay formación.

## 1. Iniciativa (orden de turnos)
- Cada combatiente tiene **Agilidad (AGI)**. Propuesta:
  - adoc: 5 + ⌊nivel/2⌋;
  - Botarramas: 3 (renquea);
  - Ofomni: 6;
  - reparep: 7;
  - garelino: 5;
  - aliados adoc: igual que el jugador para su nivel.
- **Cada ronda**: orden = AGI + tirada de 0 a 2, de mayor a menor. Empate: primero el bando del jugador.
- **Defender** se resuelve **antes que nadie** en la ronda en que se elige (prioridad).
- **Acciones que mueven el turno**:

| Acción | Efecto |
|---|---|
| **Apresurar** | Atacas con −2 de daño, pero en la ronda siguiente actúas con AGI **+4** |
| **Esperar** | Actúas el último en esta ronda y tu ataque hace **×1,25** |

- El orden de la ronda se muestra en una línea de iconos sobre el combate.

## 2. Formación (delante y detrás)
- Cada bando tiene **2 filas**:
  - **delante**: hasta 3;
  - **detrás**: el resto.
- **Golpes cuerpo a cuerpo** (casi todos):
  - van a la fila **delante** con un **75%** de probabilidad, y detrás con un 25%;
  - si delante no queda nadie, todo va detrás.
- **Desde detrás**:
  - el ataque cuerpo a cuerpo hace **×0,75**;
  - los de rol **apoyo** usan su habilidad sin penalización.
- **Cambiar de fila** gasta el turno.
- Al empezar, el jugador va **delante**. Los aliados se colocan según su rol (defensor y atacante delante, apoyo detrás).
- **Ataques en área**: el ataque conjunto de los reparep y el Latigazo múltiple del Ofomni afectan a **toda la fila delantera**. Así la formación importa también contra un solo enemigo grande.

## 3. Roles
| Rol | Dónde | Bonificación | Habilidad (1 por combate salvo que se diga) |
|---|---|---|---|
| **Atacante** | Delante | +1 ATQ | **Remate**: +3 de daño contra un objetivo por debajo del 30% de PV |
| **Defensor** | Delante | +1 DEF | **Cubrir** (cada 2 rondas): durante 1 ronda, los golpes dirigidos a un aliado se los lleva él |
| **Apoyo** | Detrás | — | **Vendar**: cura el 20% de los PV máximos de un aliado (2 usos por combate). **Animar**: +2 ATQ a un aliado durante 1 ronda |

- El jugador no tiene rol: usa sus acciones y skills (`moralidad-y-progresion.md`).
- Rol de los miembros del grupo garelino y de los aliados adoc: por seed al reclutarlos, mostrado con un icono.
- Enemigos con grupo: garelinos (mezcla de los 3 roles) y reparep (todos atacantes, con ataque conjunto).

## 4. Comportamiento (IA)
Cada combatiente controlado por la IA elige su acción con una lista de **prioridades**. Se queda con la primera que se cumpla.

**Aliados y miembros del grupo (orden "Libre")**:
1. Si un aliado (o el jugador) tiene menos del **30% de PV**: el apoyo usa **Vendar** y el defensor usa **Cubrir** sobre él.
2. Si se anuncia un ataque fuerte del enemigo (Latigazo múltiple): el defensor usa **Cubrir** sobre quien está delante con menos PV, y los demás **Defender**.
3. Si tiene menos del **20% de PV** y no es defensor: pasa **detrás** (si estaba delante) o **Defender**.
4. Atacante: si hay un objetivo por debajo del 30%, **Remate**.
5. **Atacar**: objetivo con **menos PV absolutos**; si empatan, el de mayor ATQ (amenaza).

**Perfiles de enemigo**:
| Perfil | Quién | Objetivo y conducta |
|---|---|---|
| **Agresivo** | Botarramas, Ofomni, Aledra | Ataca al de menos PV de la fila delantera. No huye |
| **Enjambre** | Reparep | Ataque conjunto contra la fila delantera; se concentra en el de menos DEF. Si queda solo uno con menos del 30%, **huye** (se va del combate, sin XP) |
| **Táctico** | Garelinos | Usa roles (Cubrir, Vendar). Ataca primero al apoyo enemigo si está a tiro, si no al de menos PV. Con menos del 25% de PV, **se retira** (no letal) |
| **Berserk** | Ofomni descarriado | Agresivo, más el ataque fuerte cada 3 ataques; nunca huye |

## 5. Órdenes del jugador a sus aliados
Una orden de grupo que dura hasta que se cambie. Cambiarla **no gasta turno** (una vez por ronda):

| Orden | Efecto |
|---|---|
| **Atacar** | Todos atacan al **objetivo del jugador** (el último al que atacó); el atacante usa Remate si puede |
| **Defender** | Prioridad a Cubrir, Vendar y Defender; nadie ataca salvo para rematar |
| **Libre** (por defecto) | Cada uno sigue su lista de prioridades (sección 4) |

- **Tácticas preestablecidas** (para la 0.6, si hace falta): "Proteger al líder" (todo para mantener al jugador por encima del 50%) y "Concentrar fuego".

## Inputs / outputs
- **Inputs:** combatientes (stats, AGI, rol, fila), orden de grupo, perfiles de enemigo, anuncios de ataque fuerte.
- **Outputs:** orden de turnos por ronda, acciones elegidas por la IA, objetivos, cambios de fila, mensajes de narración.

## Interacción con otros sistemas
- Combate en grupo existente (reparep y aliados) y `cruce-y-combate-v2.md` (fórmula de daño).
- Grupo garelino (`dos-caminos.md`): roles al reclutar, retirada al caer.
- Iserald (combate de grupo grande, 0.6): los aliados en bloque pueden usar estas reglas resumidas.
- Narración estilo Pokémon: un mensaje por acción de IA ("El defensor cubre a…").

## Casos límite
- **Todos los de delante caídos o retirados**: los de detrás pasan a recibir todos los golpes, sin moverse de fila.
- **Vendar sin usos**: el apoyo ataca desde detrás (×0,75).
- **Cubrir sobre alguien que cambia de fila**: el Cubrir se mantiene esa ronda.
- **Empate de AGI entre aliados**: orden fijo de reclutamiento.
- **Combate 1 contra 1**: sin filas ni roles; se ignora la sección 2.
- **Enemigo que huye** (reparep): no cuenta como vencido para la XP de ese individuo.

## Criterios de éxito para playtest
- El jugador ve la orden de turnos y la usa ("me apresuré para actuar antes del latigazo").
- Los aliados parecen listos: curan o cubren al herido sin que se lo pidan (pregunta directa).
- El jugador cambia de orden ("Defender") al menos una vez en un combate difícil.
- El dueño siente que hay "formaciones" y que la IA "sabe atacar y defender" (pregunta directa).

## Preguntas abiertas
- **#174**: ¿AGI como stat nuevo del adoc (con puntos al subir de nivel) o solo derivada del nivel?
- ¿Los Botarramas y el Ofomni usan filas cuando vienen acompañados? (Por ahora pelean solos.)
