# Persuasión de villas: muestras de diálogo

> Dueño: `narrative-writer`. Estado: **PROPUESTA**. Rama garelina del arco ([`arco-dos-caminos.md`](arco-dos-caminos.md), Acto IV-b, hito 3).
> Las cuatro vías son del dueño: resolver su necesidad, diálogo y argumentos, fuerza del grupo (sin matar) y regalar Piedras. Cuánto cuenta cada vía, qué umbrales hay y qué pasa en el mundo al convencer una villa lo decide `game-designer`. Aquí solo hay texto y su intención.
> Formato: `Speaker: texto`. Cada mensaje cabe en **2 líneas de 38 caracteres** como mucho. Los `id` son propuestos para `data/quests/` o `data/npcs/`.

## Quién escucha
- **Ildo**: decide y guía la villa (§5). Es a quien se le habla de futuro: necesidad, argumentos, fuerza.
- **Ista**: dictamina lo justo ante la Luz y el pacto, y **valúa Luz y Piedras** (§5, §6). Es a quien se le habla de valor: las Piedras se le dan al Ista. El trueque lo debaten el Ildo y un Ista (§5): por eso las Piedras nunca convencen solas, el Ista se lo tiene que llevar al Ildo.
- Si la villa no tiene Ista (no siempre sale, `npcs-y-villas.md`), las Piedras las recibe el Ildo, que desconfía más.

## Qué villa es (cambia el tono, no las vías)
| Villa | Estado de su Bosque | Disposición |
|---|---|---|
| **Huérfana** | muerto (sin Nujio) | Necesita una salida. Escucha. |
| **Asustada** | corrupto o enojado | Tiene miedo del Iserald. Duda. |
| **Fiel** | sano | No te necesita. Te lo dice con educación. |

---

## Vía 1. Resolver su necesidad
El adoc garelino sigue siendo adoc: apacigua Únicos, apaga incendios, trae un dumno. Luego habla.

`id: persuasion_necesidad_huerfana` (Ildo; villa con Nujio muerto, Únicos sueltos que piden Luz)
- Ildo: Los Únicos que quedan nos piden Luz.
- Ildo: Ya no tenemos Nujio al que dársela.
- Adoc (tras resolverlo): Ya no piden. Y ustedes siguen sin fruto.
- Ildo: Lo sé. Habla. Te has ganado eso.

`id: persuasion_necesidad_asustada` (Ildo; Bosque corrupto)
- Ildo: Apaciguaste a lo que nos acechaba.
- Ildo: Pero el Nujio sigue enfermo. Lo noto.
- Ildo: Si cae, ¿qué nos queda? Dímelo tú.

`id: persuasion_necesidad_fiel` (réplica de villa fiel)
- Ildo: Gracias, adoc. El Nujio te lo pagará.
- Ildo: Con Luz. Como se ha pagado siempre.
- Ildo: Si vienes a vendernos piedras, no.

---

## Vía 2. Diálogo y argumentos
Argumentos del adoc garelino (el jugador elige uno por conversación; los mejores dependen de la villa). Cada uno tiene su réplica fiel.

`id: persuasion_argumentos`

| id | Argumento (adoc) | Mejor en | Réplica de villa fiel (Ildo o Ista) |
|---|---|---|---|
| `arg_trabajo` | "La Piedra pide manos. El trabajo honra a los Originales." | Huérfana | Ildo: "Los Originales nos dieron un Nujio, no una azada." |
| `arg_iserald` | "Un Nujio puede perder la cordura. La Piedra, no." | Asustada | Ildo: "Una piedra tampoco te avisa en Pensamiento." |
| `arg_peaje` | "Sin peajes, sin Botarramas. Caminos abiertos." | Asustada | Ista: "El peaje es justo. Lo que se toma, se paga." |
| `arg_oficio` | "Maestro y aprendiz. Así se aprende un oficio." | Huérfana | Ildo: "¿Y quién guardará lo que sabían los muertos? El Nujio lo guarda." |
| `arg_hambre` | "Cuando el Bosque se cansa, la villa no come." | Huérfana, Asustada | Ildo: "Este Bosque no se cansa. Míralo." |
| `arg_libres` | "Nadie les dirá cuántos pueden ser." | Asustada | Ista: "Aledra existe por algo. Crecer sin permiso enferma." |

Notas de lore de las réplicas:
- `arg_oficio`: el Nujio almacena el conocimiento de los oficiantes de su villa (§3). Es la objeción más fuerte de una villa fiel.
- `arg_libres`: Aledra aparece cuando la villa crece sin permiso y causa enfermedades (§3). Es la objeción que no se puede rebatir con palabras.

`id: persuasion_argumentos_huerfana_acepta`
- Ildo: Doscientas bocas, adoc. Ni una más.
- Ildo: Si tu piedra da de comer, la plantamos.

`id: persuasion_argumentos_asustada_duda`
- Ildo: Me das razones. Mi Nujio me dio siglos.
- Ildo: Vuelve cuando caiga. Si cae, te escucho.

`id: persuasion_argumentos_fiel_cierra`
- Ildo: Hablas bien. Para ser adoc, demasiado.
- Ildo: Brille tu Luz. Aquí, la del Nujio.

---

## Vía 3. La fuerza del grupo (sin matar)
El grupo del adoc se planta en la plaza, junto al Nujio. Nadie levanta un arma contra nadie. Es presión, no combate. Si alguien de la villa se resiste, el combate es no letal (ADR 0004). Intención: funciona rápido y sale caro (la villa cede de palabra y guarda rencor; la Senda baja; los adoc fieles lo sabrán).

`id: persuasion_fuerza_jelio` (antes de entrar)
- Jelio: Déjame a mí. En el Gumna no preguntábamos.
- Adoc: Aquí no se toca a nadie. Solo que nos vean.

`id: persuasion_fuerza_huerfana`
- Ildo: ¿Vienes con tanta gente a ayudarnos?
- Ildo: ¿O a decirnos qué tenemos que hacer?
- Ildo: No tenemos fuerza ni Nujio. Haz lo que quieras.

`id: persuasion_fuerza_asustada`
- Ildo: Seis armas en mi plaza. Junto al Nujio.
- Ildo: Él lo ve. Yo lo veo. Está bien. Sí.
- Ildo: Pero no me pidas que lo diga contento.

`id: persuasion_fuerza_fiel` (réplica de villa fiel)
- Ildo: No hay puertas cerradas en esta villa.
- Ildo: Tampoco vas a encontrar a nadie que ceda.
- Ista: Lo que se toma por miedo no es pacto.
- Ista: El Nujio ya ha visto tu cara, adoc.

Nota: en una villa fiel, la fuerza no convence; solo deja constancia. Propuesta para `game-designer`: puede enojar al Bosque de esa villa.

---

## Vía 4. Regalar Piedras
Las Piedras se le dan al Ista, que las valúa (§6). Las Piedras hacen crecer plantas que dan alimento cada cierto ciclo; unas mueren tras producir y otras tardan más (§7).

`id: persuasion_piedras_huerfana` (Ista)
- Ista: Déjame verla. Pesa poco para lo que dicen.
- Ista: Si da lo que prometen, vale más que Luz.
- Ista: Se lo llevaré al Ildo. El trueque es cosa de dos.

`id: persuasion_piedras_asustada` (Ista)
- Ista: Una piedra no es un regalo. Es una deuda.
- Ista: Me la quedo. Por si el Nujio cae.
- Ista: Que conste: guardada, no plantada.

`id: persuasion_piedras_fiel` (réplica de villa fiel)
- Ista: Aquí no vale nada, adoc. No hay déficit.
- Ista: Tenemos fruto. Llévala a quien no tenga.
- Ildo: Y no la entierres en mi Bosque.

Nota de lore: el multiplicador del Ista (−5 a +5, §6) explica la réplica fiel: donde el fruto sobra, la Piedra no tiene valor.

---

## Cierres

`id: persuasion_villa_se_une` (cualquier vía que llegue al umbral)
- Ildo: Plantaremos lejos del Nujio. Al borde.
- Ildo: Brille tu Luz en los Nuevos Bosques.

`id: persuasion_villa_se_une_huerfana` (si su Nujio murió)
- Ildo: Aquí ya no hay a quién ofender. Planta.

`id: persuasion_villa_rechaza_definitivo` (villa fiel que el adoc ya ha intentado por las cuatro vías)
- Ildo: Lo intentaste todo. Lo sé. Lo vimos.
- Ildo: Esta villa es del Nujio. Hasta que no lo sea.
- Ildo: No vuelvas con piedras. Vuelve con Luz.

`id: persuasion_avessa` (Avessa, Ildo PROPUESTA; ver `personajes.md`)
- Avessa: Una villa no come de promesas.
- Avessa: Pero esta piedra no es una promesa. Pesa.
- Avessa: Dámela. Y no me pidas que la quiera.
