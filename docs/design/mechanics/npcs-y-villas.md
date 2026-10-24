# Ficha: NPC y servicios de las villas

> Dueño: `game-designer`. **Propuesta para la 0.4 "Los otros adoc"** (`docs/design/roadmap-0.4.md`). Valores **provisionales**.
> Fuentes: palabras del dueño (abajo); glosario §5 ("Villa", tabla de Oficios), §6 ("Luz", "Trueque", "Multiplicador de valor" del Ista); ADR 0010 (ofrendas, dumno y heridas graves); `ofrendas-v1.md`, `sigilo-y-robo.md`, `moralidad-y-progresion.md`. No se inventa lore: los oficios y sus funciones son los del glosario.

## Objetivo
Que las villas tengan gente con la que hablar y que ofrezca algo útil: encargos, ofrendas y equipo. Así volver a una villa es una decisión con valor y no solo un sitio donde curarse.

Palabras del dueño (2026-10-24): "Deberia haber más npc. [...] Algunas villas tienes saruas a los que les puedes pedir ofrendas a cambio de favores, otras villas pueden tener artesanos que hacen equipamiento más para uso de un adoc."

## Pilares
- **Pilar 1 (dos capas)**: lo que haces en el Bosque (encargos, frutos lícitos, apaciguar) se cambia en la villa por ofrendas y equipo para volver al Bosque.
- **Pilar 4**: cada villa tiene su propia lista de oficiantes por seed; no todas ofrecen lo mismo.
- **Pilar 3**: un NPC, un oficio, un servicio.

## Presión de supervivencia
- **Alivia**: más fuentes de ofrendas y mejor equipo.
- **Añade**: los servicios cuestan Luz, ofrendas o tiempo (encargos), y las villas desconfían de un adoc de Senda violenta (`moralidad-y-progresion.md`).

## Reglas

### Población de una villa (lista de oficiantes por seed, #118)
- Cada villa genera una **lista de oficiantes** por seed. Responde a #118.
- **Siempre**: **Ildo** (guía la villa) y **Sfida** (conexión con el Nujio; en la villa natal es quien da la misión del Ofomni).
- **Probables** (cada uno con probabilidad independiente, provisional):

| Oficio (glosario §5) | Función en el glosario | Servicio en el juego (propuesta) | Probabilidad |
|---|---|---|---|
| **Sarua** | Artesanos rituales: objetos para entregar Luz, talismanes de viaje | Favores a cambio de ofrendas. Fabrica **talismanes** y **máscaras** (confirmado) | 50% |
| **Paruas** | Hacer funcional: utensilios de todo tipo | **Artesano de equipo**: armas para la mano principal y su mejora (confirmado) | 35% |
| **Dumno** | Estudioso del cuerpo, cura personas y seres | Cura las **heridas graves** (ADR 0010) | 40% |
| **Rogoc** | Viajeros designados: piden ayuda, llevan información, comercian | Informa de Bosques cercanos (estado, misiones) y vende alguna ofrenda | 40% |
| **Pholua** | Recolectores y repartidores de la comida del Bosque | Explica las reglas del fruto (1 por Momento, no sacarlo) | 50% |
| **Underil** | Narrador; viaja con historias de los Nujio | Diálogo de ambiente | 25% |
| **Adoc** | Protectores | Otros adoc de la villa: encargos compartidos (`otros-adoc.md`). La villa natal los tiene "en otras misiones" al empezar | 30% |
| **Ista** | Dictamina lo justo; valúa Luz y Piedras | Precios de la villa (multiplicador −5…+5, glosario §6) | 25% |

- Más adelante, el resto de oficios (Ledai, Folas, Turos, Jiulua) cuando tengan mecánica.
- **Jelios** (soldados) solo aparecen en la era de los Nuevos Bosques (glosario §5): fuera de las villas con Nujio.
- Cada NPC es un sprite placeholder con color de oficio y un nombre tentativo, de la misma lista que los nombres de villa (`narrative-writer`).

### Sarua: ofrendas a cambio de favores
- Al hablar con un Sarua (E) se pide un **favor**. Hay como máximo **1 favor activo por Sarua**.
- **Tipos de favor** (encargos cortos, de 3 a 8 minutos de reloj):

| Favor | Qué hay que hacer | Recompensa |
|---|---|---|
| **Llevar algo** | Entregar un objeto a otra villa o a un refugio a 1–2 Bosques | Ofrenda de 4–5 |
| **Recoger frutos lícitos** | Traer 1–2 frutos tomados **sin robar** (con el peaje pagado, 1 por Momento y por Bosque) | Ofrenda de 3–4 |
| **Apaciguar un Único cercano** | Pagar el paso o hacer que se vaya un Único apaciguable de un Bosque vecino, **sin vencerlo** | Ofrenda de 5–6, Senda +3 |

- Robar o vencer para cumplir el favor no cuenta, o reduce la recompensa (decisión: no cuenta).
- **Favores según la Senda** (`moralidad-y-progresion.md`): con el icono **violenta**, el Sarua solo da favores de "llevar algo". La skill de Confianza C2 "Rostro conocido" permite 2 favores activos y sube las recompensas +1.

### Artesanos de equipo (confirmado)
- **Paruas** hacen las **armas** y **Sarua** las **máscaras y los talismanes** (dueño: "asi es").
- **Fabricar** un objeto: cuesta Luz u ofrendas. **Mejorar**: +1 de nivel al objeto (máx. 3).

| Objeto (ranura) | Efecto base (propuesta) | Fabricar | Mejorar (+1) |
|---|---|---|---|
| Arma (mano principal) | +1 ATQ por nivel del arma (1–3) | 6 de Luz u ofrenda ≥ 6 | 8 / 10 |
| Máscara (cara) | Reduce el `vision_radius` de los Únicos un 25% por nivel (1–3) (`sigilo-y-robo.md`) | 8 | 10 / 12 |
| Talismán | Por tipo: +2 de Luz máx., +3 PV máx. o −1 al peaje (mín. 1) | 6 | 8 / 10 |

- **Coste: Luz u ofrendas + materiales** (dueño, #159: "usan materiales, si su bosque esta ya decrepito es posible que no tengan nada que ofrecer o te pediran que lo consigas para que te hagan el artefacto").
- **Artesanos de un Bosque decrépito** (estado muerto o corrupto, `bosques-y-relacion.md`): no tienen materiales propios. O no ofrecen nada, o **te piden que traigas el material** y luego fabrican (pagando solo la Luz u ofrenda).
- En un Bosque sano, el artesano pone sus propios materiales en la fabricación básica. Para las **mejoras** siempre hay que traerlos.

### Materiales (propuesta, provisional)
Lista corta sacada del glosario y del mundo del juego:

| Material | De dónde sale | Regla | Base |
|---|---|---|---|
| **Madera muerta** | Árboles muertos de un Bosque (con E) | Solo **con permiso**: Bosque pagado o relación ≥ 30. Sin permiso es **robo** (hostilidad +1, relación −20, Senda −10) | Glosario §5: madera "solo de árboles muertos y con permiso" |
| **Barro** | Orillas de arroyos y ríos | Libre | Glosario §5: casas de barro |
| **Piedra** | Junto a riscos y pendientes | Libre | Glosario §5: casas de piedra |
| **Fibra** | Plantas de los Bosques (casillas de maleza) | Como la madera: con permiso, si no es robo | Del mundo del juego, sin entrada en el glosario |
| **Metal de Gietos** | **Muy raro**: solo como recompensa de misiones difíciles | Ver el choque abajo | Glosario §3: es la única posesión de los errantes, de origen desconocido |

- **Restos de Únicos: no se proponen.** El glosario dice que los Únicos "vuelven a la Luz del Bosque" al terminar, así que no dejan cuerpo. La skill Botín da ofrendas, no restos.
- **Choque con el glosario**: el metal de Gietos es "material de la única posesión de los errantes; origen desconocido". Usarlo como material de artesano puede contradecir el lore. Se deja como recompensa rarísima, a confirmar (#164).

| Recetas (provisional) | Fabricar | Mejorar (+1 nivel) |
|---|---|---|
| Arma (Paruas) | 6 de Luz + 2 madera muerta + 1 piedra | +2 madera muerta + 2 piedra; nivel 3: + 1 metal de Gietos |
| Máscara (Sarua) | 8 de Luz + 2 madera muerta + 2 fibra | +2 fibra + 1 barro |
| Talismán (Sarua) | 6 de Luz + 2 barro + 1 fibra | +2 barro + 1 piedra |

- Cada material ocupa una casilla del inventario, apilable hasta 10 (propuesta, compatible con la bolsa de 12 casillas).
- Precios × multiplicador del Ista de la villa, si lo hay (−5…+5 → ×0,5…×1,5).

### Diálogos y servicios básicos
- Todos los NPC se hablan con **E** y usan el `DialogueBox` existente.
- Menú: **"Hablar"** (texto de ambiente u oficio), **"Servicio"** (si lo tiene: favor, fabricar, curar, informar) y **"Adiós"**.
- Textos: `narrative-writer` (`data/npcs/`).

## Inputs / outputs
- **Inputs:** seed y villa (lista de oficiantes), Senda, inventario (Luz y ofrendas), estado de los favores.
- **Outputs:** NPC colocados en la villa, favores activos y cumplidos, ofrendas, equipo fabricado o mejorado, curación de heridas.

## Casos límite
- **Villa sin Sarua ni Paruas**: solo Ildo, Sfida y los que salgan. El Rogoc puede indicar una villa cercana con artesano.
- **Favor imposible** (el objetivo está en un Bosque enojado): se puede abandonar sin castigo.
- **Fabricar sin Luz suficiente**: la opción aparece desactivada, con el precio a la vista.
- **Artesano de un Bosque decrépito sin materiales**: ofrece "Tráeme…" con la lista de lo que necesita. Se guarda como encargo hasta que se le entrega.
- **Villa dañada** (misión fallida): ¿menos servicios? (#124).

## Criterios de éxito para playtest
- El jugador vuelve a una villa que no es la natal por un servicio (favor o equipo) al menos una vez por sesión.
- El jugador completa un favor de Sarua y entiende que robar no vale para cumplirlo.

## Preguntas abiertas
- ~~¿Qué oficio fabrica qué?~~ Confirmado: Paruas, armas; Sarua, máscaras y talismanes (#154).
- ~~¿Hay materiales?~~ Resuelta (#159): sí; la lista y las recetas son propuesta. El metal de Gietos como material: #164.
- Efectos de la villa dañada en los servicios (#124).
