# ADR 0007 — Escala con Bosques, reglas de viaje, día/noche y región Valle del Sara

## Contexto
Respuestas del dueño del proyecto (2026-10-23) tras probar el prototipo de movimiento. Palabras textuales (se omite la frase sobre un fallo técnico de la tecla D, que lleva el coordinador):

> "la velocidad esta bien [...]. Los bosques son lugares más tupidos, puedes caminar entre los árboles, las barreras fisicas son el agua, los riscos o pendientes pronunciadas. digamos que la palabra zona sea remplazada por Bosque. Asumamos que un bosque puede tener entre 4 y 16 chunks. Puedes moverte libremente dentro de un bosque inicial. Si quieres pasar a otra zona o bosque que aun tenga Nujio debes pagar con Luz o enfrentarte a los Únicos que te envie el bosque. Un área puede tener entre 6 o 12 bosques. una región puede tener decenas de áreas o hasta un ciento de estas. Puedes viajar por todo el mapa recorriendolo a pie pero es más tardado y puedes cansar al personaje. Además el día (momento de gietos) y la noche (momento de riumna) tienen diferentes peligros, hay bosques que no permiten andar por la noche. Otro dato es que es más frecuente encontrar nuevos bosques en Lean, Tossie, Ostie ya que desde ahí empezó la expansión de ese evento. Es múy raro encontrar un nuevo bosque en Nosie y casi imposible en Alciss ya que fue la región más alejada. Una aclaración del mapa es que Lean, Tossie, Ostie Casie, Vastie, Alss y Causie son parte de la región del Valle del Sara. Adess, Istil, Sass, Ness y Alciss son parte de la Región de Alcuss. Empecemos a trabajar con la región del Valle del Sara. Esta región es más agreste al norte y las zonas más planas y con algunos claros rivereños en el sur. Los rios grandes son navegables y otros más pegados a las montañas o rios estrechos no son navegables."

## Decisiones
| Tema | Decisión |
|---|---|
| Terminología | El nivel "zona" pasa a llamarse **Bosque**. La escala queda: **chunk < Bosque < área < región < Sur Lenfi**. En ADR 0005, "zona" se lee como "Bosque". |
| Tamaños | Un Bosque tiene **4 a 16 chunks** (de 64×64 tiles). Un área tiene **6 a 12 Bosques**. Una región tiene **de decenas a un centenar de áreas**. |
| Bosque de la escala y Bosque del glosario | Probablemente son lo mismo, la entidad con un Nujio del glosario §3 ("otro bosque que aun tenga Nujio"). **A confirmar** (#69). |
| Terreno | Los bosques son tupidos y se puede caminar entre los árboles. Las **barreras físicas** son el agua, los riscos y las pendientes pronunciadas. |
| Ríos | Los grandes son **navegables**. Los que están pegados a las montañas y los estrechos **no lo son**. |
| Movimiento | Libre dentro del Bosque inicial. Para pasar a otro Bosque **que aún tenga Nujio** hay que pagar con **Luz** o enfrentarse a los **Únicos** que envía el bosque. |
| Viaje a pie | Se puede recorrer todo el mapa a pie. Es más lento y **puede cansar al personaje**. |
| Día y noche | El día (Momento de Gietos) y la noche (Momento de Riumna) tienen peligros distintos. Hay Bosques que no permiten andar de noche. |
| Región Valle del Sara | Lean, Tossie, Ostie, Casie, Vastie, Alss y Causie forman parte de ella. Que sean áreas es una suposición, **a confirmar** (#77). Es más agreste al norte; el sur es más plano, con algunos claros ribereños. |
| Región de Alcuss | Adess, Istil, Sass, Ness y Alciss forman parte de ella (áreas, a confirmar, #77). |
| Frecuencia de Nuevos Bosques | Más frecuentes en Lean, Tossie y Ostie, porque la expansión empezó allí. Muy raros en Nosie y casi imposibles en Alciss, "la región más alejada". |
| MVP | Se empieza a trabajar con la **región Valle del Sara**. |

## Contradicciones registradas (sin resolver)
- **"Nosie"** no aparece ni entre las áreas del Valle del Sara ni entre las de Alcuss (#77).
- **Alciss**: el dueño la llama "la región más alejada", pero la lista como parte de la región de Alcuss. Puede ser región o área (#77).
- **Glosario §8**: sus regiones del Sur (Safio, Nan, Dorias, Sagra (valle del Sara), Gumna, Calf, Ungol, Amuss, Hagat, Uta, Sanag, Sunasem, Ifa, Foss) no incluyen Alcuss ni ninguno de los nombres nuevos (Lean, Tossie, etc.). Probablemente "Valle del Sara" equivale a "Sagra (valle del Sara)", a confirmar (#77).
- **Origen de la expansión de los Nuevos Bosques**: según el dueño, Lean, Tossie y Ostie. Según el glosario §7, Estrella Azul surgió en Dorias (Tarca de Trastas). No es necesariamente incompatible (origen del movimiento frente a origen de la expansión), pero hay que confirmarlo (#79).
- **Peaje entre Bosques frente a viaje a pie**: pasar a otro Bosque con Nujio cuesta Luz o un enfrentamiento, y a la vez "puedes viajar por todo el mapa a pie". No está claro si ir a pie evita el peaje (#72).
- **ADR 0004/0005**: "el chunk puede tener o no una villa" y "una zona nueva puede ser una villa, un bosque o una geografía" no cuadran con que la zona sea ahora un Bosque. El glosario §5 pone la villa dentro del Bosque (una por Bosque) (#61, #82).
- **Glosario, incoherencia interna**: "un Nujio por Bosque" (§3) frente a Umun-Mal, que "ocupa 3 Bosques y tiene 4 Nujio" (§5). Afecta a la equivalencia de #69.

## Consecuencias
- La clave de generación pasa a ser región / área / Bosque / chunk (formato: `world-gen-dev` + `engine-architect`).
- Para el prototipo, los árboles **no son colisión**. Solo bloquean el agua, los riscos y las pendientes pronunciadas.
- El slice de Aventura transcurre en **un Bosque inicial** del Valle del Sara, con movimiento libre entre sus chunks. Salir de él (peaje de Luz o Únicos) queda para la siguiente iteración.
- Recursos o estados nuevos que necesitan fuente, sumidero y efecto al agotarse antes de implementarse: cansancio (#73) y Luz como peaje (#71).
- `world-gen-dev` necesita la imagen o los datos del mapa del Valle del Sara (qué áreas están al norte y al sur, ríos navegables) en `docs/design/world/` (#80).
