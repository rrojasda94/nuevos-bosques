# Dirección de arte — Nardaram

> Dueño: `pixel-artist`. Estado: **propuesta**, pendiente de validar con el dueño del proyecto. Sirve también como brief para un artista humano.
> Complementa [`style-guide.md`](style-guide.md): la guía fija las reglas técnicas; este documento fija la intención.

## La idea en una frase
Caminar por un bosque extraño que te mira, acompañado por criaturas etéreas que no terminas de entender. Nostalgia de RPG de SNES con alma de juego indie.

## Pilares
1. **Nostálgico.** Lectura inmediata de RPG clásico: sprites pequeños y expresivos, menús en cajas, combate de perfil.
2. **Místico.** El bosque es un ser vivo y antiguo. Luz que no se explica, niebla baja, cosas que flotan.
3. **Extraño, no terrorífico.** Inquieta, no asusta. Formas de árbol que casi son caras, colores un poco fuera de lugar, silencio.
4. **Vivo en lo pequeño.** Todo se mueve un poco: hojas, hierba, partículas, respiración de los personajes. Nada está del todo quieto.

## Referencias
- **Final Fantasy III (SNES, en Japón Final Fantasy VI):** combate de perfil (grupo a la derecha, enemigos a la izquierda sobre un fondo pintado del lugar), ventanas azules de menú, sprites de batalla con poses (listo, golpe, herido, victoria).
- **Atmósfera:** Secret of Mana (bosques densos y luminosos) y Eastward (detalle de texturas pixeladas y escenas vivas). Spiritfarer u Ori solo como sensación de compañía de seres de luz (a confirmar).

## Color
- Se mantiene la paleta fija de 32 colores (`assets/palettes/palette_nuevos_bosques.gpl`). Composición y tamaños de 16 bits; color restringido de 8 bits.
- **Base del bosque:** verdes y azules apagados; el bosque no es "verde alegre".
- **Acento místico:** un solo color frío y brillante (cian o lavanda) reservado para lo etéreo: criaturas, Luz, runas. Si todo brilla, nada es mágico.
- Cada Bosque y estado (sano, enojado, corrupto, muerto) cambia la rampa dominante, como ya hace el recoloreado por claves.

## Movimiento sutil
Es lo que más vende la atmósfera y casi todo se resuelve con código, sin dibujar más.

| Elemento | Cómo | Quién |
|---|---|---|
| Copas y hierba que se mecen | Shader de desplazamiento por píxel entero (sin interpolar) | `engine-architect` + `pixel-artist` |
| Motas de luz, polen, esporas | Partículas de 1 px con colores de paleta | `pixel-artist` |
| Niebla baja | Capa de tiles de niebla con tramado (*dithering*), deslizándose lento | `pixel-artist` |
| Sombras de copas | Capa de sombra animada sobre el suelo | `pixel-artist` |
| Personajes en reposo | 2-4 fotogramas de respiración, no estatuas | `pixel-artist` |
| Criaturas etéreas | Flotan con un vaivén seno; parpadeo entre 2-3 tonos del acento | `pixel-artist` |

Regla: el movimiento es lento y en saltos de píxel entero. Nada de suavizados ni de giros.

## Criaturas etéreas acompañantes
Propuesta visual; su función en el juego la decide `game-designer` (posible encaje con los Otros adoc aliados o con la Luz).
- Pequeñas (8×8 o 16×16), siluetas simples, ojos sin pupila o sin ojos.
- Hechas casi solo del color de acento; pueden tener píxeles que aparecen y desaparecen.
- Siguen al jugador con retraso y se dispersan cerca de peligro.

## Combate estilo FF III (SNES)
Hoy el combate es estilo Pokémon (monstruo en un cuadro de 96×96 y Adoc de espaldas). La propuesta:
- **Vista de perfil:** grupo a la derecha mirando a la izquierda, enemigos a la izquierda.
- **Fondo de batalla** por bioma y estado del Bosque (320×~120), con capa animada (niebla, hojas cayendo).
- **Sprites de batalla de héroe** 16×24 con poses: reposo, listo, ataque, herido, victoria y KO.
- **Enemigos** más grandes y detallados que en el mapa (32×32 a 64×64); los jefes (Iserald) pueden ocupar media pantalla.
- **Ventanas de menú** en el estilo de cajas con borde, ver `ui-ux-dev`.

> Cambiar la presentación del combate cruza áreas: `game-designer` decide si llega también la barra de tiempo (ATB) de FF; `ui-ux-dev` maqueta la pantalla; se registra en un ADR antes de implementarse.

## Cambios pendientes en la guía
- Permitir **niebla y luz como post-proceso** (hoy solo se permite la luz de luna, ADR 0012), o resolver la niebla solo con tramado.
- Añadir tamaños de sprite de batalla y de fondos de batalla.

## Plan sin presupuesto
1. Mejorar lo que no cuesta: movimiento sutil y partículas por código sobre los placeholders actuales.
2. Una escena vertical de muestra: un claro del bosque con niebla, motas, un acompañante y el Adoc. Sirve de prueba de concepto y de captura.
3. Rehacer el combate en vista de perfil con placeholders (tras el ADR).
4. Con presupuesto: contratar a un artista con este documento como brief y la escena del punto 2 como prueba pagada.
