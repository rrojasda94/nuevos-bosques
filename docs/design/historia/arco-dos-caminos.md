# Arco "Dos caminos": propuesta de historia

> **BORRADOR APARCADO, no canon** (dueño, 2026-10-25: "por ahora no se cuales podrian ser las historias. Centremonos en mecanicas, jugabilidad, desarrollo de personaje y de ahi buscamos crear la historia del juego."). Los actos, hitos y finales de este arco quedan aparcados.
> **Nombres NO aprobados**: Oridna → la ledai; Urdan → un adoc veterano; Avessa → el Ildo vecino; Tiunel → el Sfida (ver `personajes.md`).
> **Correcciones del dueño que valen igualmente**:
> - Los Nuevos Bosques se siembran **donde el Bosque de Nujio ya no está**: se tala el Bosque muerto y luego se siembra (no junto a un Nujio debilitado).
> - El adoc que se une a los Nuevos Bosques se vuelve **magra**: los Bosques viejos y nuevos no son compatibles.
> - Los ledai de la Tarca de Trastas son como **profetas** de Garel / Estrella Azul; cualquiera puede hacerse garelino y seguirlos.

> Dueño: `narrative-writer`. Estado: **PROPUESTA** para el dueño del proyecto (worldbuilder). No es canon hasta que él lo apruebe.
> Rama: `design/dos-caminos`. Mecánicas (Senda, cambio de bando, persuasión, coste de la redención): las define `game-designer` en `docs/design/mechanics/` y `docs/decisions/`. Aquí solo hay historia, tono y texto.
> Fuente de verdad del lore: [`docs/glosario_nuevos_bosques.md`](../../glosario_nuevos_bosques.md). Todo lo que no sale de ahí lleva la marca **PROPUESTA**.
> Archivos hermanos: [`personajes.md`](personajes.md), [`encuentro-garelinos.md`](encuentro-garelinos.md), [`villas-persuasion.md`](villas-persuasion.md).

## Idea del dueño (textual)
> "podriamos unir el modo garelino aqui mismo. Porque hariamos que dependiendo del camino del adoc, podria ser un detractor de los bosques y tomar parte de los nuevos bosques. Puedes juntar tu grupo y tratar de convenser a las villas para unirse a los nuevos bosqes."

Más: el cambio de bando es gradual según tus actos; hay un momento de historia en que te cruzas con los garelinos y te invitan a unirte, o tú se lo pides; se puede volver atrás con un gran costo; a las villas se las convence resolviendo su necesidad, con diálogo y argumentos, con la fuerza del grupo (sin matar) o regalando Piedras.

## Límites de tono
- Sobrio, de mito y de oficio. Nadie habla de "destino" ni de "elegido". Se habla de Luz, de fruto, de trabajo, de lo que el Nujio oye.
- Ningún bando es el malo. Los Bosques no son perfectos (glosario §3: "No es perfecto"); los Nuevos Bosques trajeron la guerra al Sur (§7). Las dos cosas son verdad a la vez.
- **No se mata gente** (ADR 0004). La guerra de la era existe de fondo, en la cuenca del Gumna (§9), lejos. En el Valle del Sara el conflicto se juega con palabras, con Piedras, con Únicos y con combates no letales.
- Sin lore dumps: lo que el jugador sabe de Estrella Azul lo sabe por lo que dice la gente, por una Piedra en la mano y por un Bosque de troncos color madera.

---

## 1. Premisa
Era tardía de los Nuevos Bosques (glosario §9). Estrella Azul domina el vado oeste del Sara, salvo Umun-Mal, y gran parte del este. En la cuenca del Gumna hay batallas. Al este del Ungol están los ueutrec. Hay Únicos fuera de control en algunas regiones.

El Valle del Sara está en la costura. Al noroeste (Lean, Tossie, Ostie) los Nuevos Bosques ya crecen con frecuencia: troncos color madera, hojas verdes, gente que trabaja la tierra y comercia con Piedras. Al este, hacia Nosie, casi no los hay y la Luz sigue siendo la moneda (§6: "Al oeste dominan las Piedras; al este la Luz").

Tu villa natal está en algún punto del valle, dentro del Bosque de su Nujio. El Nujio no tiene nombre propio (§3); la villa lleva el de su Original fundador (§5). Allí se te dio el oficio de adoc en un riutash, frente al Nujio. Tu villa paga su Luz, recibe su fruto y no guarda comida. Por ahora el Nujio está en calma.

Pero los Bosques se están cansando. Cada vez hay más Únicos descarriados, más Bosques corruptos y más Iserald (§3: "Más frecuente en la era de los Nuevos Bosques"). Cuando un Nujio muere, su villa se queda sin fruto. Y entonces llega alguien con una Piedra en la mano.

**Pregunta del arco**: cuando el Bosque deja de dar, ¿le debes todavía tu Luz?

## 2. El adoc protagonista
- Lenfi del Valle del Sara, cultura Limaco (§4: Limaco = Sara, Gumna). Lo crea el jugador; la historia no le da nombre, sexo ni pasado fijos.
- Oficio: adoc. Protector, único especialista en armas, para apaciguar Únicos descarriados (§5). Es un oficio respetado y a la vez incómodo: el adoc es el lenfi que más cerca está de ser un guerrero, y ser guerrero está mal visto (§7, Guerra).
- Es joven en el oficio: el Ofomni descarriado es su primera misión (ya existe). Los otros adoc están fuera.
- **Lo que está en juego para él (PROPUESTA)**: el adoc es el oficiante que más Bosques ve morir. Por eso es el primero en dudar. Y si cambia de lealtad, deja de servir al Nujio que le dio el oficio: a ojos de su villa, se acerca a ser **magra** (§5: quien abandona o cambia de oficio). Ver "Preguntas de lore".

## 3. Estructura en actos (partida de Aventura)
Cada acto se cierra con un hito. La Senda (violenta / neutral / respetuosa) y la inclinación hacia los Nuevos Bosques (mecánica de `game-designer`) cambian lo que pasa dentro de cada acto, no el orden.

### Acto I. Primer encargo (existe: `data/quests/primera_mision.json`)
- El sfida natal te aborda: el Nujio ha oído en Pensamiento a un Ofomni descarriado que viene hacia la villa. Lo interceptas o llega y daña la villa.
- **Semilla nueva (PROPUESTA)**: al volver con el sfida tras la misión (cumplida o fallida), una línea extra deja la primera duda. El Ofomni no se descarrió solo: venía de un Bosque del noroeste que ya no responde.
  - Sfida: "El Nujio dice que venía del noroeste."
  - Sfida: "De un Bosque que ya no le contesta."
- Hito: primera misión cerrada. Se abren las misiones de villa y las de Pensamiento.

### Acto II. El desgaste de los Bosques
El adoc sale del valle conocido. Tres escenas marcan el acto, en el orden que dé la partida (por Pensamiento, por encargos del sfida o por el camino):

1. **El Bosque corrupto (PROPUESTA de escena)**. Una villa vecina, la de **Avessa** (Ildo, PROPUESTA; ver `personajes.md`), pide adoc: su Nujio pierde la cordura. Colores manchados, emboscadas, Únicos que atacan sin peaje. El **errante** de ese Bosque (PROPUESTA de personaje) guía al adoc hasta el Nujio. Allí se puede devolver cordura con ofrendas y descanso (mecánica existente en `bosques-y-relacion.md`) o no llegar a tiempo.
2. **El Iserald**. En un Bosque cercano (el de Avessa si el jugador falla en la escena 1, otro si no) se desata un Iserald. El Nujio muere y el Bosque pasa a muerto (dueño, `monstruos.md`). **Urdan**, adoc veterano de tu villa (PROPUESTA), lanza la llamada de adoc: hacen falta de 6 a 8 para contenerlo. Si el adoc juega en solitario, debe huir: el Miedo enseña lo que es un Iserald mejor que cualquier diálogo.
3. **El primer Nuevo Bosque**. Camino del noroeste (Tossie u Ostie), el adoc entra en un Bosque que no cobra peaje, sin Botarramas, con troncos color madera y animales que parecen mamíferos (`bosques-y-relacion.md`). Gente trabajando la tierra. Nadie le pide Luz. Un niño le ofrece una Piedra para mirarla. Nada más: sin explicación.

- Hito: el adoc ha visto un Bosque morir y un Bosque nuevo crecer. A partir de aquí la gente le pregunta qué piensa.
- **Gente del acto**: el sfida (cada vez más callado), Urdan (cada vez más duro), Avessa (cada vez más desesperada), el errante (siempre igual).

### Acto III. El cruce (escena clave)
Guion completo en [`encuentro-garelinos.md`](encuentro-garelinos.md).

- **Dónde (PROPUESTA)**: en el borde entre un Bosque muerto y un Nuevo Bosque recién sembrado, al noroeste del valle. Un grupo garelino entierra Piedras en la tierra gris del Bosque muerto. No atacan un Bosque vivo: siembran en lo muerto. Así la escena puede ser una invitación y no una batalla.
- **Quién**: **Oridna**, ledai de la Tarca de Trastas (PROPUESTA; los ledai son clérigos de Estrella Azul en esta era, §5), con dos garelinos. Uno de ellos es un jelio (§5: soldado, figura temida y de poca confianza).
- **Cuándo (PROPUESTA)**: después del hito del Acto II. Si el jugador busca a los garelinos antes, puede pedírselo él (versión "tú se lo pides").
- **Cómo llega según tu Senda**:
  - **Violenta**: te conocen de oídas. "Los Bosques ya te temen." Te invitan sin rodeos.
  - **Neutral**: te miden. Te proponen un trato pequeño, una prueba, sin invitación todavía.
  - **Respetuosa**: te ven como un adoc del Nujio, es decir, un estorbo. Te advierten. Si quieres unirte, tienes que pedirlo tú y te cuesta.
- **Salidas**: unirte, rechazar, aplazar, echarlos (combate no letal) o pedir una prueba. Cada una deja una marca en la relación con Oridna y en la inclinación (consecuencias en el guion).

### Acto IV-a. Rama fiel (el adoc sigue con los Bosques)
Hitos:
1. **Reunir a los adoc**. Con Urdan, juntar el grupo de 6–8 para el Iserald del Acto II si sigue suelto, o para otro (mecánica existente en `monstruos.md`). Solo vienen los de afinidad compatible.
2. **El Bosque bajo ataque**. Oridna vuelve, esta vez con un grupo que sí ataca un Bosque vivo, o con un grupo que ella no controla (el jelio). Combate no letal con los Únicos del Bosque como aliados. Se puede hablar con Oridna antes y después: no es una villana.
3. **La villa de Avessa**. Si su Nujio murió, Avessa ya ha aceptado Piedras. El adoc fiel no puede devolverle un Nujio. Lo que puede hacer es elegir cómo despedirse: respetar su decisión o denunciarla ante su propia villa. **(Escena de tono, sin combate.)**
4. **Final fiel**. El Nujio natal oye algo en Pensamiento por última vez en el arco: un Bosque grande del valle está a punto de lanzar a su Iserald. El adoc lo sostiene con ofrendas, descanso y su grupo, o llega tarde.
   - **"El Bosque recuerda"** (sale bien): el Bosque grande vuelve a cordura. El sfida dice por fin el nombre del adoc en la plaza. El Nuevo Bosque de Avessa sigue creciendo al lado: el valle queda partido, pero en paz.
   - **"Lo que no se pudo sostener"** (sale mal): el Iserald se desata, el Nujio muere. La villa de ese Bosque recibe Piedras de Oridna. El adoc vuelve a casa. El sfida no lo culpa; tampoco lo consuela.

### Acto IV-b. Rama garelina (el adoc se une a los Nuevos Bosques)
Hitos:
1. **La primera Piedra**. Oridna te da Piedras y una tarea: llevarlas a una villa que lo necesite. El adoc ya no paga peajes en Nuevos Bosques; en los Bosques con Nujio, los Botarramas lo miran de otra forma (mecánica de `game-designer`).
2. **Juntar tu grupo**. Gente que se suma: adoc de Senda violenta que ya no quieren trabajar para los Nujio, algún magra que huyó con su oficio (§5: "Huye con el conocimiento del oficio"), el jelio de Oridna si se lo ganas. Urdan, no: se niega (afinidad).
3. **Convencer villas**. Por las cuatro vías (ver [`villas-persuasion.md`](villas-persuasion.md)). El orden natural va de lo fácil a lo difícil:
   - la villa de un Bosque muerto (Avessa, si su Nujio murió): solo necesita una salida;
   - la villa de un Bosque corrupto: tiene miedo;
   - una villa sana, fiel a su Nujio: no te necesita y te lo dice.
4. **Sembrar**. El grupo siembra el primer Nuevo Bosque del adoc en un Bosque muerto. Trabajo, mucho trabajo (§7). Las primeras plantas dan alimento cuando toca el ciclo, y algunas mueren tras producir.
5. **Final garelino**. El adoc vuelve a su villa natal con su grupo. El Nujio natal sigue vivo. ¿Qué hace?
   - **"Brille tu Luz en los Nuevos Bosques"** (persuasión): la villa natal no abandona a su Nujio, pero acepta comerciar con Piedras y acoger a quien quiera irse al Nuevo Bosque. El valle queda con dos monedas, como el Sur entero.
   - **"La villa cerrada"** (rechazo): el Ista te declara magra (PROPUESTA, depende de la pregunta de lore 3). No te echan con violencia; simplemente nadie te habla. Tu Nuevo Bosque crece lejos de allí.
   - **Final radical (para decidir con `game-designer` y el dueño)**: forzar al Nujio natal hasta su Iserald para sembrar en su lugar. Es el objetivo original del modo Garelino (ADR 0004: eliminar al Nujio). Narrativamente es posible, pero es el final más oscuro: el adoc destruye el Bosque que le dio el oficio, y el Iserald es fatal. **Recomendación**: si existe, que sea un final y no un hito, y que la historia lo trate como una pérdida, no como una victoria.

## 4. Cómo se refleja la Senda en lo que te dicen
La Senda mide tu trato con los Bosques (`moralidad-y-progresion.md`). La inclinación garelina es otra cosa (la define `game-designer`). Aquí, una muestra de cómo cambia la voz de la gente. Cada mensaje cabe en 2 líneas de 38 caracteres.

| Quién | Violenta | Neutral | Respetuosa | Ya garelino |
|---|---|---|---|---|
| Sfida natal | "El Nujio te oye llegar. No le gusta." | "Brille tu Luz, adoc." | "El Nujio duerme mejor cuando vuelves." | "El Nujio no dice tu nombre. Ya no." |
| Pholua de la villa | "No toques el fruto. Ya lo cojo yo." | "Fruto de hoy. Uno, como siempre." | "Te guardé el más maduro, adoc." | "¿Eso que traes es una Piedra?" |
| Adoc desconocido | "Contigo no salgo. Pregunta a otro." | "¿Vas al norte? Cuidado con el borde." | "Si vas al norte, voy contigo." | "Los Nujio pagan poco, ¿verdad?" |
| Rogoc en el camino | "Te cobro el doble. Ya sabes por qué." | "Traigo noticias del Gumna. Malas." | "Para ti, a precio de villa." | "¿Piedras o Luz? Acepto las dos." |
| Garelino en el camino | "Tú eres el que tumba Botarramas." | "Paso, adoc. No buscamos pelea." | "Adoc del Nujio. Apártate." | "Brille tu Luz en los Nuevos Bosques." |

Reglas de escritura:
- La violencia se nota en la distancia (la gente se aparta, cobra más, no te ofrece), no en insultos.
- El respeto se nota en pequeñas cosas (el fruto más maduro, un "voy contigo").
- El bando garelino se nota en la moneda y en el saludo: "Brille tu Luz en los Nuevos Bosques" es la variante posterior del glosario (§5).

## 5. La redención
Se puede volver atrás con un gran costo (dueño). Hay dos sentidos.

### De garelino a fiel (el caso principal)
- **Lo que pesa (PROPUESTA de lore)**: el adoc ha servido a quien quiere un Sur sin Nujio. Su villa lo trata como a un magra. Un magra, según el glosario, huye pidiendo asilo y luego suele ser desterrado (§5).
- **El camino**: el adoc vuelve y **pide asilo** en su villa natal. El **Ista** dictamina lo justo ante la Luz y el pacto (§5). Lo que el Ista pide es el costo:
  1. **Entregar las Piedras.** Todas. Se entierran fuera del Bosque.
  2. **Perder el grupo.** Quien te siguió por los Nuevos Bosques no te sigue de vuelta. Oridna no te persigue, pero no vuelve a hablarte igual.
  3. **Una reparación** al Bosque: devolver la cordura a un Bosque corrupto, contener un Iserald con los adoc, o apagar lo que tu grupo dañó. Urdan decide si te acompaña.
  4. **El riutash frente al Nujio** (PROPUESTA): el adoc pasa un riutash junto al Nujio natal, en dirección norte o sur, como cuando recibió el oficio (§5, Oficio). Si el Nujio lo acepta, el oficio "vuelve". Si no, el adoc sigue siendo adoc para sí mismo, pero no para la villa.
- **Lo que no vuelve**: lo que el adoc hizo sigue hecho. El Nuevo Bosque que sembró sigue creciendo. Las villas que convenció no vuelven a su Nujio (y si su Nujio murió, no tienen adónde volver).
- Sfida: "El Nujio te oyó. No dijo que sí."
- Sfida: "Tampoco dijo que no. Vuelve mañana."

### De fiel a garelino tarde (el caso inverso)
- Un adoc que rechazó a Oridna y luego la busca no recibe la misma invitación. Le cuesta una prueba más dura (llevar Piedras a una villa en contra de su Ildo, o no defender un Bosque que lo llama) y la desconfianza del jelio.
- Oridna: "La primera vez te pedí. Ahora pides tú."

## 6. Preguntas abiertas del lore que toca
Ninguna se resuelve aquí. Se señalan para que el dueño decida.

1. **¿Los garelinos son seguidores de Garel / Estrella Azul?** El GDD lo trata como deducción a confirmar (#25). Este arco lo **asume** (PROPUESTA): "garelino" viene de Garel. Si el dueño dice que no, el arco aguanta cambiando la fe de Oridna, pero pierde a los ledai como clérigos.
2. **Garel frente a Gael** (#46). PROPUESTA de uso, sin tocar el glosario: "Garel" en boca de la gente común y de los garelinos (de ahí el nombre); "Gael" solo en boca de Oridna, como forma de culto o de Dorias. Es reversible: si el dueño fija una sola grafía, se usa esa en todo el texto.
3. **¿Un adoc garelino es magra?** El adoc no deja de proteger ni de llevar armas, pero deja de servir al Nujio que le dio el oficio. ¿Basta eso para ser magra?
4. **¿Qué pasa con el oficio si el Nujio muere?** El Nujio guarda el conocimiento de los oficiantes de su villa (§3) y el oficio se recibe frente a él (§5). Sin Nujio, ¿cómo aprenden los nuevos? El canon dice que maestro y aprendiz son siempre del mismo oficio, y Oridna lo usa como argumento. Falta saber si es suficiente en el lore.
5. **¿Se puede sembrar un Nuevo Bosque en un Bosque muerto?** El glosario lo da como alternativa para villas con Nujio muerto por Iserald (§7). Que se siembre **en el mismo suelo** es PROPUESTA (pregunta #140).
6. **El errante libre**. Un errante no puede salir de su Bosque mientras el Nujio exista (§3). Si el Nujio muere, ¿queda libre, como el Caminante (errante sin Nujio)? Los ueutrec surgen en la era tardía "sobre todo desde el valle del Sara" (§4). El arco **insinúa** (PROPUESTA) que el errante de Avessa, libre, se va hacia el este. No afirma que se combine.
7. **Estrella Azul en Pensamiento**. Es un combinado de una riumini (fragmento de Riumna, ojo de la noche) y un humano (§7). ¿Puede su voz llegar al adoc en Pensamiento, de noche? El arco lo propone como opción; la alternativa segura es que Oridna recite sus palabras.
8. **Jelios y "no se mata gente"**. Los jelios aparecen con los Nuevos Bosques y la Guerra trajo matanzas (§5, §7). En el Valle del Sara del juego nadie mata. El arco lo explica por tono: Oridna desprecia la matanza del Gumna y lleva a un jelio que sí la conoció.
