# Ficha: Ajustes de playtest de la 0.5 (huida, colarse, fruto, armas, objetos e IA)

> Dueño: `game-designer`. **Versión 0.5**, bloque **P** de `roadmap-0.5.md`. Valores **provisionales**, todos en datos (`data/combat/balance.json`, `data/items/items.json`).
> Sale del playtest del dueño con el combate táctico activado (`tactical.enabled = true`). **Confirmada por el dueño** (#191–#195 y #197) y registrada en el **ADR 0017**. Sustituye a #184 ("Cualquier borde, seguro") y a "sin máscara no se puede colarse". Siguen abiertas #190 (permiso del fruto en un Bosque forzado) y #196 (consumibles).
> Fichas afectadas, con una nota que apunta aquí: `combate-tactico.md`, `ia-de-combate.md`, `sigilo-y-robo.md`, `bosques-y-relacion.md`, `cruce-y-combate-v2.md`, `monstruos.md` y `npcs-y-villas.md`.

## Palabras del dueño (playtest, textual)
> "es muy facil huir de los combates. Deberia ser más complicado quizas a la suerte.
> comer un fruto en otro bosque aun lo reconoce como segundo fruto y manda ofomni. No permite ingresar a los bosques libremente sin enfrentamiento. debería poderse entrar como sneaking pero los botarramas u otros unicos si te ven te pillan. Si estas muy bien equipado no deberían notarte a menos que pases por su lado.
> Las armas no afectan el combate
> los item no tienen ningun valor real aun en la jugabilidad
> la ia de los enemigos es muy basica."

## Diagnóstico (código de `main`)
| Punto | Qué pasa hoy | Por qué se siente mal |
|---|---|---|
| Huir | Táctico: desde cualquier borde, siempre (#184); el borde queda a 3 casillas o menos en el 8 × 6 y la IA no corta el paso. Menú: `flee_chance` 0,75. Exploración: correr (Shift) va a 200 px/s, más que cualquier Único, y tras huir el monstruo queda calmado 3 s | Huir no cuesta nada |
| Fruto | El contador va por Bosque, como debe. Pero en un Bosque **forzado** (lo normal tras vencer al Botarramas) o **colado** no hay permiso, así que el primer fruto ya es robo y manda a los Ofomni. El aviso no explica por qué, y la descripción de `items.json` dice que solo se come en su Bosque, que ya no es así | El dueño lo vivió como "segundo fruto" |
| Colarse | Umbral fijo: visión del Botarramas − camuflaje ≤ 1, sin arma y sin nadie que te persiga. Si no se cumple, tocar el borde abre el menú esté donde esté el Botarramas. Con hostilidad 0 hace falta camuflaje 9 o más, y al empezar no llevas nada equipado | No se puede "entrar como sneaking" |
| Armas | La lanza suma +2 ATQ, pero es la única arma, empieza sin equipar, llevarla cierra los Bosques y anula el camuflaje, y la escena táctica no lo muestra | No se nota |
| Objetos | Las ofrendas pagan peajes; el fruto cura un 25% fuera del combate; las máscaras y los talismanes vienen todos en la bolsa de prueba. No hay comercio ni objetos de combate | Nada se gana ni se gasta |
| IA | Botarramas, Ofomni y Aledra: agresivo; descarriado: berserk; reparep: enjambre. Nadie Defiende ni Espera, nadie corta la huida, todo es determinista y nadie usa la altura | Predecible y plana |

## Pilares
- **Pilar 1 (dos capas)**: las ofrendas que ganas en el mundo compran máscaras en la villa, y esas máscaras cambian cómo cruzas (puntos 3 y 5).
- **Pilar 3 (legibilidad 8-bit)**: un porcentaje de huida visible, un icono de permiso del fruto, la lanza enfundada o en la mano: cada estado, un sprite y una línea.
- **Pilar 4**: la IA con azar controlado y el sigilo según la distancia real hacen que cada cruce y cada pelea salgan distintos.

## Presión de supervivencia
- **Añade**:
  - huir es una tirada, y fallarla cuesta el turno;
  - los Únicos cortan el paso al borde y esprintan en distancias cortas;
  - pasar junto a un vigía siempre te delata.
- **Alivia**:
  - con buen equipo se cruza sin pagar ni pelear;
  - el fruto cura en combate;
  - la lanza deja golpear a 2 casillas;
  - empiezas con una máscara puesta;
  - las ofrendas compran equipo.

---

## 1. Huida con suerte (táctico, mundo y menú)

### 1a. Táctico
- **Dónde**: igual que ahora, desde una casilla del **borde**. Huye todo el bando.
- **Cuándo**: es una **acción**. Se puede mover primero y luego intentar huir.
- **Probabilidad** (se muestra en el menú antes de confirmar: "Huir (45%)"):

```
P = base + agi_factor × (AGI_tuya − AGI_max_cercanos)
      − adjacent_penalty × (enemigos adyacentes)
      − near_penalty × (enemigos cercanos no adyacentes)
      + retry_bonus × (intentos fallidos en este combate)
P = clamp(P, min, max). Sin enemigos cercanos: P = max.
```

  - **Adyacente**: enemigo en pie a 1 casilla ortogonal.
  - **Cercano**: enemigo en pie con distancia Manhattan ≤ su Mov + 1, es decir, que te alcanzaría en su siguiente turno.
  - **AGI_max_cercanos**: la AGI más alta de entre los adyacentes y los cercanos.
  - Estado **Miedo** (Iserald, `monstruos.md`): + `fear_bonus`.

| Clave (`tactical.flee`) | Valor |
|---|---|
| `base` | 70 |
| `agi_factor` | 5 (por punto de AGI) |
| `adjacent_penalty` | 35 (por enemigo) |
| `near_penalty` | 10 (por enemigo) |
| `retry_bonus` | 10 (por intento fallido) |
| `min` / `max` | 5 / 95 |
| `fear_bonus` | 20 |

- **Si falla**: "No logras escapar". El turno **termina**. El intento cuenta como actuar, así que el CT baja 100 si te moviste antes y 80 si no. El enemigo **no** recupera PV.
- **Si sale bien**: como hoy, el enemigo recupera sus PV y vuelves al mundo (ver 1b).

**Ejemplos** (Adoc de nivel 1, AGI 5):

| Situación | P |
|---|---|
| Botarramas (AGI 3) lejos, a más de 3 casillas | 95% |
| Botarramas a 2–3 casillas | 70 + 10 − 10 = **70%** |
| Botarramas adyacente | 70 + 10 − 35 = **45%** |
| Ofomni (AGI 6) adyacente | 70 − 5 − 35 = **30%** |
| Aledra (AGI 5) adyacente, de noche | **35%**. Contra un fatal, el aviso previo sigue dejando huir **sin coste antes** del combate |
| 3 reparep (AGI 7): 2 adyacentes y 1 cercano | 70 − 10 − 70 − 10 → **5%**: rodeado, no se huye |
| El mismo Ofomni, tras 2 intentos fallidos | 30 + 20 = **50%** |

- **Regla de oro**: alejarse primero de los enemigos y luego huir funciona. Huir pegado a ellos es casi imposible.

### 1b. Mundo (exploración)
- **Calma tras una huida con éxito**: el monstruo queda calmado `flee_cooldown` = **1,5 s** (antes 3 s). El "Retroceder" del menú del borde sigue con 3 s: es una decisión pacífica y debe ser segura.
- **Sprint de los Únicos** (carrera corta). Cuando un Único persigue y está a `sprint_trigger` casillas o menos, corre a `sprint_px` durante `sprint_seconds`. Luego no puede volver a esprintar en `sprint_cooldown` s.
  - El jugador anda a 100 px/s y corre (Shift) a 200 px/s.
  - El **Botarramas no esprinta**: renquea (`monstruos.md`). Guarda el borde, no persigue.

| Monstruo | `sprint_trigger` (casillas) | `sprint_px` | `sprint_seconds` | `sprint_cooldown` |
|---|---|---|---|---|
| Botarramas | — | — | — | — |
| Ofomni (los dos) | 4 | 240 | 1,5 | 4,0 |
| Aledra | 3 | 250 | 1,0 | 5,0 |
| Reparep | 3 | 220 | 1,0 | 4,0 |

  - **Comprobación (Ofomni contra un jugador que corre)**: en 1,5 s gana 60 px, unas 3,75 casillas. Con `engage_px` = 26, si te ve a 4 casillas (64 px) te alcanza, y a 6 casillas escapas por poco.
  - Si vas andando te alcanza siempre que te vea a 4 casillas o menos.
  - El **talismán de pluma** (+30%) sube la carrera a 260 px/s: escapas de cualquier sprint. Así tiene un uso claro.
- **Correr delata**: mientras corres, tu camuflaje **no cuenta** (como con el arma en la mano). Tienes que elegir entre ir oculto andando o escapar corriendo, y se lee con el icono de máscara en rojo.

### 1c. Combate por menú (mientras siga siendo el de por defecto)
- `flee_chance`: 0,75 → **0,6**. Si falla, pierdes el turno (como ahora).
- La escena antigua se retira en T8. Hasta entonces, este es el único cambio.

### Casos límite
- **Huir con aliados en el tablero**: la tirada es la del Adoc y huye todo el bando.
- **Emboscada del enemigo**: empiezas de espaldas y con los enemigos con CT 100. Lo normal es que te alcancen antes de llegar al borde.
- **Tablero grande (14 × 10)**: el borde queda más lejos, pero también hay más espacio para alejarse y huir al 95%.
- **Bucle de huidas**: tras una huida, el monstruo tarda 1,5 s y luego te persigue con sprint. Si vuelve a alcanzarte, es otro combate y otra tirada. Ganar la tirada da la huida, pero no la regala dos veces.

---

## 2. Fruto: que se entienda el permiso

La **regla no cambia** (`bosques-y-relacion.md`, "Fruto"). Cambian la información y un texto.

- **Estado de permiso** (función pura, `FruitRules.permission_state(bosque_id, home)`):

| Estado | Cuándo | Icono en el HUD (junto a la máscara y la lanza) |
|---|---|---|
| `granted` | Natal, pagado, salvoconducto o Bosque que no cobra (muerto, necesita ayuda), y sin fruto tomado en este Momento | Fruto **verde** |
| `used` | Con permiso, pero ya tomaste el de este Momento | Fruto **gris** |
| `forced` | Forzado: venciste a un Botarramas sin pagar | Fruto **rojo** |
| `sneaked` | Colado | Fruto **rojo** |
| `closed` | Cerrado | Fruto **rojo** |

  - Al entrar en un Bosque sin permiso, el aviso de entrada (`_entry_notices`) añade una línea:
    - forzado: "Este Bosque no te ha dado permiso: su fruto no es tuyo.";
    - colado: "Te has colado: su fruto no es tuyo.".
  - El aviso sale **una vez por entrada**.
- **Confirmación al tomarlo** (ya existe "Tomarlo igualmente / Dejarlo"). Se mantiene, con tres cambios:
  - El **título** dice el motivo: "Este Bosque no te ha dado permiso: tomarlo es robar." más una segunda línea según el estado:
    - "Vencer a su Botarramas no da permiso.";
    - "Te has colado.";
    - "Ya tomaste el fruto de este Momento.".
  - La opción pasa a llamarse **"Robarlo"**, que dice lo que es.
  - El cursor empieza en **"Dejarlo"**.
- **Comer un fruto guardado no cuenta como tomar** (`FruitRules.eat_from_bag` no toca `fruit_taken`). Hay que **reproducir** el caso del dueño ("comer un fruto en otro bosque aun lo reconoce como segundo fruto"):
  1. Toma y guarda un fruto en un Bosque pagado.
  2. Cruza a otro Bosque pagado y cómete el guardado.
  3. Toma un fruto de ese Bosque: no debe ser robo.
  4. Repite en un Bosque forzado: debe ser robo, con el motivo a la vista.
  - Si en el paso 3 sale robo, es un bug (`qa-tester`, `rpg-systems-dev`).
- **Descripción en `items.json`** (texto propuesto para `narrative-writer`; sustituye la actual, que está desfasada): "Cura un cuarto de tus PV. Tómalo solo con permiso del Bosque (el natal o uno pagado), uno por Momento. Puedes comerlo en cualquier sitio, pero su Bosque nota que te lo llevas."
- **Pregunta al dueño (#190)**: ¿forzar un Bosque venciendo al Botarramas debería dar algún permiso? La regla no cambia mientras no responda.

---

## 3. Colarse de verdad

**Idea**: el borde cerrado se cruza **sin menú** si en ese momento **nadie te ve**. Lo que importa es la distancia real a cada vigía, no un umbral fijo.

### Regla
- **Detección** (función pura `Stealth.detects(dist, vision, camo) -> bool`; distancia Chebyshev en casillas):

```
te ve  ⇔  dist ≤ close_detect                        (pasar a su lado: siempre)
       o  dist ≤ visión_efectiva
visión_efectiva = max(0, visión − camuflaje)          con máscara o talismán que oculte (camuflaje del equipo > 0)
                = visión × unmasked_vision_factor    sin nada que oculte, o corriendo
camuflaje = el del equipo − sheathed_camo_penalty del arma enfundada (mínimo 0)
visión = vision_radius del monstruo + hostilidad y estado del Bosque (como hoy) − Paso quedo
```

- **Vigías**: los Botarramas del Bosque al que entras y los Únicos de ese Bosque que estén en el mundo cargado: los que rondan, los cazadores y los Ofomni perseguidores.
- **Al tocar el borde cerrado**:
  1. **Nadie te ve**: cruzas en silencio. El Bosque queda **colado** (como hoy: sin cazadores mientras nadie te vea, sin permiso de fruto) y se gasta un uso de la máscara de ceniza.
  2. **Te ve un Botarramas**: no cruzas. Se abre el **menú del borde** (pagar, ofrenda, Enfrentar a ese Botarramas, Retroceder).
  3. **Te ve otro Único** del Bosque: no cruzas. Ese Único te persigue y el encuentro es el suyo (combate o, con Aledra de noche, su aviso). No hay menú del borde.
  4. **Ya te persigue alguien**: el borde no se cruza (como hoy).
- **Hablar en vez de colarse**: con **E** mirando a un Botarramas o a la frontera cerrada, se abre el menú del borde aunque nadie te vea. Pagar es siempre una opción tuya, nunca algo forzado.
- **Dentro del Bosque**: la misma regla `detects` decide si un Único te ha visto (`AdventureRules.spotted`). `close_detect` sustituye al "te encuentra de cerca a su `engage_distance`".

| Clave (`stealth`) | Valor | Sustituye a |
|---|---|---|
| `close_detect` | 2 | La detección a `engage_distance` |
| `unmasked_vision_factor` | 2,0 | "Sin máscara no se puede colarse" |
| `run_breaks_camouflage` | true | — (nuevo, punto 1b) |
| `sneak_max_vision` | **se retira** | El umbral fijo |
| `hidden_vision` | 2 (sin cambios; solo para los cazadores del Bosque enojado) | — |

### Qué significa en el juego (Botarramas, visión base 10)
| Equipo | Hostilidad 0 | Hostilidad 2 (visión 14) | Lectura |
|---|---|---|---|
| Nada (lanza enfundada o en la bolsa) | Te ve a **20** casillas | A 28 | Posible, pero hay que cruzar lejos del puesto, por la esquina del tramo y fuera del camino. "Más difícil", como pidió el dueño |
| Máscara de corteza (6) con la lanza enfundada (−2) | A 6 | A 10 | Hay que rodear |
| Corteza (6) | A 4 | A 8 | — |
| Corteza + semillas (9) | Solo a su lado (2) | A 5 | "Si estás muy bien equipado no deberían notarte a menos que pases por su lado" |
| Ceniza + semillas (14) | Solo a su lado (2) | Solo a su lado (2) | Para Bosques hostiles o enojados (+4) |
| Lanza **en la mano** | **No se puede colarse**: el Bosque siente tu arma y el menú del borde solo ofrece Enfrentar o Retroceder (como hoy) | — | — |

- Un tramo de frontera mide 64 casillas y su Botarramas está junto al camino, con un renqueo de 3. Así, sin máscara, cruzar a más de 20 casillas exige apartarse del camino.
- **Orientación (opcional, después de M17a)**: un Único que te da la espalda ve a la mitad. Es la única regla de esta ficha que necesita la orientación del monstruo en el mundo nuevo; si complica el M17a, se deja fuera.

### Casos límite
- **Dos Bosques en la esquina de un chunk**: solo cuentan los vigías del Bosque al que entras.
- **El Botarramas te ve justo mientras cruzas**: se mira en el instante de tocar el borde, así que el menú gana.
- **Colado y te ven dentro**: como hoy (`spotted`): se rompe el camuflaje 20 s y el Bosque empieza a cazarte.
- **Bosque enojado**: su visión +4 hace que solo el mejor equipo pase.
- **Correr hasta el borde**: llegas sin camuflaje (punto 1b) y te ve quien esté a `visión × 2`. Para colarse, se anda.

---

## 4. Armas que importan (mínimo para la 0.5)

### 4a. Enfundada o en la mano
- El dueño (2026-10-24): "Las armas deberían poder estar o equipadas o desequipadas de la mano principal". Se interpreta así: **enfundada = desequipada de la mano principal**, sin quitarla de la ranura.
- Dueño (#193): "Sí, y sicabi prohíbe aun enfundada".
- **Tecla `Q`** (acción nueva `toggle_weapon`; mando: botón X). La `R` ya es `new_seed`. La asignación concreta la confirma `engine-architect`.
- Cambiar es gratis fuera de combate y no se puede mientras empieza un encuentro.
- **Sicabis** (0.6, `lugares-e-interiores.md`): no se entra con un arma **equipada**, ni en la mano ni enfundada. Hay que dejarla en la bolsa.

| Estado | En el mundo | En combate |
|---|---|---|
| **En la mano** (`weapon_drawn = true`) | Como el "armado" de hoy: camuflaje 0; ningún Bosque (salvo el natal y los que no cobran) te deja pasar en paz; aviso "El Bosque siente tu arma." | ATQ y alcance del arma |
| **Enfundada** | No cierra Bosques. El camuflaje funciona con −`sheathed_camo_penalty` (por arma; lanza 2) | Se desenfunda sola al empezar, salvo en una **emboscada del enemigo**: entonces desenfundar es tu acción del primer turno ("Desenfundar"). Antes de desenfundar, peleas con el ATQ base |
| **En la bolsa** (sin equipar) | Sin efecto | Sin arma |

- `AdventureRules.is_armed()` pasa a significar **en la mano**. Se añade `AdventureRules.has_weapon()` (equipada, en la mano o enfundada).
- Al terminar el combate, el arma vuelve al estado en que estaba.
- El sprite lleva la lanza a la espalda o en la mano (`pixel-artist`).

### 4b. La lanza en el táctico
- **Alcance 2 en línea**: ataca a una casilla ortogonal a 1 o a 2 de distancia.
  - A 2, la casilla de en medio debe ser transitable.
  - Si la casilla de en medio tiene un enemigo, el golpe va a ese.
  - Altura: el desnivel con el objetivo debe ser ≤ Salto (como el cuerpo a cuerpo).
- A 2 casillas se aplican la orientación y la altura del objetivo como siempre.
- Datos en `items.json`: `"range": [1, 2]`, `"line": true`.
- **Por qué alcance y no atravesar**: se explica con una línea ("golpea a 2"), se usa contra el Botarramas (Mov 2) y contra el Ofomni (que también llega a 2, punto 6), y casa con huir: golpear y alejarse.

### 4c. Mostrar el arma
Requisitos para `ui-ux-dev` en la escena táctica:
- en la ficha del combatiente activo: "ATQ 8 (Lanza +2)" o "ATQ 6 (sin arma)";
- un icono del arma;
- en el rango de ataque resaltado, las casillas a 2 de la lanza.

### 4d. Dos armas más (dueño, #194: "Sí, con esos nombres")
| id | Nombre | `atk_bonus` | Alcance | Efecto propio | `sheathed_camo_penalty` | De dónde sale |
|---|---|---|---|---|---|---|
| `cuchillo` | Cuchillo | +1 | 1 | Espalda: +2 de daño extra (+4 en total). Encaja con la rama Sombra | 0: no estorba al sigilo | Hallazgo en refugios (1 de cada 4 hallazgos, `refuge_loot`) y trueque con un Paruas (punto 5) |
| `honda` | Honda | +1 | 2–3, sin línea (por encima de obstáculos y combatientes) | No ataca a 1 casilla; precisión −10 | 1 | Recompensa, una vez, al vencer junto a otro adoc (`otros_adoc`), si no la tienes; trueque con un Paruas |

- **Lanza** (+2, alcance 1–2, −2 enfundada): la de siempre, la más fuerte en el ataque directo.
- **Cuchillo**: para el sigilo y la emboscada.
- **Honda**: para pelear de lejos contra los lentos, con menos daño.
- La honda solo alcanza a 3, y en el 8 × 6 el espacio para alejarse se acaba enseguida.
- Nombres confirmados: **Cuchillo** y **Honda**. Las descripciones son de `narrative-writer`.

---

## 5. Objetos con valor en la 0.5

### 5a. Acción "Objeto" en el táctico
- **Acción** (cuenta como actuar). Abre la bolsa con lo que se puede usar en combate (`"combat_use": true`).
- **Fruto**:
  - cura el 25% de los PV máximos del objetivo;
  - el objetivo es el Adoc o un aliado adyacente (`"use_range": 1`);
  - aplica la regla de siempre: comerlo lejos de su Bosque baja la relación con él (−5).
- **Consumibles nuevos**: necesitan lore (¿qué remedio lleva un adoc?). Van como pregunta (#196) con una propuesta mecánica: "remedio del Dumno, cura el 40%, 1 por día". En la 0.5 solo entra el fruto.

### 5b. Trueque mínimo en la villa (adelantado de la 0.6; dueño, #197: "Sí, adelante")
- **Sarua** (obligatorio en todas las villas; hace máscaras y talismanes, #154): opción **"Servicio → Trueque"**.
  - Das una **ofrenda** de valor ≥ el precio, o **Luz suelta**, o las dos combinadas (como en el peaje).
  - Recibes un objeto de sigilo.
  - Sin materiales: los materiales y las mejoras siguen en la 0.6.
- **Paruas** (habitual, puede no estar): lo mismo con las armas del punto 4d.

| Objeto | Precio (Luz u ofrenda) | Quién |
|---|---|---|
| Talismán de semillas (camuflaje 3) | 4 | Sarua |
| Máscara de corteza (6) | 4 | Sarua |
| Máscara de musgo (8, DEF −2) | 5 | Sarua |
| Máscara de ceniza (11, 3 cruces) | 6 | Sarua |
| Talismán de pluma (+30% de paso) | 6 | Sarua |
| Cuchillo | 5 | Paruas |
| Honda | 6 | Paruas |

- **Existencias**: cada artesano ofrece **3 objetos** de su lista, por seed de la villa y del día. Se reponen en el riutash del amanecer, y cada objeto se compra 1 vez por día.
- La **máscara de ceniza** es el sumidero que se repite: se rompe y hay que volver a por otra.
- **No vende ni compra ofrendas.** Las ofrendas siguen siendo moneda de peaje y de trueque.
- Precios × multiplicador del Ista de la villa, si lo hay (`npcs-y-villas.md`).
- **Economía de la ofrenda** (las reglas del rol piden fuente, sumidero y qué pasa si se agota):
  - **Fuente**: refugios (1 de cada 3), Botín (Sombra), misiones lejanas, ayudar a otros adoc.
  - **Sumideros**: peaje, Ofrenda, dejarlas al Nujio y, ahora, el trueque.
  - **Si se agotan**: se paga con Luz suelta (máximo 10) o se pelea.
- **Dependencia**: el Sarua como NPC con E llega con el PR 1 de la 0.5 (villas vivas). Si P5 llega antes, el trueque sale en el diálogo de la plaza de la villa (hub) con el nombre del Sarua.
- **El favor del Sarua** sigue en la 0.6.

### 5c. Equipo inicial
| Ranura o bolsa | Antes | Ahora (#197) |
|---|---|---|
| Mano principal | vacía | **Lanza de adoc, enfundada** |
| Máscara | vacía | **Máscara de corteza** |
| Talismán | vacío | vacío |
| Bolsa | lanza y las 5 piezas de sigilo (prueba) | **Trenza votiva** (ofrenda de 4): da para un peaje pequeño o un talismán de semillas |

- **Con este equipo, al empezar**:
  - un Botarramas de hostilidad 0 te ve a 6 casillas (corteza 6 − 2 de la lanza enfundada);
  - si dejas la lanza en la bolsa, a 4.
  - El sigilo se nota desde el primer cruce, y lo demás se gana.
- Los objetos de prueba se pueden seguir dando con una opción de depuración (`dev-tooling`).

---

## 6. IA más lista (táctico)

### 6a. Perfiles (sobre el lore que ya existe en `monstruos.md`; dueño, #195: "Sí, encaja")
| Perfil | Quién | Base en `monstruos.md` | Conducta |
|---|---|---|---|
| **Guardián** (`guardian`, nuevo) | Botarramas | "restringen el paso"; "renquean" | Se queda a `guard_radius` = 2 casillas o menos de su casilla inicial, entre el Adoc y el borde de su lado. Ataca si llega. Si no llega, **Defiende** (como mucho 1 de cada `guard_defend_every` = 2 turnos). Si el Adoc no se acerca en `guard_advance_after` = 3 turnos suyos, avanza como un agresivo. **No corta la huida**: quiere que te vayas |
| **Látigo** (`whip`, nuevo) | Ofomni (apaciguable) | "ataca con látigos"; "ojo con tentáculos" | **Alcance 2 en línea** (como la lanza). Prefiere atacar desde 2 casillas y no quedarse adyacente. Prefiere casillas altas. Anuncia el Latigazo como ahora |
| **Berserk** | Ofomni descarriado | "berserk" | Como hoy (carga contra el más cercano, nunca huye ni Defiende), con **alcance 2** porque es el mismo ser. Sin azar |
| **Emboscadora** (`ambusher`, nuevo) | Aledra | Serpiente; ronda de noche; fatal de noche | Busca la **espalda o el flanco** (como el táctico). Si este turno solo llega de frente, **Espera** (CT −60) fuera de tu alcance para golpear antes y por detrás en el siguiente. Corta la huida |
| **Enjambre** | Reparep | "atacan en grupos" | Como hoy (rodean, ataque conjunto, el último huye), y además cortan la huida |
| **Táctico** | Garelinos | `ia-de-combate.md` | Como hoy, y además cortan la huida y Esperan (ver 6b) |

### 6b. Reglas comunes nuevas (salvo berserk)
- **Defender**: si este turno no puede atacar, un enemigo del Adoc puede alcanzarle en su siguiente turno y le queda menos del `defend_below` = 50% de PV, se mueve y Defiende en vez de solo moverse.
- **Esperar**: táctico y emboscadora. Si acercarse sin atacar le deja al alcance de 2 o más enemigos, Espera (CT −60).
- **Cortar la huida** (emboscadora, enjambre, táctico, látigo):
  - Se activa si el Adoc está en el borde o a `cut_flee_edge` = 1 casilla, y su probabilidad de huir pasa de `cut_flee_above` = 30%.
  - Entonces, entre las casillas desde las que puede atacarle, prefiere una **adyacente** a él, así que la penalización de 35 entra sola.
  - Si no puede atacar, se mueve a la casilla alcanzable más cercana a la casilla de borde más próxima al Adoc, para interponerse.
- **Altura** (cuando el tablero tenga relieve, T7a y M17a):
  - a igualdad de lo demás, se prefiere la casilla más alta: +`height_weight` = 1 de puntuación por nivel;
  - el látigo y la emboscadora puntúan doble;
  - en el tablero llano no hace nada.
- **Azar controlado** (top-2 ponderado):
  - dentro de la **misma prioridad** (elegir objetivo o elegir casilla), se toma la mejor opción con `top2_weight` = 75% y la segunda con 25%;
  - solo si la segunda puntúa al menos `top2_margin` = 80% de la mejor;
  - nunca se elige una acción de una prioridad más baja;
  - la tirada sale de la seed del combate, así que es reproducible en los tests;
  - el berserk no tira.

### Datos (`tactics.ai` y `monsters.*`)
| Clave | Valor |
|---|---|
| `tactics.ai.defend_below` | 0.5 |
| `tactics.ai.guard_radius` / `guard_defend_every` / `guard_advance_after` | 2 / 2 / 3 |
| `tactics.ai.cut_flee_edge` / `cut_flee_above` | 1 / 30 |
| `tactics.ai.height_weight` | 1 |
| `tactics.ai.top2_weight` / `top2_margin` | 0.75 / 0.8 |
| `monsters.botarramas.ai` | `guardian` |
| `monsters.ofomni.ai`, `attack_range` | `whip`, [1, 2] |
| `monsters.ofomni_descarriado.attack_range` | [1, 2] (ai sigue `berserk`) |
| `monsters.aledra.ai` | `ambusher` |

### Casos límite
- **Guardián contra un Adoc que no se acerca**: al tercer turno avanza, así que no hay bucle de Defender.
- **Látigo arrinconado** (sin casilla a 2): ataca a 1.
- **Corte de huida imposible** (el borde queda fuera de su Mov): se acerca como siempre.
- **Varios cortan a la vez**: cada uno toma una casilla adyacente distinta, y el resultado es el rodeo.

---

## Inputs / outputs
- **Inputs**: posiciones, AGI, Mov y orientación en el tablero; distancias reales a los vigías en el mundo; equipo (máscara, talismán, estado del arma); acceso del Bosque; bolsa y ofrendas; existencias del artesano.
- **Outputs**: resultado de la tirada de huida; cruce colado o menú del borde; icono de permiso del fruto; daño a 2 casillas; PV curados con Objeto; objetos comprados; planes de la IA.

## Interacción con otros sistemas
- `combate-tactico.md`: Huir, acción Objeto, alcance de las armas.
- `ia-de-combate.md`: perfiles nuevos y reglas comunes.
- `sigilo-y-robo.md`: colarse sin umbral, arma enfundada, correr delata.
- `bosques-y-relacion.md`: permiso del fruto (sin cambiar la regla).
- `cruce-y-combate-v2.md`: menú del borde solo si te ven o si hablas; `flee_chance` 0,6.
- `monstruos.md`: sprint, perfiles y alcance del Ofomni.
- `npcs-y-villas.md`: trueque mínimo del Sarua y del Paruas adelantado de la 0.6.
- Mundo 2.0 (M17a): el gancho del borde y el sprint tocan la exploración. Las reglas van en clases puras (`Stealth`, `FruitRules`, `AdventureRules`, `MonsterSteering`) y la exploración solo las llama.

## Criterios de éxito para playtest
1. **Huida**: en 5 combates, el dueño falla al menos 1 huida y al menos una vez se aleja antes de huir a propósito. A la pregunta "¿huir es demasiado fácil?" responde que no.
2. **Fruto**: el dueño explica sin ayuda por qué un fruto es robo en un Bosque forzado (pregunta: "¿por qué te persiguieron los Ofomni?").
3. **Colarse**: con corteza y semillas, se cuela al menos 1 vez sin menú y le pillan al menos 1 vez por pasar cerca. Responde que sí a "¿se puede entrar a escondidas?".
4. **Armas**: golpea al menos una vez a 2 casillas con la lanza y usa la tecla de enfundar antes de cruzar.
5. **Objetos**: compra al menos 1 objeto al Sarua en 30 minutos y usa el fruto en combate al menos una vez.
6. **IA**: ve a un Botarramas Defender y a un enemigo cortarle la huida. A la pregunta "¿la IA sigue siendo básica?" responde que no.

## Plan de PR
Ver el bloque **P** de `roadmap-0.5.md`.

## Preguntas abiertas
- **#190**: permiso del fruto en un Bosque forzado.
- **#196**: consumibles de combate (hace falta lore).
- ~~#191–#195 y #197~~: resueltas (ADR 0017).
