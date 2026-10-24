# Ficha: Sigilo, armas y robo en los Bosques (0.3.0)

> Dueño: `game-designer`. **Versión 0.3.0, fuera de la 0.2.0** (alcance elegido por el dueño: "Botarramas en la 0.2.0; sigilo en la 0.3.0").
> Esta ficha recoge lo dicho por el dueño y deja las reglas que faltan como preguntas o como propuestas marcadas. Se completará con números antes de implementarse.
> Fuentes: palabras del dueño (abajo), glosario §5 (Sarua: "talismanes de viaje"; Adoc: "únicos especialistas en armas"), `ofrendas-v1.md`, `monstruos.md`.

## Objetivo
Que haya otra forma de moverse por los Bosques además de pagar o pelear: colarse sin ser visto, con una cara oculta y un riesgo claro si se roba.

Palabras del dueño:
> "hay articulos que te permiten "sneak" en los bosques. Estos articulos son mascaras de diferentes formas, algunos talismanes. Llevar armas equipadas hace que el bosque no te deje pasar y debes vencer a los enemigos constantemente. [...] Dentro del bosque, si robas algun objeto y estas sin proteccion o a la vista de otro Único, despiertas a los ofomni que te persiguen por el bosque hasta la frontera."

## Pilares
- **Pilar 1 (dos capas)**: los objetos que dan las villas (máscaras y talismanes) cambian cómo se recorre el Bosque.
- **Pilar 3 (legibilidad)**: llevar máscara o no, y llevar arma o no, son estados visibles y binarios.
- **Pilar 4**: cada Bosque reacciona a lo que llevas.

## Presión de supervivencia
- **Añade**:
  - Llevar armas equipadas cierra el paso y obliga a pelear "constantemente".
  - Robar sin protección o a la vista de un Único despierta a los Ofomni, que te persiguen hasta la frontera.
- **Alivia**: con máscaras y talismanes se puede pasar sin pagar ni pelear.

## Reglas (lo dicho por el dueño)
1. **Objetos de sigilo**: **máscaras** de distintas formas y **algunos talismanes** permiten colarse ("sneak") en los Bosques.
2. **Armas equipadas**: si el jugador las lleva, el Bosque **no le deja pasar** y tiene que **vencer a los enemigos constantemente**.
3. **Robo**: dentro de un Bosque, **robar un objeto** estando **sin protección** o **a la vista de otro Único** **despierta a los Ofomni**.
4. **Persecución**: los Ofomni **persiguen al jugador por el Bosque hasta la frontera**.

## Propuestas de `game-designer` (a confirmar; sin números todavía)
- **Máscara o talismán equipado**: los Botarramas no detectan al jugador o lo detectan a un radio menor (por ejemplo, la mitad), según la máscara. Algunas formas podrían servir solo en ciertos tipos de Bosque.
- **Armas equipadas**:
  - Los Botarramas detectan al jugador a más distancia.
  - El menú del borde no ofrece pagar, solo "Enfrentar" o "Retroceder".
  - Dentro del Bosque aparecen Botarramas o Únicos con más frecuencia.
- **Guardar el arma**: si el adoc puede guardarla (no equipada) para pasar en paz, y sacarla para pelear, ¿con qué coste o penalización (turnos, ATQ)?
- **Robo**:
  - Acción con E sobre objetos del Bosque.
  - Con máscara y sin Únicos a la vista: sin consecuencias.
  - Si no: aparecen 1 o más Ofomni que persiguen al jugador hasta que salga del Bosque por cualquier frontera.
  - Si lo alcanzan: combate.
- **Ofomni perseguidores**: más rápidos que los Botarramas, que renquean. No pasan de la frontera.

## Interacción con otros sistemas
- **Inventario y equipo** (#113): máscaras, talismanes y armas necesitan ranuras de equipo o un estado de "equipado".
- **Ofrendas** (`ofrendas-v1.md`): conviven con los talismanes. ¿Un talismán es una ofrenda que no se gasta?
- **Botarramas** (`monstruos.md`): detección y radio según lo que se lleva.
- **Ofomni** (`monstruos.md`, `mision-ofomni.md`): pasa de enemigo de misión a perseguidor tras un robo.
- **Refugios con ofrendas** (0.2.0): ver choque 2.

## Choques que hay que resolver
1. **El adoc es especialista en armas** (glosario §5: "Protectores; únicos especialistas en armas, para apaciguar Únicos descarriados"), pero **llevar armas equipadas hace que el Bosque no te deje pasar**. ¿El adoc lleva el arma guardada y solo la saca para pelear? ¿Que su oficio sea el de las armas es justo lo que hace que los Bosques desconfíen de él? (#131)
2. **Hallazgos en refugios (0.2.0) frente al robo (0.3.0)**:
   - En la 0.2.0, el jugador recoge con E ofrendas que encuentra en los refugios.
   - En la 0.3.0, robar un objeto del Bosque despierta a los Ofomni.
   - Además, pagar con una ofrenda consiste en "dejar el artículo entero en el bosque" (ADR 0010).
   - ¿Recoger una ofrenda de un refugio es robar al Bosque? (#130)
3. **Colarse en la 0.2.0** (propuesta de `monstruos.md`: cruzar por un tramo sin Botarramas cerca) frente al **sigilo con máscaras de la 0.3.0**: si en la 0.2.0 ya se puede colarse sin objetos, las máscaras valen menos. ¿Colarse sin máscara debería ser imposible o muy difícil a partir de la 0.3.0? (#129)

## Casos límite (para cuando se definan las reglas)
- Robar con máscara pero a la vista de un Único.
- Quitarse la máscara dentro de un Bosque cerrado.
- Armas equipadas dentro de un Bosque ya abierto.
- Persecución de Ofomni que llega a un refugio o a una villa.
- El riutash durante una persecución.

## Criterios de éxito para playtest (borrador)
- El jugador entiende sin explicación que la máscara le deja pasar y el arma no.
- La persecución de los Ofomni se siente tensa pero escapable (pregunta directa).

## Preguntas abiertas
- **#130**: qué cuenta como robar (¿frutos, objetos de refugios, ofrendas dejadas por otros?) y qué es "estar sin protección".
- **#131**: qué es un "arma equipada" para el adoc (¿guardada o desenvainada?) y si puede pasar en paz.
- **#132**: duración y efecto de las máscaras y los talismanes de sigilo. ¿Se gastan? ¿Cada forma de máscara sirve para ciertos Bosques? ¿De dónde salen (villas, sarua)?
- Inventario y equipo (#113).
