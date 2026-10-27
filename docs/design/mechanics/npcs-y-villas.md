# Ficha: NPC y servicios de las villas

> Dueño: `game-designer`. **Propuesta para la 0.5 "Los otros adoc"** (antes 0.4; `docs/design/roadmap-0.5.md`). Valores **provisionales**.
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

### Población de una villa: prioridad de oficios (#118)
Palabras del dueño (2026-10-25): "las villas tienen gente, tienen lugares para dormir. [...] Puedes determinar con ello cuales son los niveles de prioridad de una villa en cuanto a oficios. Como por ejemplo toda villa debe tener alguien que recolecte los frutos, debes tener los oficiantes principales: ildo, sfida, folat. Debe haber un sarua. Despues ya puede variar un poco las especializaciones de cada villa. Pero debe notarse como un espacio vivo."

- Cada villa genera por seed su lista de oficiantes **según la prioridad**. Todo NPC de villa tiene oficio: en el glosario §5, cada lenfi tiene uno asignado.
- **Tamaño de villa** (el glosario da de 20 a 1000–2000 habitantes; en el juego, NPC visibles representativos):
  - **pequeña**: 6–8 NPC;
  - **mediana**: 10–14;
  - **grande**: 16–20.

| Prioridad | Oficio (glosario §5) | Función (glosario) | Servicio en el juego | Pequeña | Mediana | Grande |
|---|---|---|---|---|---|---|
| **Obligatorio** | **Ildo** | Heredero de los Originales; decide y guía la villa | Persuasión y contrapersuasión (`dos-caminos.md`); encargos de villa | 1 | 1 | 1 |
| **Obligatorio** | **Sfida** | Conoce la Luz; interpreta riutash y sueños; conexión con el Nujio | Misiones (Ofomni), visiones, rastro | 1 | 1 | 1–2 |
| **Obligatorio** | **Folas / Folat** (grafía doble en el glosario: "Folas" en §5 Oficios, "Folat" en §5 Villa) | Pone en palabras las señales del Nujio, el Bosque y los Humores | Explica el estado del Bosque, sus señales y los Humores cercanos | 1 | 1 | 1–2 |
| **Obligatorio** | **Sarua** | Artesanos rituales: objetos para entregar Luz, talismanes de viaje | Favores por ofrendas; máscaras y talismanes | 1 | 1 | 2 |
| **Obligatorio** | **Pholua** | Recolectores y repartidores de la comida del Bosque | Reglas del fruto; lugar de los frutales | 1 | 2 | 3 |
| **Habitual** | **Ista** | Dictamina lo justo; valúa Luz y Piedras | Precios (multiplicador −5…+5, glosario §6) | 0–1 | 1 | 1 |
| **Habitual** | **Adoc** | Protectores; especialistas en armas | Otros adoc (`otros-adoc.md`) | 0–1 | 1–2 | 2–3 |
| **Habitual** | **Dumno** | Estudia el cuerpo y cura | Cura heridas graves (ADR 0010) | 0–1 | 1 | 1–2 |
| **Habitual** | **Rogoc** | Viajeros designados: piden ayuda, informan, comercian | Información de Bosques; trueque (metal) | 0–1 | 1 | 1–2 |
| **Habitual** | **Paruas** | Hacer funcional: utensilios | Armas (artesano) | 0–1 | 1 | 1–2 |
| **Especialización** | **Turos** | Sabios de los Humores; manipulan el clima a favor de la aldea | Avisa o aleja Humores (más adelante) | 0 | 0–1 | 0–1 |
| **Especialización** | **Jiulua** | En aldeas que recolectan agua | Solo en villas junto a agua | 0 | 0–1 | 0–1 |
| **Especialización** | **Underil** | Narrador; viaja con historias de los Nujio | Ambiente, historias | 0 | 0–1 | 1 |
| **Especialización** | **Ledai** | Buscadores de los Originales; en esta era, como profetas de Estrella Azul (dueño) | En villas con convicción garelina alta o convertidas | 0 | 0–1 | 0–1 |
| Fuera de las villas con Nujio | **Jelios** | Soldados de la era de los Nuevos Bosques | Grupos garelinos y villas convertidas | — | — | — |

- **Reglas de reparto**:
  1. Se colocan siempre los obligatorios.
  2. Después, los habituales hasta llenar el tamaño, cada uno con un 60% (pequeña), 85% (mediana) o 100% (grande).
  3. Al final, 1–2 especializaciones según el entorno de la villa (agua → Jiulua; Bosque con Humores frecuentes → Turos; convicción garelina → Ledai).

### Villa viva: rutinas, lugares y diálogos (más adelante; PR 1 de la 0.5)
- **Lugar de cada oficiante** (de día):
  - el Sfida, junto al Nujio;
  - el Pholua, entre los frutales;
  - el Sarua, en su taller al aire libre (glosario: "el resto de estructuras de la villa son al aire libre");
  - el Paruas, junto a su taller de utensilios;
  - el Ildo, en la plaza;
  - el Ista, cerca del Ildo;
  - el Dumno, en una casa con enfermos;
  - el Rogoc, a la entrada de la villa o de viaje (a veces no está);
  - los adoc, de misión o en la plaza.
- **Rutinas por Momento**:
  - **Gietos (día)**: trabajan en su sitio.
  - **Riutash**: se reúnen junto al Nujio. Glosario §5: el conocimiento del oficio se recibe en un riutash frente al Nujio.
  - **Riumna (noche)**: duermen en las **casas**, que son dormitorios. Glosario §5: casas de barro o piedra, sin puertas cerradas, ventanas pequeñas, sin propiedad privada, solo asignada. De noche solo se puede hablar con el Sfida (vela al Nujio).
- **Lugares para dormir**: el jugador duerme en la casa que le asignan en una villa (si lo aceptan) o en la plaza (refugio). Enlaza con dormir y Pensamiento (`bosques-y-relacion.md`).
- **Diálogos según el oficio**: cada oficio tiene una frase de ambiente por Momento y una por estado de su Bosque (sano, enojado…). Textos de `narrative-writer`, en pausa mientras la historia esté aparcada.
- Cada NPC es un sprite placeholder con color de oficio y un nombre tentativo (lista de `narrative-writer`, pendiente de aprobación del dueño).
- **Dependencia**: la colocación en el mapa (plaza, frutales, casas) depende del **Mundo 2.0** (0.4, otra sesión).

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
- **Trueque mínimo adelantado a la 0.5** (ajuste de playtest; confirmado por el dueño en #197, "Sí, adelante"; ADR 0017; `ajustes-playtest-0.5.md`, §5b). Dueño: "los item no tienen ningun valor real aun en la jugabilidad".
  - En "Servicio → Trueque", el Sarua cambia **ofrendas o Luz suelta** por máscaras y talismanes del catálogo actual (precios de 4 a 6), y el Paruas, por el **Cuchillo** (5) y la **Honda** (6).
  - Ofrecen 3 objetos por día, por seed, que se reponen en el riutash del amanecer.
  - Sin materiales ni mejoras: fabricar y mejorar siguen en la 0.6, igual que los favores del Sarua.
- **Fabricar** un objeto: cuesta Luz u ofrendas. **Mejorar**: +1 de nivel al objeto (máx. 3).

| Objeto (ranura) | Efecto base (propuesta) | Fabricar | Mejorar (+1) |
|---|---|---|---|
| Arma (mano principal) | +1 ATQ por nivel del arma (1–3) | 6 de Luz u ofrenda ≥ 6 | 8 / 10 |
| Máscara (cara) | Reduce el `vision_radius` de los Únicos un 25% por nivel (1–3) (`sigilo-y-robo.md`) | 8 | 10 / 12 |
| Talismán | Por tipo: +2 de Luz máx., +3 PV máx. o −1 al peaje (mín. 1) | 6 | 8 / 10 |

- **Coste: Luz u ofrendas + materiales** (dueño, #159: "usan materiales, si su bosque esta ya decrepito es posible que no tengan nada que ofrecer o te pediran que lo consigas para que te hagan el artefacto").
- **Artesanos de un Bosque decrépito** (estado muerto o corrupto, `bosques-y-relacion.md`): no tienen materiales propios. O no ofrecen nada, o **te piden que traigas el material** y luego fabrican (pagando solo la Luz u ofrenda).
- En un Bosque sano, el artesano pone sus propios materiales en la fabricación básica. Para las **mejoras** siempre hay que traerlos.

### Materiales
Lista del dueño (#164): "Los artesanos normalmente trabjan con madera, piedras, fibras vegetales, obsidianas y algunos metales blandos que se llamaran simplemente metal." Sustituye a la lista anterior: el barro sale y entra la obsidiana. Dónde se consigue cada uno es propuesta.

| Material | De dónde sale (propuesta) | Regla | Base |
|---|---|---|---|
| **Madera** | Árboles muertos de un Bosque (con E) | Solo **con permiso**: Bosque pagado o relación ≥ 30. Sin permiso es **robo** (hostilidad +1, relación −20, Senda −10) | Glosario §5: madera "solo de árboles muertos y con permiso" |
| **Piedra** | Junto a riscos y pendientes | Libre | Glosario §5: casas de piedra |
| **Fibra vegetal** | Maleza y plantas de los Bosques | Con permiso, igual que la madera | Lista del dueño |
| **Obsidiana** | **Zonas rocosas y montañosas**: chunks con riscos en las subregiones agrestes del norte del Valle del Sara (Lean, Causie, Tossie, Alss) y en Vastie (muy montañosa). 1–2 vetas por chunk montañoso | Libre; las vetas se agotan hasta el riutash | Lista del dueño; relieve de `docs/design/world/sur-lenfi.md` |
| **Metal** (metales blandos) | **Raro**: 1 veta en algunos chunks de montaña (1 de cada 4), o por **trueque con un Rogoc** (glosario §5: comercian) por 3 de Luz | Libre; la veta se agota hasta el riutash | Lista del dueño |
| **Metal de Gietos** | **Solo robándoselo a un errante** (dueño: "no se puede conseguir a menos que le robes a un errante") | Robo grave (abajo) | Glosario §3: es la única posesión de los errantes |

- **Robar el metal de Gietos a un errante** (propuesta; los errantes aún no están en el juego):
  - Los errantes son lenfi vinculados al Nujio, uno por Bosque, que advierten o guían a los viajeros (glosario §3).
  - Robarles es el robo más grave: relación −40 y hostilidad +2 con su Bosque, Senda −20 y cordura del Bosque −10.
  - En la 0.3 (sigilo), despierta a los Ofomni perseguidores.
  - No se mata al errante (ADR 0004).
- **Restos de Únicos: no.** Según el glosario, vuelven a la Luz del Bosque.

| Recetas (provisional) | Fabricar | Mejorar (+1 nivel, máx. 3) |
|---|---|---|
| Arma (Paruas) | 6 de Luz + 2 madera + 1 metal | +1 metal + 1 obsidiana (nivel 3: +2 metal + 1 obsidiana) |
| Arma de metal de Gietos (Paruas, especial) | Un arma de nivel 3 + 1 metal de Gietos | +1 ATQ extra sobre el nivel 3 (solo por robo; encaja con la rama Sombra) |
| Máscara (Sarua) | 8 de Luz + 2 madera + 2 fibra | +2 fibra + 1 obsidiana |
| Talismán (Sarua) | 6 de Luz + 1 piedra + 1 fibra | +1 obsidiana + 1 piedra |

- Cada material ocupa una casilla del inventario, apilable hasta 10 (propuesta, compatible con la bolsa de 12 casillas).
- Precios × multiplicador del Ista de la villa, si lo hay (−5…+5 → ×0,5…×1,5).

### Villas y bandos (0.5 "Dos caminos", `dos-caminos.md`)
- Cada villa (menos la natal) tiene un medidor de **convicción** garelina (0–100) y **1 necesidad** generada por seed: comida escasa, un Único que la acosa, un incendio en su Bosque, enfermedad o falta de un material o servicio.
- El **Ildo** y el **Ista** son con quienes se habla para persuadir (garelino) o contrapersuadir (fiel), con argumentos.
- **Villa convertida**: acepta **Piedras de los Nuevos Bosques** como moneda, además de la Luz. Da 1 miembro de grupo garelino, una vez.
- **Adoc garelino**: la villa natal le niega servicios y curación. Las demás villas lo atienden según su convicción (con < 30, desconfían: precios ×1,5).

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
- ~~¿Hay materiales?~~ Resuelta (#159, #164): madera, piedra, fibra vegetal, obsidiana y metal. El metal de Gietos solo se consigue robando a un errante. Dónde salen la obsidiana y el metal, y las recetas, son propuesta.
- ¿Cuándo entran los errantes en el juego (necesarios para el metal de Gietos)? (#166)
- Efectos de la villa dañada en los servicios (#124).
