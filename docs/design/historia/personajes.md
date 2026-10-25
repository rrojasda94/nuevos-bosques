# Personajes recurrentes del arco "Dos caminos"

> **BORRADOR APARCADO, no canon** (dueño, 2026-10-25: "por ahora no se cuales podrian ser las historias. Centremonos en mecanicas, jugabilidad, desarrollo de personaje y de ahi buscamos crear la historia del juego.").
> **Nombres NO aprobados** (dueño: "No"). Léanse como roles genéricos hasta que el dueño ponga nombres:
> - Oridna → **la ledai** (de la Tarca de Trastas);
> - Urdan → **un adoc veterano**;
> - Avessa → **el Ildo vecino**;
> - Tiunel → sin nombre (**el Sfida**).
>
> Lore confirmado: los ledai de esta era son como **profetas**, al menos los de la Tarca de Trastas, donde está Garel / Estrella Azul, y cualquiera puede hacerse garelino y seguir a los ledai.

> Dueño: `narrative-writer`. Estado: **PROPUESTA**. Todos los nombres propios de este archivo son PROPUESTA y deben aprobarse y registrarse en el glosario antes de usarse en el juego (regla del agente). El glosario es del dueño: no se ha tocado.
> Arco: [`arco-dos-caminos.md`](arco-dos-caminos.md).

## Criterios
- Pocos personajes y cada uno con una función: el sfida es el Nujio que habla; Oridna es la puerta a los Nuevos Bosques; Urdan es el oficio; Avessa es la villa que tiene hambre; el errante es el Bosque que mira; la Estrella es la idea.
- Los nombres siguen la fonética de `data/text/nombres_villas.json` (dobles eses, finales en -ie, -un, -as, -el), pero **no repiten ninguno de esa lista**, porque esos son nombres de Originales fundadores (§5).
- Formato de diálogo: cada mensaje cabe en **2 líneas de 38 caracteres**, como mucho (76 caracteres). Cada personaje tiene **una** frase de voz. En las tablas, " / " separa mensajes (cajas de diálogo distintas).

---

## 1. El sfida natal
- **Nombre**: en pantalla sigue siendo "Sfida" (`data/npcs/sfida_natal.json`). Nombre propio opcional: **Tiunel** (PROPUESTA), solo si el dueño quiere que alguien lo llame por su nombre en el final fiel.
- **Rol**: la voz del Nujio natal. Da los encargos, interpreta Pensamiento y riutash. Es quien mide al adoc sin decir nunca un número.
- **Motivación**: que el Nujio no pierda la cordura. Su miedo no es a los garelinos, es al silencio: el día en que el Nujio deje de oír.
- **Voz (existente)**: "Lo que el Nujio oye, yo lo digo."
- **Cómo cambia**:
  - Rama fiel: cada vez habla más del Nujio como de alguien cansado. En el final bueno, dice el nombre del adoc en la plaza.
  - Rama garelina: no te echa. Te sigue saludando, pero deja de transmitir lo que oye el Nujio. Es su forma de castigo.
  - Redención: es quien lleva al adoc al riutash frente al Nujio.

| Momento | Mensajes |
|---|---|
| Acto II, tras ver un Bosque morir | "Esta noche el Nujio no durmió." / "Oyó caer a un hermano. Lo oímos todos." |
| Rama garelina | "Traes polvo de piedra en los pies." / "El Nujio lo nota. Yo también." |
| Redención | "Siéntate al norte del Nujio, adoc." / "Lo que oiga, lo diré. Sea lo que sea." |

## 2. Oridna, ledai de la Tarca (PROPUESTA)
- **Quién**: ledai dorica, criada en una villa de Dorias. Los ledai buscaban a los Originales; en esta era son clérigos de Estrella Azul (§5). Ella estuvo en la Tarca de Trastas, donde los ledai hallaron restos humanos, quizá de Originales (§7). Viaja libre: los ledai no pagan Luz para transitar (§5).
- **Rol**: emisaria garelina en el Valle del Sara. Es la que te cruza en el Acto III, la que te invita o te mide, y tu enlace en la rama garelina.
- **Motivación (PROPUESTA)**: vio morir de hambre a una villa cuyo Nujio se desató en Iserald. Desde entonces cree que ningún pueblo debería depender de la cordura de un árbol. Desprecia las matanzas del Gumna: siembra en lo muerto, no tala lo vivo. Eso la enfrenta con parte de su propio bando.
- **Voz**: "La piedra no cobra Luz. Pide manos."
- **Cómo cambia**:
  - Senda violenta: te invita enseguida, pero vigila tu violencia; no quiere un jelio más.
  - Senda respetuosa: te trata como a un rival digno. Si te unes, es la que más te respeta.
  - Rama fiel: vuelve en el Acto IV-a como adversaria que conversa. Nunca combate en persona.
  - Redención: no te persigue. Te devuelve una sola frase.
- **Grafía**: es la única que dice "Gael" en vez de "Garel" (PROPUESTA de uso, ver duda de lore 2 del arco).

| Momento | Mensajes |
|---|---|
| Acto III, Senda respetuosa | "No venimos por tu Bosque, adoc." / "Este ya no tiene quien lo cobre." |
| Rama garelina | "Una villa no se gana con miedo." / "Se gana cuando come al día siguiente." |
| Redención | "Vuelve con tu Nujio. Te esperaba." / "Que te dé lo que nosotros no pudimos." |

## 3. Urdan, adoc veterano (PROPUESTA)
- **Quién**: el adoc más viejo de tu villa natal. Ha apaciguado Únicos durante décadas y vio un Iserald de joven. Es uno de los "otros adoc" que estaban fuera en el Primer encargo.
- **Rol**: el oficio hecho persona. Lanza la llamada de adoc contra el Iserald (Acto II) y es el núcleo del grupo de 6–8 en la rama fiel. Encaja con los "otros adoc" de `otros-adoc.md`: siempre aliado, nunca hace daño, y su afinidad depende de tu Senda.
- **Motivación**: que el oficio siga siendo lo que es. Para él, el adoc apacigua; no conquista ni siembra. Teme a los jóvenes que usan el arma para abrir paso.
- **Voz**: "El arma cierra el paso. No lo abre." (eco de la regla de `sigilo-y-robo.md`: con el arma en la mano, el paso se cierra).
- **Cómo cambia**:
  - Senda violenta: no quiere salir contigo (afinidad). Te lo dice a la cara.
  - Senda respetuosa: te elige para la llamada de adoc. En el final fiel, te cede el frente.
  - Rama garelina: se niega a trabajar contigo. Te cruzas con él en un Bosque que tu grupo amenaza. No pelea: se pone delante.
  - Redención: decide si te acompaña en la reparación. Si viene, lo dice con una sola palabra.

| Momento | Mensajes |
|---|---|
| Acto II, llamada de adoc | "Un Iserald no se vence. Se contiene." / "Somos seis o no somos nada. Ven." |
| Senda violenta | "Tumbas Botarramas como quien poda." / "Así no se apacigua. Así se ofende." |
| Rama garelina, en el Bosque amenazado | "No voy a pelear contigo, chico." / "Vas a tener que pasar por encima." |

> Nota: "chico" es neutro de edad, no de sexo; si el jugador elige otro, `rpg-systems-dev` puede variar la palabra o usar "adoc".

## 4. Avessa, Ildo de una villa vecina (PROPUESTA)
- **Quién**: Ildo de una villa cercana a la tuya, en un Bosque que se corrompe en el Acto II. El Ildo es heredero de los Originales y guía la villa (§5).
- **Rol**: la bisagra del arco. Su villa es la primera en sentir el hambre si el Nujio muere y la primera que se puede convencer en la rama garelina. En la rama fiel es la decisión que el adoc no puede deshacer.
- **Motivación**: que su gente coma mañana. No tiene fe en las Piedras ni en el Nujio: tiene doscientas bocas.
- **Voz**: "Una villa no come de promesas."
- **Cómo cambia**:
  - Si el adoc salva su Bosque (devuelve la cordura): se queda con su Nujio y le debe un favor al adoc. En la rama garelina es la villa más difícil.
  - Si su Nujio muere: acepta Piedras de quien se las ofrezca primero, el adoc garelino u Oridna.
  - Senda violenta: no te pide ayuda; pide a otro adoc.

| Momento | Mensajes |
|---|---|
| Acto II, pide adoc | "Mi Nujio ya no me contesta, adoc." / "Y el fruto sale amargo. Ayúdanos." |
| Tras la muerte de su Nujio | "No me hables de pactos. Ya no hay." / "Hay doscientas bocas. Eso hay." |
| Rama fiel, con Piedras ya aceptadas | "No me mires así. Tú no tenías pan." / "La piedra sí. Brille tu Luz igual." |

## 5. El errante del Bosque de Avessa (PROPUESTA)
- **Quién**: el errante del Bosque de Avessa. Ojos verdes profundos, cabello negro robusto, desnudo, sigiloso (§3). Su único objeto es un **aro de metal de Gietos** en el antebrazo (PROPUESTA de objeto; el glosario admite aro o brazalete).
- **Nombre**: **ninguno** (PROPUESTA). No lo da cuando se le pregunta; la gente lo llama "el errante". Si el dueño prefiere que los errantes tengan nombre, se le pone después.
- **Rol**: el Bosque que mira. Guía al adoc por el Bosque corrupto hasta el Nujio (Acto II) y advierte a los viajeros. Enlaza con el **metal de Gietos**, que solo se consigue robándoselo (`npcs-y-villas.md`).
- **Motivación**: no tiene una como las de los demás. Sirve de intermediario entre villa y Bosque (§3). Si el Nujio muere, por primera vez puede salir de su Bosque y no sabe qué hacer con eso.
- **Voz**: "Por aquí no. Por aquí."
- **Cómo cambia**:
  - Rama fiel: te guía. Si el Bosque sobrevive, aparece en el final fiel a lo lejos, entre los árboles.
  - Rama garelina: el jelio del grupo quiere su aro ("con eso se paga medio valle"). Robarlo es posible y grave; el errante no pelea, solo mira. No se le mata (ADR 0004).
  - Si su Nujio muere (cualquier rama): sale del Bosque y camina hacia el este. Insinúa la Voz del mundo y a los ueutrec, sin decirlo (duda de lore 6 del arco).

| Momento | Mensajes |
|---|---|
| Acto II, en el Bosque corrupto | "Por aquí no. Por aquí." / "El Nujio no te ve. Mejor así." |
| Si le roban el aro | "Era lo único." / "Ya no sé de quién soy." |
| Si su Nujio muere | "Puedo salir. Nunca había podido." / "Algo me llama desde el este." |

## 6. La voz de Estrella Azul, a distancia (PROPUESTA)
- **Quién**: Estrella Azul (Garel / Gael), combinado de una riumini disidente y un humano, sin recuerdos claros, con el poder de Crear con la Luz (§7). Nunca aparece en el Valle del Sara.
- **Cómo llega su voz (dos opciones para el dueño)**:
  - **A. Recitada** (segura, sin lore nuevo): Oridna recita sus palabras como clériga. Prefijo: "Dice Gael:".
  - **B. En Pensamiento** (PROPUESTA de lore): en la rama garelina, al dormir de noche, en vez de una misión lejana llega una voz fría y azul. Encaja con su origen en Riumna, el ojo de la noche, pero no está en el glosario.
- **Rol**: la idea, no la persona. Dice poco y no ordena nada concreto: el adoc nunca recibe una orden de matar o de talar de su boca.
- **Voz**: "No recuerdo de dónde vengo. Sé adónde vamos."
- **Cómo cambia**: solo habla en la rama garelina. En la redención, una última vez, o nunca más (elección del dueño).

| Momento | Mensajes |
|---|---|
| Rama garelina, primera vez | "No recuerdo de dónde vengo." / "Sé adónde vamos. Ven." |
| Tras convencer una villa | "Comerán sin pedir permiso a nadie." / "Eso es todo lo que quise." |
| Redención | "Vuelves a tu árbol. Lo entiendo." / "Yo también tuve un cielo al que volver." |

---

## Secundario sin nombre: el jelio de Oridna
- Soldado (§5: figura temida y de poca confianza). Acompaña a Oridna y conoció el Gumna.
- Función: el borde duro del bando garelino. Es quien propone robar el aro del errante y quien pide "la fuerza del grupo" en las villas. No mata en el juego, pero recuerda que en otros sitios se mató.
- Muestra: "En el Gumna no pedíamos permiso." / "Aquí la ledai manda. Por ahora."
