# Ficha: Sigilo, armas y robo en los Bosques (0.3)

> **En la hoja de ruta de la 0.3** (`docs/design/roadmap-0.3.md`), después de inventario y equipo.

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
1. **Objetos de sigilo**: **máscaras** de distintas formas y **algunos talismanes** permiten colarse ("sneak") en los Bosques. Precisión (2026-10-24): "sneak puede darse usando una mascara solamente o algun otro artefacto que camufle la Luz del jugador". **Sin uno de esos objetos no se puede colarse**: el borde sigue cerrado aunque se esquive a los Botarramas.
2. **Armas equipadas**: si el jugador las lleva, el Bosque **no le deja pasar** y tiene que **vencer a los enemigos constantemente**. Precisión (2026-10-24): "Las armas deberían poder estar o equipadas o desequipadas de la mano principal". **Desequipada, no cierra el paso.**
3. **Percepción de los Únicos**: tienen radio de visión, velocidad y distancia de encuentro (`monstruos.md`, regla general). Las máscaras y los artefactos de camuflaje actúan sobre esa percepción.
4. **Robo**: dentro de un Bosque, **robar un objeto** estando **sin protección** o **a la vista de otro Único** **despierta a los Ofomni**.
   - **Primer caso definido** (dueño, 0.3: "solo puedes tomar 1 fruto por Momento, sino es un robo al boque"): **es robo tomar un segundo fruto del mismo Bosque en el mismo Momento, o cualquier fruto de un Bosque cuyo peaje no has pagado** (#149: "si pagas tu peaje puedes tomar un fruto por momento. Pero si en otro arbol del mismo bosque tomas un futo, es robo"). Ya implementado: hostilidad +1 y relación −20 con ese Bosque (`bosques-y-relacion.md`, "Fruto").
   - **Persecución implementada** (PR #39; dueño: "tomar o comer mas de un fruto puede alertar a los ofomni a que te sigan"):
     - Al robar aparecen **1–2 `ofomni` apaciguables** que **persiguen dentro del Bosque robado hasta la frontera**.
     - **Apaciguarlos** (Ofrecer Luz u ofrenda) paga el peaje del Bosque.
     - **Vencer a uno** da hostilidad +1 y relación −10.
     - **No son fatales.**
     - Las máscaras y el arma (resto de esta ficha) siguen pendientes.
   - Los perseguidores son `ofomni` **apaciguables** (`monstruos.md`), no el `ofomni_descarriado` de la misión.
5. **Persecución**: los Ofomni **persiguen al jugador por el Bosque hasta la frontera**.

## Implementado en la 0.3 (provisional, a confirmar por el dueño en #131 y #132)
> Números en `data/combat/balance.json` (bloque `stealth`) y `data/items/items.json`. Nombres y textos provisionales (`narrative-writer`). Código: `Stealth`, `AdventureRules` (sección Colarse), `MonsterField`, `exploration.gd`.

- **Camuflaje**: cada máscara y talismán tiene `camouflage` (casillas que se restan al `vision_radius` de todos los Únicos). Máscara + talismán se suman, con tope `camouflage_max` = 14. **Con un arma en la mano principal, el camuflaje no funciona.**
- **Objetos** (para probar, todos en la bolsa inicial; de dónde salen sigue en #132):

| Objeto | Camuflaje | Otro efecto | Coste |
|---|---|---|---|
| Máscara de corteza | 6 | — | — |
| Máscara de musgo | 8 | — | DEF −2 mientras se lleva |
| Máscara de ceniza | 11 | — | Se deshace tras 3 cruces colados |
| Talismán de semillas | 3 | — | — |
| Talismán de pluma (de viaje) | 0 | Paso un 30% más rápido (`speed_bonus`, tope 0,5) | No oculta |

- **Colarse**: si la visión de los Botarramas del Bosque vecino (con su hostilidad y su estado, menos el camuflaje) queda en `sneak_max_vision` = 1 o menos, se cruza su frontera cerrada sin menú. El Bosque queda **colado** mientras sigas dentro: ni pagado ni forzado, sin cazadores mientras nadie te vea y sin derecho a fruto (tomarlo es robo). Al salir, hay que volver a colarse. Ejemplos: corteza + semillas (9) basta en un Bosque sano sin hostilidad; con hostilidad 1 ya no; un Bosque enojado (+4) pide ceniza + semillas (14).
- **Te han visto**: un Único que te encuentra de cerca (a su `engage_distance`) o que empieza a perseguirte mientras vas oculto rompe el camuflaje `exposed_seconds` = 20 s; te persigue y tarda `seen_grace_seconds` = 0,8 s en empezar el encuentro. Si estabas colado en su Bosque, el Bosque empieza a cazarte.
- **Robo camuflado**: solo despierta a los Ofomni si un Único del Bosque te tiene a su visión o a su distancia de encuentro. La hostilidad y la relación del robo se aplican igual. Sin camuflaje, siempre (100%).
- **Arma equipada** (#131 provisional): con un arma en la mano principal, ningún Bosque salvo el natal (y salvo los que no cobran: muerto y necesita ayuda) te deja pasar en paz, aunque esté pagado: sus Únicos te persiguen, el menú del borde solo ofrece "Enfrentar" o "Retroceder" y caza como uno sin pagar. Aviso al entrar: "El Bosque siente tu arma.". Equipar o desequipar fuera de combate (pantalla I) es gratis. En combate el arma suma su ATQ; sin ella, ATQ base y "Peleas sin arma.". En combate se sigue pudiendo apaciguar con Luz u ofrendas.
- **Bosque enojado**: con camuflaje alto (un Botarramas base se queda con visión ≤ `hidden_vision` = 2) o con velocidad, sus cazadores tardan `stealth_hunt_factor` = 2 veces más.
- **HUD**: icono de máscara (verde oculto, rojo visto) y de lanza (armado).

## Propuestas de `game-designer` (a confirmar; sin números todavía)
- **Máscara o artefacto de camuflaje equipado**:
  - Reduce el `vision_radius` con el que los Únicos ven al jugador (por ejemplo, a la mitad o a 0, según la máscara).
  - Permite cruzar una frontera cerrada sin que salte el menú si ningún Único llega a la `engage_distance`. El Bosque no se abre.
  - Algunas formas podrían servir solo en ciertos tipos de Bosque.
- **Arma equipada en la mano principal**:
  - Los Únicos la ven desde más lejos.
  - El menú del borde no ofrece pagar, solo "Enfrentar" o "Retroceder".
  - Dentro del Bosque aparecen Botarramas o Únicos con más frecuencia.
- **Arma desequipada**: no cierra el paso. Equipar o desequipar: ¿desde el menú, gratis fuera de combate? ¿En combate cuesta un turno o se lucha con ATQ reducido? (#131)
- **Robo**:
  - Acción con E sobre objetos del Bosque.
  - Con máscara y sin Únicos a la vista: sin consecuencias.
  - Si no: aparecen 1 o más Ofomni que persiguen al jugador hasta que salga del Bosque por cualquier frontera.
  - Si lo alcanzan: combate.
- **Ofomni perseguidores**: más rápidos que los Botarramas, que renquean. No pasan de la frontera.

## Interacción con otros sistemas
- **Inventario y equipo** (#113, **confirmado**): bolsa de 12 casillas estilo Minecraft y 3 ranuras de equipo: **mano principal** (arma), **máscara** y **talismán**. Las máscaras y los talismanes de sigilo se equipan en sus ranuras.
- **Ofrendas** (`ofrendas-v1.md`): conviven con los talismanes. ¿Un talismán es una ofrenda que no se gasta?
- **Botarramas** (`monstruos.md`): detección y radio según lo que se lleva.
- **Ofomni** (`monstruos.md`, `mision-ofomni.md`): pasa de enemigo de misión a perseguidor tras un robo.
- **Refugios con ofrendas** (0.2.0): ver choque 2.

## Choques que hay que resolver
1. ~~**El adoc es especialista en armas** (glosario §5), pero **llevar armas equipadas hace que el Bosque no te deje pasar**.~~ **Resuelto** (dueño, 2026-10-24): el arma se equipa o se desequipa de la mano principal, y desequipada no cierra el paso. El adoc lleva su arma y la desequipa para pasar en paz. Quedan los detalles en #131.
2. **Hallazgos en refugios (0.2.0) frente al robo (0.3.0)**:
   - En la 0.2.0, el jugador recoge con E ofrendas que encuentra en los refugios.
   - En la 0.3.0, robar un objeto del Bosque despierta a los Ofomni.
   - Además, pagar con una ofrenda consiste en "dejar el artículo entero en el bosque" (ADR 0010).
   - ¿Recoger una ofrenda de un refugio es robar al Bosque? (#130)
3. ~~**Colarse en la 0.2.0 frente a las máscaras de la 0.3.0.**~~ **Resuelto** (dueño, 2026-10-24): solo se puede colarse con una máscara u otro artefacto que camufle la Luz. En la 0.2.0 el borde sigue cerrado. Las máscaras conservan su valor.

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
- **#130** (en parte: el fruto extra del mismo Momento es robo): qué más cuenta como robar (¿frutos, objetos de refugios, ofrendas dejadas por otros?) y qué es "estar sin protección".
- **#131** (en parte): el arma se equipa o se desequipa de la mano principal, y desequipada no cierra el paso. Falta saber cuánto cuesta equipar o desequipar y su efecto en combate.
- **#132**: duración y efecto de las máscaras y los artefactos que camuflan la Luz. ¿Se gastan? ¿Cada forma de máscara sirve para ciertos Bosques? ¿De dónde salen (villas, sarua)?
- ~~Inventario y equipo (#113).~~ Confirmado: 12 casillas y 3 ranuras.
