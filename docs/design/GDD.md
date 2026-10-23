# GDD — Nardaram: Los Nuevos Bosques

> Dueño: `game-designer`. Estado: borrador v0.4 (incorpora ADR 0002, 0003 y 0004, rondas 1 y 2).

## Visión
Cada partida ocurre en Nardaram, en un chunk de 64×64 tiles generado con seed, y tiene un **modo elegido al empezar** (Supervivencia, Garelino o Aventura) con su propia misión (ADR 0004). En el centro del conflicto está el **Nujio**, un árbol gigantesco que domina los bosques y tiene poder sobre las villas, y los **garelinos**, fanáticos que quieren destruir esos bosques para sembrar los Nuevos Bosques. Pixel art 8-bit top-down, sesiones cortas, progreso visible. Solo español.

> Por revisar: la visión anterior ("refundar un pueblo en un bosque arrasado") y la gestión de ciudad por días (ADR 0002) no aparecen en la descripción que el dueño hizo de los modos. Cómo encajan las dos capas en cada modo está por definir (#29). La generación del mundo también está abierta (#27, prioritaria).

## Pilares
1. Dos capas, un mundo. (Encaje por modo: por definir, #29.)
2. Sesiones cortas con progreso visible (15 min = algo nuevo).
3. Legibilidad 8-bit.
4. **Cada partida es distinta, cada región se reconoce**: la seed cambia la disposición, la región mantiene su identidad.

## Loop principal (por días)
> Loop previo a ADR 0004. Por revisar para cada modo (#29).
```
Inicio del día: ver estado del pueblo (comida, gente, amenazas) y de la misión
   ↓
Fase de ciudad: construir, asignar trabajos, gestionar almacén
   ↓
(opcional) Expedición: elegir destino en el chunk → explorar → combates por menú → loot/supervivientes
            Consume 1–3 días (pendiente #12); el pueblo sigue simulándose mientras tanto.
   ↓
Fin del día: producción → consumo → necesidades → eventos → chequeo de misión
```

## Modos de partida (ADR 0004)
El modo se elige al empezar, de forma similar a Project Zomboid. **Derrota = fallar la misión de la partida.**

| Modo | Qué haces | Victoria | Derrota |
|---|---|---|---|
| **Supervivencia** | Mantienes con vida al Nujio. Es un modo largo: debes evitar que los garelinos enloquezcan al Nujio o aniquilen el bosque. A quién controlas: por definir (#28). | No hay. | Los garelinos enloquecen al Nujio o aniquilan el bosque (reglas concretas: por definir, #39). |
| **Garelino** | Comandas un grupo de fanáticos que buscan destruir los bosques dominados por un Nujio. Mejoras tus tropas, aprendes habilidades y estrategias para acelerar la decadencia y reclutas nuevos individuos. Te enfrentas a los Humores del mundo, a los Únicos que envía el bosque y a la resistencia de la población de la villa. | Eliminar al Nujio y sembrar las primeras semillas de los Nuevos Bosques. | Quedarte sin individuos. |
| **Aventura** | Creas un personaje que viaja de lugar en lugar según las misiones que aparezcan (derrotar Únicos; las villas suelen llamar al adoc). Subes experiencia, aprendes habilidades, ganas objetos y fama. | Por definir (#31). | Muerte del personaje = game over. |

### Reglas de no matar
- **Aventura**: no se puede matar gente donde haya otras personas o seres con consciencia (qué ocurre si se intenta: por definir, #34).
- **Garelino**: matar gente afecta mucho a la reputación del grupo y hace más difícil el trabajo, o vuelve a los enemigos más agresivos y fuertes (medida y efectos: por definir, #35).

### Recursos nuevos sin definir
Antes de implementarse necesitan fuente, sumidero y qué pasa si se agotan:
- Fama (Aventura): por definir (#33).
- Reputación del grupo (Garelino): por definir (#35).
- Individuos/tropas (Garelino): cuando llegan a 0, derrota. Reclutamiento y mejora: por definir (#37).

### Presiones de supervivencia por modo
- Supervivencia: los garelinos (sobre el Nujio y el bosque). Resto: por definir.
- Garelino: Humores del mundo, Únicos, resistencia de la villa, pérdida de individuos, reputación.
- Aventura: muerte permanente del personaje. Resto: por definir.

## Mundo (ADR 0003, ADR 0004)
- **Generación del mundo: pregunta abierta prioritaria (#27).** El dueño la comparó con Minecraft y Dwarf Fortress (a confirmar). Puede seguir el mapa mundial hecho a mano de ADR 0003 o generarse entero.
- Mapa mundial (según ADR 0003, vigente): `data/world/world_map.json` + arte de referencia en `docs/design/world/`.
- Región → bioma, clima, relieve, facción, recursos, peligro.
- Chunk: **64×64 tiles.** Puede tener o no una villa al generarse.
- Villa: edificios pequeños que sirven como habitaciones para dormir o almacenar; el resto de estructuras está al aire libre. Tamaño: por definir (#14b).
- Nujio: suele estar en el centro de la villa; ocupa "entre 6x6 y 8x8 de diámetro" (unidad: por confirmar, #40).

## Capa ciudad (MVP)
> Por revisar frente a villas, Nujio y modos (#14b, #29). La hoguera en el centro choca con que el Nujio esté en el centro de la villa.
- Grid 16×16 top-down.
- Recursos: madera, piedra, comida, oro.
- Edificios iniciales: hoguera (centro), cabaña, aserradero, cantera, huerto, herrería.
- Ciudadanos: llegan por expediciones; necesitan cabaña y comida; trabajan en un edificio.
- Producción/consumo **por día** en `data/buildings/`.

## Capa RPG (MVP)
> Por revisar: en Aventura se crea un solo personaje y en Garelino se comandan tropas (#32).
- Party de hasta 3. Stats: HP, ATK, DEF, SPD.
- Combate por turnos, menú: Atacar / Habilidad / Objeto / Huir.
- Exploración top-down del chunk; encuentros según bioma de la región.
- Inventario 12 slots. Equipo: arma, armadura, accesorio.

## Glosario (provisional)
> **Provisional.** El dueño del proyecto dejará en la carpeta del proyecto un `.md` con el glosario de Los Nuevos Bosques. Cuando llegue, este glosario se conciliará con ese archivo y ese archivo manda. Aquí solo está lo dicho por el dueño; lo demás está por definir (dueño del lore: `narrative-writer`).

| Término | Definición |
|---|---|
| **Nujio** | Árbol gigantesco ("gran árbol") que tiene poder sobre el actuar de la villa. Por lo general está en el centro de la villa y ocupa entre 6x6 y 8x8 de diámetro. Domina bosques. En Supervivencia hay que mantenerlo con vida; en Garelino, eliminarlo. Resto: por definir (#39, #41). |
| **Garelinos** | Grupo de fanáticos que buscan destruir los bosques dominados por un Nujio. Al eliminar al Nujio siembran las primeras semillas de los Nuevos Bosques. Enemigos en Supervivencia; el grupo del jugador en el modo Garelino. Origen y motivación: por definir. |
| **Nuevos Bosques** | Lo que siembran los garelinos tras eliminar al Nujio ("las primeras semillas de los nuevos bosques"). Resto: por definir. |
| **Únicos** | Monstruos defensores de bosques que se han descarriado y entrado en modo berserk. Hay muchos tipos. Objetivo de las misiones de Aventura; en Garelino, el bosque los envía contra el jugador. Tipos y número: por definir (#20, #22, #44). |
| **adoc** | Al que las villas suelen llamar para combatir a los Únicos. Qué es exactamente: por definir (#23). |
| **Villa** | Lugar de edificios pequeños que sirven como habitaciones para dormir o almacenar; el resto de estructuras está al aire libre. Un chunk puede tener o no una. Su población resiste a los garelinos. Llaman al adoc contra los Únicos. |
| **Humores del mundo** | Climas agresivos que ocurren si el grupo garelino delata su intención y su ubicación. Tipos y efectos: por definir (#36). |

## Fuera de alcance del MVP
Multijugador, mods, más de una región jugable, localización (inglés en v1.x). (Qué modos entran en el MVP: por definir.)

## Métricas de playtest
- Tiempo hasta el primer edificio construido: < 3 min. (Por revisar según modo, #29.)
- Tiempo hasta la primera expedición: < 8 min. (Por revisar según modo, #29.)
- Jugador describe el loop sin ayuda tras 15 min.
- Duración media de partida antes de la primera derrota: 20–40 días (valor previo a ADR 0004; por revisar por modo).

## Pendiente
Ver `docs/decisions/0000-preguntas-abiertas.md`.
