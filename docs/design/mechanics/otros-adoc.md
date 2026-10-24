# Ficha: Los otros adoc

> Dueño: `game-designer`. **La parte de combate con aliados va en la 0.3 (PR 7, combate en grupo); el resto, en la 0.5 "Los otros adoc" (antes numerada 0.4).** Valores **provisionales**.
> Fuentes: palabras del dueño (abajo); glosario §5 ("Adoc": "Protectores; únicos especialistas en armas, para apaciguar Únicos descarriados"); `mision-ofomni.md` ("los otros adoc han salido a otras misiones"); `monstruos.md` (combate en grupo); `npcs-y-villas.md`; `moralidad-y-progresion.md`; `bosques-y-relacion.md`.

## Objetivo
Que el adoc no esté solo en el mundo: hay otros adoc que encontrar, ayudar y con los que compartir encargos.

Palabras del dueño (2026-10-24): "encontrarte con otros adoc, ayudarles a luchar contra 'Unicos. salvar los bosques".

## Pilares
- **Pilar 1**: los otros adoc conectan villas y Bosques.
- **Pilar 3**: un adoc aliado se ve como un NPC con arma y se une al combate en una línea.
- **Pilar 4**: dónde y cuándo aparecen depende de la seed.

## Presión de supervivencia
- **Alivia**: un aliado reparte el daño en combates difíciles.
- **Añade**: si no lo ayudas a tiempo, el otro adoc puede caer o retirarse (ver reglas).

## Reglas

### Siempre aliados, con afinidad (dueño, 0.5)
> "los adoc son aliados siempre, pero algunos pueden no querer trabajar contigo si tienen sendas distintas. No hacen daño."

- **Los adoc nunca son enemigos ni hacen daño** al jugador. No hay adoc rivales.
- Cada adoc NPC tiene su propia **Senda** (por seed, de −80 a +80).
- **Afinidad**: si la diferencia entre tu Senda y la suya es **≥ 60**, **no quiere trabajar contigo**:
  - no acepta tu ayuda en combate (el menú muestra "El adoc rechaza tu ayuda" y solo "Seguir tu camino");
  - no propone encargos compartidos.
- La skill de Confianza **C2 "Rostro conocido"** sube ese umbral a **≥ 100**: los adoc de afinidad dudosa aceptan.
- El jugador no ve el número; el adoc lo dice en su diálogo (textos de `narrative-writer`).

### Dónde aparecen
- **En las villas**: según la lista de oficiantes (`npcs-y-villas.md`, Adoc 30%). En la villa natal están "en otras misiones" al empezar (`mision-ofomni.md`) y vuelven tras completar la misión del Ofomni (propuesta).
- **En el mundo** (evento): un adoc NPC **luchando contra un Único o un grupo de reparep** cerca de un camino.
  - Probabilidad: 1 evento cada 2 Bosques nuevos visitados (provisional; determinista por seed).
  - Se ve a distancia (`vision_radius` normal).

### Ayudar en combate (0.3, PR 7)
- Al acercarte al combate en curso, se abre el menú: **"Ayudar"** o **"Seguir tu camino"**.
- **Ayudar**: combate en grupo (`monstruos.md`) con el otro adoc como **aliado**.
  - Aliado: stats de adoc de nivel 1–3 (por seed), actúa justo después de ti con "Atacar" contra el mismo objetivo.
  - Si sus PV llegan a 0, **se retira** (no muere; ADR 0004: no se mata gente) y deja de ayudar.
  - Los enemigos atacan a uno de los dos al azar (50/50).
- **Seguir tu camino**: tras 2 minutos de reloj, el otro adoc gana o se retira (por seed). Sin efecto para ti salvo la oportunidad perdida.

### Qué ganas
| Resultado | Recompensa (provisional) |
|---|---|
| Victoria con aliado | XP normal del combate (no se reparte), +1 de fama, Senda +2 |
| El aliado sobrevive | Su villa: relación con ella +10 (si existe relación con villas, #155); 1 ofrenda de 3–4 |
| El aliado se retira | Solo la XP |

- Los combates con aliado contra **Botarramas** ayudan a abrir un paso, pero **también suben la hostilidad** del Bosque (vencer es vencer; ADR 0013).

### Encargos compartidos (0.5)
- Un adoc de una villa puede proponer un **encargo compartido**: ir juntos a por un Único descarriado, defender un Bosque en necesidad de ayuda (`bosques-y-relacion.md`, "Salvar los Bosques") o, con 2 o más adoc, enfrentarse a un **Iserald** desatado.
- El adoc NPC te acompaña (te sigue por el mundo) hasta terminar el encargo.
- Recompensa repartida: tú recibes la mitad de la Luz y toda la XP.

## Inputs / outputs
- **Inputs:** seed (eventos), villas (lista de oficiantes), estado de la misión principal, combate en grupo.
- **Outputs:** eventos de adoc NPC, aliado en combate, recompensas, fama, Senda.

## Casos límite
- **Ayudar a un adoc contra un Único de un Bosque pagado**: el Único es pasivo; no hay combate (el evento no se genera ahí).
- **Huir de un combate con aliado**: huyes tú; el aliado se retira.
- **Derrota con aliado**: regla normal (fatal o no según el monstruo). El aliado se retira.
- **Senda distinta**: el adoc no quiere trabajar contigo (afinidad, arriba). No te ataca.
- **Iserald** (`monstruos.md`): solo lo vence un grupo de adoc. Los encargos compartidos con 2 o más adoc aliados son la forma de enfrentarlo.

## Criterios de éxito para playtest
- El jugador ayuda a otro adoc al menos una vez y nota que el combate es más fácil.
- El dueño siente que el mundo tiene "más vida" (pregunta directa).

## Preguntas abiertas
- ~~¿Hay adoc rivales?~~ Resuelta (#153): siempre aliados, nunca hacen daño. Algunos no quieren trabajar contigo si sus Sendas son distintas. Los enemigos humanos son los **garelinos** (`monstruos.md`).
- ¿Existe relación con las villas, además de con los Bosques? (#155)
