# Spec: primera pasada de sprites y SFX (0.2.0)

> Dueños: `pixel-artist` (sprites) y `audio-designer` (SFX). Estado: **[PLACEHOLDER]** programático, listo para que el artista humano lo sustituya con la misma spec (tamaño, fotogramas, orden y colores clave).
> Fuentes: `docs/design/mechanics/monstruos.md` (Botarramas, Ofomni), glosario (lenfi, adoc, sfida), `docs/art/style-guide.md`.

## Cómo se generan
- Sprites: `python tools/art/make_sprites.py` escribe `assets/sprites/*.png`. Cada fotograma es una matriz de caracteres; cada carácter es un color de la paleta (tabla `COLORS` del script) y `.` es transparente. El contorno de 1 px (`181425`, el más oscuro de la paleta) se añade solo. El script falla si algún color se sale de la paleta o hay alfa parcial. `--preview <carpeta>` deja vistas x8.
- SFX: `python tools/audio/make_sfx.py` escribe `assets/audio/sfx/sfx_*.wav` (mono, 16 bits, 22050 Hz). Síntesis estilo NES: cuadrada con ciclo de trabajo, triangular de 16 escalones y ruido de LFSR (determinista).
- Hojas: fotogramas en horizontal y direcciones en vertical, sin márgenes ni recorte (como `Export Sprite Sheet` de Aseprite, *by rows, trim off*).

## Sprites

| Archivo | Tamaño hoja | Fotograma | Filas × fotogramas | Paleta |
|---|---|---|---|---|
| `sprite_adoc_walk.png` | 32×64 | 16×16 | 4 (abajo, arriba, izquierda, derecha) × 2 de caminar | Cabello `262b44`/`3a4466`, piel trigueña `c28569`/`b86f50`, ojos verdes `3e8948`, túnica `be4a2f`/`d77643`, cuero `733e39`, cinturón `3e2731`, pantalón `3a4466` |
| `sprite_sfida_idle.png` | 32×16 | 16×16 | 1 (abajo) × 2 de reposo | Cabello y piel lenfi, diadema y cinta `feae34`, túnica `68386c`/`b55088`, Luz `fee761`/`ffffff` |
| `sprite_botarramas_walk.png` | 32×24 | 16×24 | 1 (mira a la izquierda) × 2 de renqueo | **Recoloreable**: claves `A`/`B`/`C`; fijos: contorno, ojo `ffffff` |
| `sprite_ofomni_idle.png` | 64×32 | 32×32 | 1 × 2 (tentáculos) | **Recoloreable**: claves `A`/`B`/`C`; fijos: contorno, ojo `ffffff`, iris `e43b44` |
| `sprite_icon_sign.png` | 8×8 | 8×8 | 1 × 1 | Madera `b86f50`/`733e39` |
| `sprite_icon_refuge.png` | 8×8 | 8×8 | 1 × 1 | Tejado `be4a2f`, pared `e4a672`, puerta `3e2731` |

### Personajes
- **Adoc**: lenfi (piel trigueña, ojos verdes, cabello negro largo con una trenza: sobre el hombro de frente, por la espalda de espaldas y de lado). Ropa de protector: mangas y botas de cuero, túnica rojiza y cinturón. Fotogramas de frente y espalda: alterna la pierna adelantada; de lado: zancada y pies juntos. La izquierda es la derecha reflejada. Cambia de fotograma al empezar cada paso (con `STEP_TIME` = 0,16 s sale a unos 6 fps).
- **Sfida**: lenfi con túnica larga de oficiante, cinta dorada central y diadema. Fotograma 1: junta las manos con un poco de Luz. Cambia cada 0,8 s.

### Monstruos recoloreables
Se pintan con tres colores clave que el juego sustituye al cargar el PNG por los colores del Bosque (`UnicoArt.recolor`, con `PlaceholderTileset.LEAVES` y `TRUNKS`):

| Clave | Color en el PNG | Se cambia por |
|---|---|---|
| `A` | `c0cbdc` | hoja clara del Bosque |
| `B` | `8b9bb4` | hoja oscura del Bosque |
| `C` | `5a6988` | tronco del Bosque |

Ningún otro píxel del monstruo puede usar esos tres colores. El artista humano debe respetar las claves o avisar para cambiar `UnicoArt.KEY_*` y el script a la vez.

- **Botarramas**: ave sin plumas, piel clara con granos oscuros, muñón de ala, pico, cola y patas en color tronco. Mira a la izquierda; el juego lo refleja cuando anda hacia la derecha. Fotograma 0: apoyado en la pata buena con la mala encogida. Fotograma 1: baja el cuerpo y apoya la mala, torcida. Cambia de fotograma en cada paso: eso es el renqueo. El pixel art no se gira (el balanceo con rotación queda solo para el placeholder procedural).
- **Ofomni**: ojo enorme con iris rojo y cuatro tentáculos que cambian de postura entre fotogramas. Simétrico, menos los tentáculos y el brillo del ojo (arriba a la izquierda).
- **Reparep** (pendiente, `UnicoArt.Kind.REPAREP`; hoy placeholder procedural de `UnicoArt.texture`): cangrejo fantasmal, pálido y algo transparente (en el placeholder el cuerpo va al 78% de opacidad y su color claro, aclarado hacia el blanco), con caparazón y pinzas en los colores de hoja del Bosque, y patas y tallos de los ojos en color tronco. En combate se dibuja en un cuadro de 40×40 (hasta 4 en fila); en el mundo, como un grupo de 2 a 4 cangrejos de 15×15 dentro de un cuadro de 32×32 (`UnicoArt.group_texture`). Necesita una hoja de 2 fotogramas con las claves de color de arriba y decidir cómo se ve la transparencia con la paleta (¿un tramado?).
- **Otro adoc** (pendiente, `AdocNpc`; hoy la hoja del Adoc con la túnica recoloreada con los colores de `data/npcs/otros_adoc.json`): un adoc con otra ropa, que se reconozca como adoc y no como el jugador.
- **Combate**: el primer fotograma ampliado a escala entera (×4 el Botarramas, ×3 el Ofomni) en el cuadro de 96×96. El Adoc de espaldas usa el fotograma 0 de la fila "arriba".

### Iconos
Letrero y refugio de 8×8, listos para el HUD o el mapa. Todavía no se usan: el mapa sigue con `PixelIcons`, que se tiñe por código.

## SFX

| Archivo | Uso | Síntesis | Duración |
|---|---|---|---|
| `sfx_step` | Paso del jugador, uno de cada 2 (`PlayerWalker.STEP_SOUND_EVERY`) | Ruido grave, muy bajo | 35 ms |
| `sfx_text_blip` | Letra del diálogo, una de cada 2 (`DialogueBox.BLIP_EVERY`) | Cuadrada 990 Hz al 25 % | 22 ms |
| `sfx_hit` | Golpe en combate (Atacar, Ofrecer Luz, golpe del Botarramas) | Ruido seco + cuadrada que cae | 140 ms |
| `sfx_whip` | Latigazo del Ofomni | Silbido de ruido que sube + chasquido | 210 ms |
| `sfx_riutash_warning` | `EventBus.riutash_warning` | Dos notas de alerta que bajan | 350 ms |
| `sfx_riutash` | `EventBus.riutash_passed` (destello) | Arpegio rapidísimo + ruido brillante + triangular grave | 750 ms |
| `sfx_riutash_swish` | Reloj del riutash: avisos de 60 y 15 s y a los 10 y 5 s | Barrido de ruido que sube y baja, "swishhh" | 420 ms |
| `sfx_level_up` | `EventBus.character_leveled_up` y `Sfx.play_level_up()` | Arpegio de do mayor | 640 ms |
| `sfx_menu_move` | Mover el cursor de `OptionMenu` | Cuadrada 1320 Hz | 30 ms |
| `sfx_menu_accept` | Aceptar en `OptionMenu` | Dos notas que suben | 110 ms |

- Integración: autoload `Sfx` (`scripts/autoload/sfx.gd`) con `play(nombre)`. Una voz por efecto: repetirlo lo reinicia. Suena con el árbol en pausa. Un nombre sin archivo devuelve `false` y no hace nada.
- Bus `SFX` a −6 dB (`default_bus_layout.tres`; si faltase, `Sfx` lo crea).
- Nombres: `sfx_<nombre>.wav`, según `docs/CONVENCIONES.md`. La lista del `audio-designer` (`sfx_ui_move`...) se alinea con estos nombres cuando se revise el audio.
