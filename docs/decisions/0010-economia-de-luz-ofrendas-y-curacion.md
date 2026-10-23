# ADR 0010 — Economía de Luz, ofrendas y curación (modo Aventura)

> Número 0009 reservado para `rpg-systems-dev`.

## Contexto
Respuesta del dueño del proyecto (2026-10-23) a la propuesta de ajuste 5 de `docs/design/mechanics/cruce-y-combate-v1.md` (economía de Luz cerrada) y a la #57. Palabras textuales:

> "un adoc gana luz ganando batallas contra únicos o ayudando a la gente de la villa con los peligros que tengan. Uno se puede curar en una villa o luego de un riutash (el cambio entre dia y noche). Esta bien que al principio irse lejos sea complicado. Tambien uno puede almacenar Luz cuando una villa le otorga ofrendas, estos artefactos pueden tener diferente valor en Luz y se usan de forma entera, es decir debes dejar el artículo entero en el bosque y pierdes su Luz total del valor. Así que es bueno saber administrar los recursos."

## Decisiones
| Tema | Decisión |
|---|---|
| Fuentes de Luz | 1) **Ganar batallas contra Únicos**. 2) **Ayudar a la gente de la villa con sus peligros** (misiones de villa; tipos y recompensa: #106). |
| Ofrendas | Una villa puede otorgar **ofrendas**: artefactos que **almacenan Luz**, con **valores distintos**. Se usan **enteras**: para pagar, se deja el artefacto completo en el Bosque y se pierde todo su valor, aunque el coste fuera menor. |
| Gestión de recursos | Es intencionado: "es bueno saber administrar los recursos". |
| Curación | **En una villa** o **tras un riutash** (el cambio entre día y noche; glosario §2). |
| Dificultad por distancia | Que al principio sea complicado ir lejos es **intencionado**. |

## Respuestas del dueño (2026-10-23): #107, #110, #111 y parte de #73
Palabras textuales:
> "Existe Luz suelta pero tienes un límite interior de Luz suelta que puedes tener ejemplo: 10. El resto si requiere items. Si, puedes ofrecer ofrendas en combate para que el Único se vaya. Estoy viendo si hacemos el inventario por cuadriculas donde poner las cosas al estilo diablo, o como minecraft o por peso como kingdom come deliverance. Si Debes empezar en una villa, tu lugar natal. El riutash regenera estamina y cura parcialmente. No cura heridas graves."

| Tema | Decisión |
|---|---|
| Luz suelta (#107) | **Existe**, con un **límite interior** (ejemplo del dueño: 10; en el código, `luz_max = 10`, provisional). La Luz por encima del límite **requiere objetos** (ofrendas). |
| Ofrendas en combate (#107) | **Sí**: se puede ofrecer una ofrenda en combate **"para que el Único se vaya"**. Es otra salida del combate. Si abre el borde como una victoria o solo termina el combate: #112. |
| Inventario (#107) | **Sin decidir**: cuadrícula (estilo Diablo), slots (estilo Minecraft) o peso (estilo Kingdom Come: Deliverance). Ver #113. |
| Inicio (#110) | **Se empieza en una villa, el lugar natal.** El Bosque inicial **siempre tiene villa** (fuera de la probabilidad de 1/5 de ADR 0008). |
| Riutash (#111, #73) | **Regenera la estamina** (el cansancio de la #73) y **cura en parte**. **No cura heridas graves.** |

Nuevos conceptos que necesitan definición: **estamina** (#73) y **heridas graves**, distintas de los PV (#114).

Choques:
- v1 da 10 de Luz inicial, igual al límite. La primera victoria (+1) supera el límite: ¿se pierde, se convierte en ofrenda o no se gana? (#115)
- La curación en villa (sección anterior) cura "por completo". ¿Cura también las heridas graves? (#114)

## Respuestas del dueño (2026-10-23): #112 y #114
Preguntas: (1) "¿Ofrecer una ofrenda en combate y que el Único se vaya abre el paso como si lo hubieras vencido?" (2) "¿Qué es una 'herida grave', algo aparte de los PV?"

Palabras textuales:
> "1 paso abierto. 2 si es algo aparte que solo lo curas en una villa que tenga al oficiante correcto como un dumno. Se puede mandar a pedir un dumno a otra villa, pero te ata a quedarte mas tiempo en una villa si queires curarte. Heridas graves son perks o status que un combate complicado deja."

| Tema | Decisión |
|---|---|
| Ofrenda en combate (#112) | Que el Único se vaya con una ofrenda **abre el paso**, igual que vencerlo. |
| Heridas graves (#114) | Son **perks o estados negativos** que deja un **combate complicado**. Van **aparte de los PV**. |
| Curación de heridas graves | **Solo en una villa que tenga el oficiante adecuado**, por ejemplo un **dumno** (glosario §5: estudia el cuerpo de cualquier ser y cura). Ni el riutash ni la curación normal de villa las curan. |
| Dumno de otra villa | Si la villa no tiene el oficiante, se puede **mandar a pedir un dumno a otra villa**, pero eso **obliga a quedarse más tiempo** en la villa para curarse. |

Esto también matiza "la villa cura por completo" (sección anterior): cura los PV, no las heridas graves, salvo que tenga el oficiante adecuado.

## Consecuencias
- **`cruce-y-combate-v1.md`**:
  - La regla de curación pasa de "junto a cualquier Nujio" a **"en la plaza o junto al Nujio de una villa"** (cambio que aplica el coordinador en el código).
  - La curación por riutash espera a que exista el ciclo día/noche (#75).
  - Se cierra la propuesta de ajuste 2 (d ≥ 4 muy difícil): es intencionado.
  - La propuesta 5 queda resuelta en parte.
- ~~**Choque**: solo 1 de cada 5 Bosques tiene villa. Si el Bosque inicial no tiene villa, el jugador no puede curarse salvo al ser derrotado (#110).~~ Resuelto: el Bosque inicial siempre tiene villa (respuestas del dueño, arriba).
- Las ofrendas se relacionan con el oficio **Sarua** del glosario §5 ("objetos para entregar Luz"). Es una relación de lore, no una regla.
- Las ofrendas son un recurso nuevo. Fuente: villas, por misiones de villa. Sumidero: pagos enteros en los bordes. Qué pasa al agotarse: hay que cruzar combatiendo o retroceder. Faltan los detalles (#107–#109).
- `engine-architect`: el estado guardado pasa a incluir el inventario de ofrendas (con su valor) además de la Luz.
