# Ficha: Ofrendas v1

> Dueño: `game-designer`. Versión 0.2.0 "Primer encargo". Fuentes: ADR 0010 (ofrendas, Luz suelta y su límite, uso en combate), glosario §5 (Sarua: "objetos para entregar Luz, talismanes de viaje").
> **Valores y nombres PROVISIONALES**, en `data/items/items.json` (kind `ofrenda`). `narrative-writer` puede renombrarlas. Implementación: `rpg-systems-dev` (PR 7).

## Objetivo
Dar al jugador una forma de guardar Luz por encima del límite de Luz suelta, y una decisión de gestión: cada ofrenda se gasta **entera**.

Palabras del dueño: "uno puede almacenar Luz cuando una villa le otorga ofrendas, estos artefactos pueden tener diferente valor en Luz y se usan de forma entera, es decir debes dejar el artículo entero en el bosque y pierdes su Luz total del valor. Así que es bueno saber administrar los recursos." Y: "Existe Luz suelta pero tienes un límite interior de Luz suelta que puedes tener ejemplo: 10. El resto si requiere items. Si, puedes ofrecer ofrendas en combate para que el Único se vaya." Y sobre esto último: "paso abierto".

## Pilares
- **Pilar 1 (dos capas)**: las villas dan ofrendas y las ofrendas abren el Bosque.
- **Pilar 3 (legibilidad 8-bit)**: un objeto, un número.

## Presión de supervivencia
- **Añade**: hay que decidir qué ofrenda gastar. Pagar un peaje de 4 con una ofrenda de 8 desperdicia 4.
- **Alivia**: más reserva de Luz para cruzar o para salir de un combate perdido.

## Reglas

### Catálogo inicial (provisional)
| id | Nombre provisional | Valor (Luz) | Dónde se consigue en la 0.2.0 |
|---|---|---|---|
| `cuenta_de_barro` | Cuenta de barro | 3 | Hallazgo en refugios |
| `trenza_votiva` | Trenza votiva | 4 | Hallazgo en refugios |
| `talisman_de_viaje` | Talismán de viaje | 5 | Más adelante: villas y misiones. Los Sarua hacen "talismanes de viaje" (glosario §5) |
| `cuenco_ritual` | Cuenco ritual | 6 | Recompensa de la misión del Ofomni (`mision-ofomni.md`) |
| `figura_sarua` | Figura sarua | 8 | Más adelante: misiones difíciles |

### Fuentes
- **Hallazgos**: los refugios (`navegacion.md`) guardan una ofrenda pequeña en **1 de cada 3** (determinista por seed). Mitad Cuenta de barro (3), mitad Trenza votiva (4). Se recoge con E **una sola vez por partida** (persistente).
- **Recompensa de misión**: el Cuenco ritual (6) de la misión del Ofomni.
- **Villas**: más adelante, por misiones de villa (#106).

### Uso
- **Pagar un peaje** (menú del borde, `cruce-y-combate-v1.md`) con la opción nueva "Ofrecer una ofrenda":
  - Se elige **una** ofrenda. Si su valor es menor que N, se **completa con Luz suelta**; si no alcanza ni así, la opción no está disponible para esa ofrenda.
  - La ofrenda se deja **entera**: si su valor supera N, el excedente **se pierde**.
  - Abre el borde como pagar con Luz.
- **En combate contra un Único** (acción nueva "Ofrecer ofrenda"):
  - Misma regla que el peaje: una ofrenda, completada con Luz suelta si hace falta, hasta llegar a N del Bosque.
  - El Único **se va** y el paso queda **abierto** (ADR 0010).
  - No da XP ni la Luz de victoria.
  - Gasta el turno. Si no se puede pagar, la acción aparece desactivada.
- **Contra el Ofomni**: no se puede usar (`mision-ofomni.md`).
- **"Ofrecer Luz"** (2 de Luz, 8 de daño) sigue usando solo Luz suelta; las ofrendas no se fraccionan.

### Inventario
- **Provisional**: una **lista sin límite** de `{id, luz}`. La decisión entre cuadrícula (Diablo), slots (Minecraft) y peso (Kingdom Come: Deliverance) sigue abierta (#113).
- Se ve en la pantalla de estado (tecla I).

### Luz suelta y límite
- Luz suelta entre 0 y `luz_max` = 10 (provisional). Lo que supere el límite **se pierde** (el código ya la topa; #115).
- Las ofrendas **no cuentan** para `luz_max`.

### Derrota
- Al ser derrotado se pierde la mitad de la Luz suelta (v1). **Las ofrendas no se pierden** (provisional, #109).

## Inputs / outputs
- **Inputs:** catálogo, inventario, N del borde, Luz suelta, elección del jugador.
- **Outputs:** inventario sin la ofrenda usada, Luz suelta ajustada, borde abierto, registro de refugios saqueados.

## Interacción con otros sistemas
- **Cruce y combate**: opción nueva en el borde y acción nueva en combate.
- **Navegación**: hallazgos en refugios.
- **Misión del Ofomni**: recompensa, y bloqueo de la acción en ese combate.
- **Guardado**: inventario y refugios saqueados.

## Casos límite
- **Ofrenda de valor 3 y N = 4 sin Luz suelta**: no se puede pagar con ella. Con 1 de Luz suelta, sí (3 + 1).
- **Ofrenda de 8 para un peaje de 4**: se paga y se pierden 4. La UI muestra el valor y el coste antes de confirmar, por ejemplo "Ofrecer Figura sarua (8) por un paso de 4".
- **Varias ofrendas para un peaje**: no se pueden combinar en la 0.2.0 (una ofrenda + Luz suelta).
- **Inventario vacío**: las opciones aparecen desactivadas.
- **Refugio ya saqueado**: E muestra "No queda nada" (texto de `narrative-writer`).
- **Cargar una partida de la 0.1.0**: inventario vacío y ningún refugio saqueado.

## Criterios de éxito para playtest
Propuestas, a confirmar con el dueño:
- El jugador usa al menos una ofrenda para cruzar en su primera hora.
- El jugador entiende sin ayuda que el excedente se pierde (pregunta: "¿qué pasó con la Luz que sobraba?").
- Al menos una vez el jugador guarda una ofrenda grande y paga con una pequeña.

## Decisiones a confirmar con el dueño
- Completar una ofrenda con Luz suelta está permitido, pero no combinar varias ofrendas (#107).
- En combate, la ofrenda necesita llegar a N (ofrenda + Luz suelta) (#112).
- Las ofrendas no se pierden al ser derrotado (#109).
- La Luz que supera el límite se pierde (#115).
- Hallazgos en 1 de cada 3 refugios, de valor 3–4.
- Nombres del catálogo (para `narrative-writer`).

## Preguntas abiertas
- Inventario definitivo (#113).
- Aspecto de las ofrendas (#108).
- Ofrendas que dan las villas y las misiones de villa (#106).
