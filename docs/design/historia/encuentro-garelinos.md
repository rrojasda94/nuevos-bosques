# Escena: el cruce con los garelinos (Acto III)

> Dueño: `narrative-writer`. Estado: **PROPUESTA**. Personajes y lugar: PROPUESTA (ver [`personajes.md`](personajes.md) y [`arco-dos-caminos.md`](arco-dos-caminos.md)).
> Las consecuencias de cada opción son **intención narrativa**. Los números (inclinación, Senda, relación) y si hay un medidor de bando los decide `game-designer`. La lógica la implementa `rpg-systems-dev`.
> Formato listo para pasar a JSON: cada bloque tiene un `id`; cada mensaje es `speaker: texto` y cabe en **2 líneas de 38 caracteres** como mucho. Las opciones llevan `id`, texto de botón (≤ 24 caracteres) y consecuencia en una línea.

## Contexto
- **Lugar**: el borde entre un Bosque muerto (gris, sin Nujio) y un Nuevo Bosque recién sembrado (troncos color madera, hojas verdes), al noroeste del Valle del Sara (Lean, Tossie u Ostie).
- **Quién**: Oridna (ledai), un jelio y un garelino joven sin nombre. Están enterrando Piedras en la tierra gris.
- **Cuándo**: tras el hito del Acto II (el adoc ha visto un Bosque morir y un Nuevo Bosque crecer). Se dispara al entrar en el chunk del borde.
- **Estado según la Senda** al empezar la escena: `violenta`, `neutral` o `respetuosa` (umbrales de `moralidad-y-progresion.md`).
- **Versión "tú se lo pides"**: al final del archivo, para cuando el adoc busca a los garelinos por su cuenta.

Speakers: `Oridna`, `Jelio`, `Garelino`, `""` (narración).

---

## Apertura común
`id: garelinos_cruce_apertura`
- "": La tierra está gris. No hay Botarramas.
- "": Tres figuras entierran algo en el suelo.
- Garelino: ¡Ledai! Un adoc. Viene armado.

---

## Versión VIOLENTA
`id: garelinos_cruce_violenta`
- Jelio: Mira quién viene. El que tumba Botarramas.
- Oridna: Baja el arma, adoc. Aquí no hay Únicos.
- Oridna: Este Bosque murió. Nadie te va a cobrar.
- Jelio: Los Bosques ya te temen. Lo sabes, ¿no?
- Oridna: Has hecho media obra sin saberlo.
- Oridna: Ven con nosotros. Haz la otra media.

`id: garelinos_cruce_violenta_opciones`

| id | Botón | Respuesta inmediata | Consecuencia |
|---|---|---|---|
| `aceptar` | "Voy con ustedes" | Oridna: "Bien. Toma. Pesa menos de lo que crees." ("": Recibes: 3 Piedras.) | Entras en la rama garelina; Oridna pasa a aliada; el sfida lo notará al volver. |
| `rechazar` | "No soy de los suyos" | Oridna: "Tus actos dicen otra cosa. Ya volveremos a vernos." | Sigues fiel; la puerta queda abierta y la próxima invitación llega sin prueba. |
| `aplazar` | "Aún no" | Oridna: "No hay prisa. Los Nujio sí la tienen." | Sin cambio de bando; se habilita "tú se lo pides" más tarde, sin coste extra. |
| `echar` | "Váyanse de aquí" | Jelio: "¿Tú? ¿Defendiendo un Bosque muerto?" | Combate no letal contra el jelio y el garelino; si ganas, se retiran; Oridna no pelea y se va con ellos. |

`id: garelinos_cruce_violenta_echar_post`
- Oridna: Pelear por lo muerto. Qué adoc más raro.
- Oridna: Cuando quieras hablar, búscame en el norte.

---

## Versión NEUTRAL
`id: garelinos_cruce_neutral`
- Oridna: Quieto. Es un adoc, no un Único.
- Oridna: No venimos por tu Bosque. Este ya no tiene quien lo cobre.
- Garelino: Plantamos. Nada más. ¿Quieres ver?
- Oridna: Me han hablado de ti. Ni de un lado ni del otro.
- Oridna: Te propongo algo pequeño. Un favor.
- Oridna: Lleva esta Piedra a la villa del Bosque muerto.
- Oridna: Que su Ildo la tenga en la mano. Solo eso.

`id: garelinos_cruce_neutral_opciones`

| id | Botón | Respuesta inmediata | Consecuencia |
|---|---|---|---|
| `aceptar_prueba` | "La llevaré" | Oridna: "Gracias. No le digas nada. La piedra habla sola." | Encargo "La Piedra en la mano"; al cumplirlo, Oridna te invita (pasa a la versión violenta de la invitación, sin el jelio). |
| `pedir_unirse` | "Quiero ir con ustedes" | Oridna: "Así, sin más. Primero lleva la Piedra." | Mismo encargo; tu inclinación garelina sube algo más por haberlo pedido. |
| `preguntar` | "¿Qué es esa piedra?" | (bloque `garelinos_cruce_preguntar`) | Información sin compromiso; vuelve a estas opciones. |
| `rechazar` | "No llevo piedras" | Oridna: "Como quieras. La villa la recibirá igual, de otra mano." | Sigues fiel; la villa del Bosque muerto recibe Piedras de Oridna más tarde. |
| `echar` | "Váyanse de aquí" | Oridna: "No vamos a pelear por tierra gris. Vámonos." | Se retiran sin combate; Oridna recuerda que la echaste; la próxima vez llegará con menos paciencia. |

`id: garelinos_cruce_preguntar`
- Oridna: La hizo Gael, en la Tarca de Trastas.
- Oridna: La entierras, trabajas, y la planta da.
- Oridna: No pide Luz. No se vuelve loca. No se cansa.
- Garelino: Pero hay que regarla. Mucho. Todos los días.
- Oridna: Eso honra a los Originales. ¿O no?

---

## Versión RESPETUOSA
`id: garelinos_cruce_respetuosa`
- Jelio: Adoc del Nujio. Apártate, que no va contigo.
- Oridna: Calma. Sabe dónde pisa. Se le nota.
- Oridna: Tú pagas peajes, ¿verdad? Todos.
- Oridna: Y dejas ofrendas sin que te las pidan.
- Oridna: Respeto eso. Pero mira a tu alrededor.
- Oridna: ¿Dónde está el Nujio que pagaste aquí?
- Oridna: No venimos por tu Bosque, adoc. Vete en paz.

`id: garelinos_cruce_respetuosa_opciones`

| id | Botón | Respuesta inmediata | Consecuencia |
|---|---|---|---|
| `irse` | "Me voy en paz" | Oridna: "Brille tu Luz, adoc. La tuya." | Sigues fiel; no hay invitación; Oridna te recordará con respeto en la rama fiel. |
| `echar` | "Aquí no se siembra" | Jelio: "Por fin algo de carácter." | Combate no letal; si ganas, se retiran; Senda sube; Oridna te nombra rival, no enemigo. |
| `preguntar` | "¿Qué es esa piedra?" | (bloque `garelinos_cruce_preguntar`) | Información sin compromiso; vuelve a estas opciones. |
| `pedir_unirse` | "Quiero ir con ustedes" | (bloque `garelinos_cruce_respetuosa_pide`) | Oridna duda y pide una prueba dura (abajo). |

`id: garelinos_cruce_respetuosa_pide`
- Oridna: ¿Tú? ¿El que paga hasta el último peaje?
- Jelio: Es una trampa, ledai. Lo manda su sfida.
- Oridna: Puede ser. Por eso te voy a pedir algo.
- Oridna: Un Bosque al este se está corrompiendo.
- Oridna: Su villa nos llamó. Tú, no lo salves.
- Oridna: Llega tarde. Solo eso. Llega tarde.

`id: garelinos_cruce_respetuosa_pide_opciones`

| id | Botón | Respuesta inmediata | Consecuencia |
|---|---|---|---|
| `aceptar_prueba_dura` | "Llegaré tarde" | Oridna: "Entonces sabremos lo que eres." | Encargo "Llegar tarde": si el Bosque cae sin tu ayuda, entras en la rama garelina; Senda baja; el sfida lo sabrá. |
| `retirar` | "No puedo hacer eso" | Oridna: "Lo sé. Por eso eres quien eres." | Sigues fiel; Oridna te tiene por honesto; nada más cambia. |

---

## Versión "tú se lo pides"
Para un adoc que busca a los garelinos antes del hito del Acto II, o que aplazó o rechazó. Se dispara al hablar con un garelino en un Nuevo Bosque y elegir "Busco a la ledai".

`id: garelinos_pedir_primera`
- Garelino: ¿A la ledai? ¿Para qué la quiere un adoc?
- "": Al rato, Oridna sale de entre los árboles.
- Oridna: Me buscabas. Eso no lo hace cualquiera.

Luego sigue la versión de tu Senda, empezando por el tercer mensaje.

`id: garelinos_pedir_tras_rechazo` (si antes la rechazaste o la echaste)
- Oridna: La primera vez te pedí. Ahora pides tú.
- Oridna: Te va a costar más. Ya lo sabes.

Coste: se usa siempre la prueba de la versión respetuosa ("Llegar tarde"), sea cual sea tu Senda.

---

## Resumen de salidas
| Salida | Rama | Huella |
|---|---|---|
| Aceptar la invitación (violenta) | Garelina | Oridna aliada; 3 Piedras. |
| Cumplir "La Piedra en la mano" (neutral) | Garelina | Oridna aliada; la villa del Bosque muerto ya te conoce. |
| Cumplir "Llegar tarde" (respetuosa o tras rechazo) | Garelina | Un Bosque perdido a tu nombre; desconfianza del jelio. |
| Aplazar | Fiel por ahora | Puerta abierta sin coste. |
| Rechazar o irse en paz | Fiel | Oridna vuelve en el Acto IV-a. |
| Echar (combate no letal o retirada) | Fiel | Oridna rival; el jelio te busca en el Acto IV-a. |

## Notas para el paso a JSON
- Los textos de botón deben revisarse con `ui-ux-dev` si el panel de opciones es más estrecho que 24 caracteres.
- "Recibes: 3 Piedras." usa el patrón de `primera_mision.json` ("Recibes: Cuenco ritual."). La cantidad la fija `game-designer`.
- "Gael" aparece solo en boca de Oridna (duda de lore 2 del arco). Si el dueño fija una sola grafía, se cambia aquí.
