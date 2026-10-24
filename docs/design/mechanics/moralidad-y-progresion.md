# Ficha: Senda (moralidad), puntos de stats y skills

> Dueño: `game-designer`. **Versión 0.5 "Los otros adoc"** (antes numerada 0.4) (reparto confirmado por el dueño). Valores **provisionales**.
> Fuentes: palabras del dueño (abajo); `progresion-adoc.md` (tabla de niveles hasta la 0.3), `cruce-y-combate-v2.md` y ADR 0013 (hostilidad, relación), `bosques-y-relacion.md`, `monstruos.md` (fatales, Iserald), ADR 0004 (regla de no matar), `npcs-y-villas.md`, `otros-adoc.md`.

## Objetivo
Que el jugador elija cómo ser adoc y que esa elección se note en sus habilidades, en las villas y en los Bosques.

Palabras del dueño:
- Primera ronda: "poder ser un adoc malo y poderoso o uno que se apega a las reglas y avanza con calma. podemos incluir puntos de stats o skills."
- Respuestas (0.5, antes 0.4):
  - "vamos por 3 puntos para subir manual pero la vida, y otros stats si esta bien darle 1 o 2, decidelo."
  - "podria ser un icono o parte de la rama de skils que puede desbloquear el jugador. Es decir si comete muchas maldades se desbloquean algunos skils, caso cotrario otros. Quizas para malvados el tema de sigilo, poder, conseguir mas recursos y si eres bueno la confianza, facilidad para pedir favores, habilidades mas blandas."

## Pilares
- **Pilar 1 (dos capas)**: tu forma de actuar en el Bosque cambia cómo te reciben las villas y qué puedes aprender.
- **Pilar 2**: cada nivel da una elección visible (3 puntos de stat y, en los pares, 1 de skill).
- **Pilar 4**: dos partidas pueden jugarse de formas opuestas.

## Presión de supervivencia
- **Senda violenta**: poder y recursos rápidos (rama Sombra), pero Bosques hostiles, villas que desconfían, adoc que no quieren trabajar contigo y riesgo de **Iserald** si dañas un Bosque (`monstruos.md`).
- **Senda respetuosa**: más lenta, pero con confianza, favores fáciles y ayuda (rama Confianza).

## Senda
- Valor interno por partida, de **−100 (violenta)** a **+100 (respetuosa)**. Empieza en **0**. Se guarda con la partida y se reinicia con un game over o una partida nueva.
- **Cómo se ve** (dueño: "podria ser un icono o parte de la rama de skils"):
  - No hay número ni barra.
  - Hay un **icono de Senda** con tres estados: **violenta** (≤ −30), **neutral** (−29 … +29) y **respetuosa** (≥ +30). Aparece en la pantalla de estado y en el árbol de skills.
  - En el árbol, las skills que se van desbloqueando muestran hacia dónde va el jugador.
- La Senda mide el trato con **los Bosques y sus Únicos**. La regla de no matar gente (ADR 0004) vale en cualquier Senda.

### Qué la mueve
| Acción | Cambio |
|---|---|
| Vencer a un Botarramas (Bosque forzado) | −3 |
| Robar (fruto extra, fruto de un Bosque no pagado, objetos) | −10 |
| Sacar un fruto guardado de su Bosque | −1 |
| Dañar un Bosque (más adelante: talar, quemar) | −15 |
| Pagar el peaje con Luz | +1 |
| Pagar con ofrenda | +2 |
| Dejar una ofrenda voluntaria junto a un Nujio | +1 |
| Completar un favor de Sarua sin violencia | +3 |
| Ayudar a otro adoc en combate | +2 |
| Salvar un Bosque (incendio, ataque) | +5 |

Vencer al Ofomni descarriado de una misión no mueve la Senda.

### Efectos de la Senda (además de las skills)
| Icono | Efectos |
|---|---|
| **violenta** (≤ −30) | Villas: precios ×1,25 (×1,5 con ≤ −60); los Sarua solo dan favores de "llevar algo". Con ≤ −60, los Bosques que visitas por primera vez empiezan con hostilidad 1. |
| **neutral** | Sin efectos. |
| **respetuosa** (≥ +30) | Ganancias de relación +50%; villas: precios ×0,85. Con ≥ +60: peaje −1 en todos los Bosques (mín. 1). |

- Afinidad con los otros adoc: ver `otros-adoc.md`.

## Puntos de stats al subir de nivel
Decisión del coordinador (delegada por el dueño), con un ajuste de `game-designer` en el coste de los puntos para no romper el balance (ver "Comprobación").

### Automático por nivel (desde el nivel 2)
- **+3 PV máx.**
- **+1 ATQ** en los niveles impares (3, 5, 7, 9) y **+1 DEF** en los pares (2, 4, 6, 8, 10).

### 3 puntos de stat por nivel, a mano
| Gasto | Coste | Efecto |
|---|---|---|
| ATQ | **3 puntos** | +1 ATQ |
| DEF | **3 puntos** | +1 DEF |
| Vigor | 1 punto | +2 PV máx. |
| Luz | 1 punto | +1 al límite de Luz suelta (`luz_max`) |

- Con 3 puntos por nivel se compra **+1 ATQ** o **+1 DEF**, o se reparten en **Vigor y Luz** (por ejemplo, +4 PV y +1 de Luz).
- **Ajuste respecto a la propuesta del coordinador** (1 punto = +1 ATQ, +1 DEF, +4 PV o +2 de Luz): con eso, todo a ATQ en nivel 3 daba ATQ 13 y el Ofomni caía en 3 turnos (trivial). Con ATQ y DEF a 3 puntos se mantienen 3 puntos por nivel y se conserva la dificultad.
- **Los puntos no gastados** se guardan para el nivel siguiente.

### Tabla de niveles
| Nivel | XP acumulada | Auto: PV / ATQ / DEF | Build **equilibrado** (compra ATQ en pares y DEF en impares) | Tabla anterior (≤ 0.3) |
|---|---|---|---|---|
| 1 | 0 | 30 / 6 / 3 | 30 / 6 / 3 | 30 / 6 / 3 |
| 2 | 10 | 33 / 6 / 4 | 33 / 7 / 4 | 34 / 7 / 3 |
| 3 | 25 | 36 / 7 / 4 | 36 / 8 / 5 | 38 / 7 / 4 |
| 4 | 45 | 39 / 7 / 5 | 39 / 9 / 6 | 42 / 8 / 4 |
| 5 | 70 | 42 / 8 / 5 | 42 / 10 / 7 | 46 / 9 / 4 |
| 6 | 100 | 45 / 8 / 6 | 45 / 11 / 8 | 50 / 9 / 5 |
| 7 | 140 | 48 / 9 / 6 | 48 / 12 / 9 | 54 / 10 / 5 |
| 8 | 190 | 51 / 9 / 7 | 51 / 13 / 10 | 58 / 11 / 5 |
| 9 | 250 | 54 / 10 / 7 | 54 / 14 / 11 | 62 / 11 / 6 |
| 10 | 320 | 57 / 10 / 8 | 57 / 15 / 12 | 66 / 12 / 6 |

La XP por nivel no cambia.

### Comprobación contra el Ofomni descarriado (d = 4, ATQ 8, DEF 3, Latigazo múltiple ×3 cada 3 ataques; solo atacar; daño medio recibido)
Builds de nivel 3 (2 subidas = 6 puntos):

| Build nivel 3 | PV / ATQ / DEF | Ofomni PV ×0,7 (24) | **PV ×0,85 (29)** | PV ×1,0 (34) |
|---|---|---|---|---|
| Todo a ATQ | 36 / 9 / 4 | gana fácil (~23 de 36) | gana (~27 de 36) | gana (~32 de 36) |
| Equilibrado | 36 / 8 / 5 | gana fácil (~21) | gana (~25) | justo (~35) |
| Todo a DEF | 36 / 7 / 6 | gana fácil (~18) | gana (~25) | gana (~28) |
| Todo a Vigor | 48 / 7 / 4 | gana (~32 de 48) | justo (~45 de 48) | pierde (~50) |
| Todo a Luz | 36 / 7 / 4 | gana justo (~32) | pierde (~45) | pierde |

- Con la progresión nueva, el **×0,7** de la 0.3 hace el Ofomni demasiado fácil para casi todos los builds.
- **Recomendación: subir el Ofomni a PV ×0,85** (d = 4: 29 PV). Así gana cualquier build de combate (ATQ, DEF, equilibrado, Vigor por poco) perdiendo del 70% al 95% de los PV. Todo a ATQ no es trivial (~27 de 36), y un build solo de Luz pierde, como es lógico.
- **Nivel 2** (33/7/4 o 33/6/5) sigue perdiendo contra el Ofomni ×0,85 (~45 y ~42 de 33). El "ganable desde nivel 3" se mantiene.
- **Riesgo a largo plazo**: el build equilibrado llega a DEF 12 en nivel 10, por encima del ATQ máximo de un Único (10 con `d_max` = 6). Habrá que ampliar los enemigos de nivel alto (d mayor, Iserald, garelinos) o poner un tope a la DEF comprada (#161).

## Skills por Senda
- **1 punto de skill en los niveles 2, 4, 6, 8 y 10** (5 en total, como antes).
- Las skills se **desbloquean por Senda** (dueño): las maldades abren la rama **Sombra** (sigilo, poder, recursos) y la bondad abre la rama **Confianza** (confianza, favores, habilidades blandas). Cada skill exige un umbral de Senda y la anterior de su rama.
- Una skill aprendida **se conserva** aunque la Senda cambie después, pero no se pueden aprender las siguientes de esa rama sin volver al umbral.
- Con 5 puntos y umbrales opuestos, en la práctica se profundiza en una sola rama.

| Rama | Skill | Efecto (provisional) | Umbral de Senda |
|---|---|---|---|
| **Sombra** | S1 Paso quedo | Los Únicos te ven a 2 casillas menos (`vision_radius` −2). No permite cruzar fronteras sin máscara | ≤ −10 |
| | S2 Golpe fuerte | Acción nueva: daño ×1,5, una vez cada 3 turnos | ≤ −20 |
| | S3 Botín | Al vencer a un Único, 25% de dejar una ofrenda de 3–4 | ≤ −35 |
| | S4 Imponerse | Opción del menú del borde: si tu nivel ≥ d + 2, el Botarramas se aparta sin pelear. Cuenta como vencerlo (Bosque forzado, hostilidad +1, relación −10), sin XP | ≤ −50 |
| **Confianza** | C1 Palabra suave | Peaje −1 (mín. 1) | ≥ +10 |
| | C2 Rostro conocido | Hasta 2 favores de Sarua activos y sus recompensas +1. Los adoc de afinidad dudosa aceptan trabajar contigo | ≥ +20 |
| | C3 Descanso del Nujio | El riutash en refugio dentro de un Bosque pagado cura el 75% de lo que falta (en vez del 50%) | ≥ +35 |
| | C4 Llamada del Bosque | En Bosques con relación ≥ 30, un Único del Bosque pelea a tu lado (aliado) | ≥ +50 |

- Los puntos de skill que no se pueden gastar (Senda neutral) se guardan.

## Conexión con lo que ya existe
- **Hostilidad y relación** (por Bosque, ADR 0013): la Senda es global y las modifica.
- **Fama**: no depende de la Senda.
- **Robo y daño al Bosque**: bajan la Senda y la cordura del Bosque. Dañar un Bosque hasta la cordura mínima puede **desatar a su Iserald** (`monstruos.md`, `bosques-y-relacion.md`).

## Inputs / outputs
- **Inputs:** acciones del jugador (tabla), subida de nivel, gasto de puntos.
- **Outputs:** Senda e icono, stats, skills desbloqueadas y aprendidas, modificadores en villas, Bosques y combate.

## Casos límite
- **Partida de la 0.3**: al cargarla, se recalculan los stats con la tabla automática y se dan los puntos acumulados según el nivel (3 por nivel), para que el jugador los reparta. Se avisa en pantalla.
- **Senda en el límite**: −100 y +100 son topes.
- **Imponerse contra un Botarramas de un Bosque enojado**: no funciona.
- **Puntos sin gastar al subir varios niveles a la vez**: se acumulan.

## Criterios de éxito para playtest
- Dos testers con la misma seed y Sendas opuestas describen partidas distintas.
- El jugador reconoce el icono de Senda y entiende por qué se le desbloquea una skill.
- Ningún build de combate hace imposible el Ofomni, y ninguno lo hace trivial.

## Preguntas abiertas
- **#162**: ¿confirma el dueño el ajuste de que ATQ y DEF cuesten 3 puntos (y no 1)?
- **#161**: tope de DEF comprada o enemigos más fuertes para los niveles altos.
