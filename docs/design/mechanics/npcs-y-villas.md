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
| **Sarua** | Artesanos rituales: objetos para entregar Luz, talismanes de viaje | Favores a cambio de ofrendas. Fabrica **talismanes** y **máscaras** (a confirmar) | 50% |
| **Paruas** | Hacer funcional: utensilios de todo tipo | **Artesano de equipo**: armas para la mano principal y su mejora (a confirmar) | 35% |
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
- **Precio de favor según la Senda** (`moralidad-y-progresion.md`): con Senda ≤ −30, el Sarua da solo favores de "llevar algo"; con Senda ≥ 30, las recompensas suben +1.

### Artesanos de equipo (a confirmar)
- **Paruas** (armas) y **Sarua** (máscaras y talismanes): oficio de cada objeto **a confirmar**. El glosario no nombra artesanos de armas; los adoc son "únicos especialistas en armas" y los paruas hacen "utensilios de todo tipo".
- **Fabricar** un objeto: cuesta Luz u ofrendas. **Mejorar**: +1 de nivel al objeto (máx. 3).

| Objeto (ranura) | Efecto base (propuesta) | Fabricar | Mejorar (+1) |
|---|---|---|---|
| Arma (mano principal) | +1 ATQ por nivel del arma (1–3) | 6 de Luz u ofrenda ≥ 6 | 8 / 10 |
| Máscara (cara) | Reduce el `vision_radius` de los Únicos un 25% por nivel (1–3) (`sigilo-y-robo.md`) | 8 | 10 / 12 |
| Talismán | Por tipo: +2 de Luz máx., +3 PV máx. o −1 al peaje (mín. 1) | 6 | 8 / 10 |

- **Materiales**: en la 0.4 solo Luz y ofrendas. Si habrá materiales (madera de árboles muertos con permiso, piedra…) queda pendiente.
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
- **Villa dañada** (misión fallida): ¿menos servicios? (#124).

## Criterios de éxito para playtest
- El jugador vuelve a una villa que no es la natal por un servicio (favor o equipo) al menos una vez por sesión.
- El jugador completa un favor de Sarua y entiende que robar no vale para cumplirlo.

## Preguntas abiertas
- ¿Qué oficio fabrica armas y cuál máscaras (Paruas y Sarua, a confirmar)? ¿Hay materiales? (#154)
- Efectos de la villa dañada en los servicios (#124).
