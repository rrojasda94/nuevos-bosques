# ADR 0014 — Mundo 2.0: Zelda con relieve, movimiento libre y mundo híbrido

> **Estado: ACEPTADO** (dueño, 2026-10-24). Se implementa en la **versión 0.4 "Mundo 2.0"**, después de cerrar las dinámicas de la 0.3 (orden del dueño: "continúa con lo que tienes pendiente y las dinámicas del juego, luego arreglamos mapa y jugabilidad"). Plan de PR: [`docs/design/roadmap-mundo-2.md`](../design/roadmap-mundo-2.md).
>
> **Sustituye en parte** a los ADR 0003, 0004 (tamaño de chunk), 0005 (cuándo se genera) y 0006 (terreno, senderos, hub, riscos, persistencia y tamaño). Lo que cada uno conserva está en "Relación con otros ADR". Resuelve la pregunta #165 (vista).
>
> Base: la propuesta del spike `spike/mapa-estilo-zelda` (rama local, sin push), que se conserva como **Anexo** al final. Lo que este ADR dice arriba manda sobre el anexo.

## Contexto
El spike comparó tres vistas con los mismos chunks (actual, Z "Zelda con relieve en capas" e I "isométrico") y recomendó Z. El dueño probó las dos (2026-10-24):

> "me gusta como se ve en isomtrico pero la jugabilidad es terrible. mover conWASD resulta super complicado... los arboles y los elementos decorativos se ven muy repetitivos. Si, el generador de chunks parpadea y quita la inmersion. Lo otro sería crear un mapa inmenso y ya no generarlo aleatoriamente, tener aldeas y lugares bien definidos. cosa que solo carga lo que debe cargarse y tenemos un mundo abierto."

Ante las opciones que le planteó el coordinador, **eligió**:
1. **Vista**: Zelda con relieve en capas (opción Z) y **movimiento libre en 8 direcciones**, píxel a píxel y fluido, en lugar de por casillas.
2. **Mundo híbrido**: a mano la geografía grande (regiones, ríos, montañas, costa), las villas con nombre y los lugares importantes (hitos, tarcas, Bosques clave), sobre su mapa del Sur Lenfi. El relleno es procedural y distinto en cada partida. La región se genera **entera** al crear la partida (o en segundo plano) y se cachea: en juego solo se carga lo que se ve y nunca hay parpadeos.
3. **Más variedad visual** en árboles y decoración.

Problemas que hay que resolver:
- **El parpadeo.** Al cruzar el borde de un chunk, la escena de exploración funde a negro (`TRANSITION_TIME`), genera el chunk y sus 8 vecinos y redibuja todo. Es el "parpadeo" que rompe la inmersión.
- **Movimiento tosco.** `PlayerWalker` va por casillas con un tween de 0,16 s.
- **Repetición.** Los árboles son de 1×1 y se reparten casilla a casilla, los senderos forman una X por chunk y el ruido deja un grano fractal (análisis completo en el Anexo).
- **Coste.** El generador del spike tarda ~450 ms por chunk de 80×80, frente a los ~60 ms del actual de 64×64. Generar al entrar sería peor que ahora.

## Decisión

### 1. Escala
| Magnitud | Valor | Cambio |
|---|---|---|
| Viewport | **320×180**, escala entera, `Nearest`, stretch `viewport`/`keep` | Igual |
| Tile | **16×16 px** | Igual |
| Chunk | **80×80 tiles** (antes 64×64) | Nuevo |
| Sector (unidad de dibujo y streaming) | **16×16 tiles** (5×5 sectores por chunk) | Nuevo |
| Celda gruesa (relieve y autoría) | **4×4 tiles** (20×20 por chunk) | Nuevo |
| Personajes | 16×16 o 16×24; caja de colisión de **10×6 px** en los pies | Nuevo (caja) |

**Por qué 80.** El dueño pidió "aumentar un poco el tamaño de los chunks" (2026-10-24) y el ADR 0004 fijaba 64 a petición suya (#10), así que este cambio lo sustituye con su permiso. Con movimiento libre y sin transiciones, el chunk **deja de verse**: pasa a ser la unidad lógica (Bosques, peaje, refugios, mapa M, archivos de caché). Con objetos de 2×2, en 64 no caben una villa, 2 o 3 puntos de interés y el relieve. 96 alarga demasiado los Bosques (15,4 s por chunk; un Bosque de 16 chunks sería enorme). Con 80, cruzar un chunk andando son 12,8 s y un Bosque de 3×3 chunks, unos 38 s.

**Por qué sectores de 16.** Un chunk entero (6.400 casillas × 3 capas) es demasiado para montarlo en un solo fotograma. Un sector (256 casillas) se monta en ~1 ms. En pantalla caben 20×11,25 tiles, así que bastan unos 3×2 sectores visibles.

**Coordenadas.**
- `chunk_coord` (`Vector2i`): igual que hoy.
- `cell`: la casilla dentro del chunk, ahora de **0 a 79**.
- `world_cell`: casilla global de la región, `chunk_coord * 80 + cell`.
- `world_pos`: posición en píxeles (`Vector2`) de los pies del personaje. La casilla lógica es `floor(world_pos / 16)`.
- Con la región actual (12×16 chunks) el mundo mide 960×1280 tiles, es decir, 15.360×20.480 px. Con `float` de 32 bits la precisión sigue por debajo de 0,01 px.
- Nueva clase pura `WorldCoords` con las conversiones.

### 2. Movimiento libre en 8 direcciones
**Decisión: movimiento manual con colisión contra la cuadrícula lógica** (clase pura `GridMover`). No se usa el motor de física (`CharacterBody2D`).

| | `CharacterBody2D` + física del `TileMapLayer` | **`GridMover` (elegido)** |
|---|---|---|
| Colisión | Hay que generar formas de física por tile y por nivel, y reconstruirlas al hacer streaming (`set_cell` reconstruye cuerpos) | Lee `blocked[]` del chunk, que ya existe. Sin coste al cargar sectores |
| Relieve | Una capa de física por nivel y cambios de máscara en escaleras | No hace falta: entre niveles no hay casillas transitables contiguas salvo escaleras y rampas (ver §3) |
| Tests | Necesita árbol de escena y física | Clase pura testeable con GUT y determinista |
| Monstruos | Un cuerpo por monstruo | La misma clase |
| Esquinas | `move_and_slide` se engancha en las esquinas de los tiles | Ayuda de esquina a medida (estilo Zelda) |

**Cómo funciona `GridMover`.**
- Lógica pura, sin nodos. Entrada: `world_pos`, la caja (10×6 px, centrada en x, apoyada en los pies), el vector de entrada, la velocidad, `delta` y un `Callable is_blocked(world_cell) -> bool`.
- **Por ejes.** Mueve en x y comprueba las casillas que pisa la caja; si choca, la pega al borde. Después hace lo mismo en y. Así se desliza a lo largo de las paredes.
- **Ayuda de esquina.** Si el bloqueo frontal solapa la caja en ≤ 5 px, empuja en perpendicular hacia el hueco, a la velocidad de andar. Así se entra en senderos de 2 casillas sin apuntar al píxel.
- **Diagonal.** Para pasar entre dos casillas en diagonal hay que solapar las dos ortogonales. Si alguna está bloqueada, no se pasa, así que no hay atajos por las esquinas de los riscos.
- Se ejecuta en `_physics_process` a 60 Hz, con la posición en `float`. El dibujo se ajusta al píxel (`snap_2d_transforms_to_pixel`, ya activo) y la cámara sigue la posición ajustada.

**Entrada.** `Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")`: 8 direcciones con teclado y analógico con mando (Steam Input), normalizado para que la diagonal no sea más rápida. `run` igual que hoy.

**Velocidad equivalente a la actual.** Hoy: 16 px / 0,16 s = **100 px/s** andando y **200 px/s** corriendo (×2). Se mantienen esos valores, pero pasan a `data/` (`data/world/movement.json`: `walk_speed`, `run_speed`, `corner_assist_px`, `hitbox`), no a constantes. A 60 Hz, 100 px/s son 1,67 px por tick y pueden notarse saltos irregulares de píxel. Si en el playtest se nota, la alternativa es 120/240 px/s (2 y 4 px por tick exactos), que decide `game-designer`.

**Orientación y animación.** El sprite sigue teniendo 4 direcciones. `facing` es el eje dominante de la entrada; en diagonal exacta se conserva el anterior si es una de sus componentes. El fotograma de andar cambia cada 8 px recorridos (no por paso). El sonido de paso sale cada 16 px.

**Convivencia con la cuadrícula lógica.** Todas las reglas siguen en casillas. Solo cambia quién dice en qué casilla estás.
- `GridMover` emite **`cell_changed(world_cell)`** cuando la casilla de los pies cambia. Sustituye a `PlayerWalker.stepped` en todo lo que hoy cuelga de él: chunk entrado (`EventBus.chunk_entered`), chunks explorados, letreros, refugio, descanso en la villa, `explored_chunks` y misiones.
- **Interacción (E).** Punto de sondeo = pies + `facing` × 12 px. Se busca en la casilla del sondeo, después en la de los pies y después en las 8 de alrededor del sondeo. `Interaction.find` pasa a recibir `(world_pos, facing)`, pero por dentro sigue con casillas. Los objetos de varias casillas (frutal 2×2, árbol hueco, cueva, Nujio, casas) se encuentran por `occupant[]`, desde cualquiera de sus casillas.
- **NPC.** Se habla con el NPC más cercano que esté a ≤ 14 px del sondeo, en el semiplano de `facing`.
- **Letreros.** Se leen al entrar en su casilla o en una vecina (como hoy), vía `cell_changed`.
- **Borde de Bosque.** La exploración compone el `is_blocked` del jugador: terreno más las reglas. Una casilla de un Bosque cerrado bloquea al jugador y, al chocar con ella, se emite `EventBus.bosque_border_reached(bosque_id)` una vez por contacto. El flujo del peaje y del Botarramas sigue como hoy, pero sin `edge_reached` por chunk, porque ya no hay bordes de chunk que crucen escenas.
- **Encuentros.** Un monstruo enfrenta al jugador cuando sus cajas están a ≤ `engage_px` (en datos; equivale al `engage_distance` actual × 16). La visión sigue en casillas (Chebyshev, `MonsterSteering.sees`).
- **Guardado de posición.** Se guardan `chunk_coord` y `player_cell` (0–79, la casilla de los pies) y, además, `player_facing`. Al cargar, el jugador aparece en el centro de esa casilla, que es transitable por construcción (la casilla que contiene el centro de la caja nunca está bloqueada). Perder hasta 8 px es aceptable.

**Monstruos.** La lógica de decisión no cambia: `MonsterSteering` (decide, path_step y leash en casillas, ya testeado) sigue eligiendo la **siguiente casilla**. `OverworldMonster` deja de hacer tweens: se mueve hacia el centro de esa casilla con su propio `GridMover` y su velocidad (`speed_px` en los datos del monstruo, igual a 16 / su tiempo de paso actual). Al llegar al centro pide la siguiente. Así se mueven fluidos, chocan con el mismo mapa y respetan el relieve sin código nuevo. Los monstruos se activan por los **chunks activos** (el del jugador y sus 8 vecinos); al salir de ese anillo se duermen, sin borrar su estado.

### 3. Relieve
- **Niveles 0–3**, cuantizados sobre la celda gruesa de 4×4 (sin celdas sueltas, como en el spike). La altura sale de la autoría donde el dueño la pinta y del ruido donde no (§4).
- **Caras de risco** hacia el sur: **2 filas por nivel** (32 px de alto por nivel), con labio, lajas y base oscura, y **sombra** al pie. Hacia el norte, el este y el oeste: **borde** (pared lateral o labio). Del isométrico se adopta un borde este y oeste más ancho, con sombra hacia el este, para que se lea mejor.
- **Colisión por nivel sin capas de física.** Las caras y los bordes bloquean, así que dos casillas transitables de distinto nivel **nunca son vecinas ortogonales** salvo a través de una **escalera** (un sendero que cruza una cara; la columna entera de la cara se vuelve escalera) o de una **rampa** (un sendero que cruza un borde). Por eso basta un único `blocked[]`. Un test verifica esta invariante en todos los chunks de varias seeds.
- El **nivel** de cada casilla se guarda (`level[]`) para el dibujo, la sombra de nivel (hierba un tono más clara en las mesetas altas) y, más adelante, la visión de los Únicos si se quiere que no vean a través de los riscos.
- **Cascadas**: donde un río cruza una cara, la cara es agua que cae (tile animado). Bloquea.
- **Orden de dibujo** (de abajo arriba, todo por sector):
  1. `TileMapLayer` de **suelo**: suelo, agua, caras de risco, escaleras, rampas y cascadas. Las caras son casillas propias al sur de la meseta. Como bloquean, ningún personaje se dibuja *sobre* ellas desde arriba: quien está abajo queda delante (está más al sur) y quien está arriba queda detrás del labio. No hace falta ordenarlas en Y.
  2. `TileMapLayer` de **sombras** (al pie de las caras y de los objetos grandes) y decoración plana (flores, matas, piedrecitas).
  3. **Nodo con orden en Y** (`y_sort_enabled`) para todo lo que tiene altura: árboles 2×2 y 3×3, rocas, casas 4×3, Nujio, letreros, tocones, jugador, NPC y monstruos. Son `Sprite2D` con el origen en la base, de un **pool** reutilizado al cargar y descargar sectores.
  4. Post-proceso de luz de luna en la `CanvasLayer` 1 y UI en la capa 2 o más (sin cambios).

### 4. Autoría a mano (para el dueño)
**Recomendación: imágenes PNG por capas más una tabla CSV de lugares**, con una herramienta que valida y genera una vista previa.

**Comparación.**
| | **PNG por capas + CSV (elegido)** | Tiled | Editor dentro de Godot |
|---|---|---|---|
| Qué necesita el dueño | Su programa de dibujo (el mismo con el que hizo el mapa del Sur Lenfi), más una hoja de cálculo | Aprender Tiled (tilesets, capas de objetos, propiedades) | Abrir el proyecto en Godot y aprender un plugin |
| Escala adecuada | Sí: se pinta la celda gruesa (1 px = 4×4 tiles), no casilla a casilla | Pensado para pintar tiles uno a uno; a escala gruesa es un editor de imágenes peor. Las capas de objetos para los lugares sí son buenas | La mejor previsualización, pero hay que construirla |
| Coste técnico | Bajo: `Image.load` y lectura de colores exactos | Medio: importador (addon YATI) o lector de TMX/JSON propio, una dependencia más | Alto: 2 o 3 PR de `EditorPlugin` antes de poder pintar nada |
| Revisión en Git | PNG pequeños (240×320) y CSV legible | TMX/JSON legible | Recursos `.tres` |
| Riesgo | Antialiasing al pintar (lo detecta el validador) | Desajuste de versiones del importador | Mantener un editor propio |

**Tiled** queda como opción para los **lugares** si el CSV se queda corto (muchos lugares con muchas propiedades), sin cambiar las PNG. El **editor en Godot** se descarta por ahora.

**Formato.** Carpeta `data/world/regions/<region_id>/`, junto al JSON de parámetros de la región, que sigue existiendo y gana la clave `"authoring": "<region_id>/"`. Todas las PNG tienen el **mismo tamaño**: 1 px = 1 celda gruesa = 4×4 tiles, así que un chunk son 20×20 px y la región actual (12×16 chunks), 240×320 px. El tamaño de la región en chunks sale de la imagen (`size_chunks` deja de escribirse a mano).

| Archivo | Qué se pinta | Colores (exactos; la tabla vive en `data/world/authoring_palette.json`) | Transparente significa |
|---|---|---|---|
| `altura.png` | Relieve | 4 grises = niveles 0–3; un color de "cumbre" (montaña infranqueable) | El generador decide con ruido, como hoy (gradiente norte–sur + ruido) |
| `agua.png` | Ríos, lagos y costa | Río navegable, río estrecho, lago, mar, vado o paso (#88) | Sin agua pintada; el generador puede añadir arroyos de montaña |
| `caminos.png` | Caminos principales | Camino (3 tiles de ancho), puente forzado | Los caminos entre villas los traza el generador (red de `BosqueMap`, ADR 0006) |
| `bosques.png` | Bosques clave | Un color por Bosque con nombre, declarado en `lugares.csv` | El reparto en Bosques es procedural (4–16 chunks, ADR 0007) |
| `lugares.csv` | Villas con nombre, villa natal, hitos, tarcas, Nujio de los Bosques clave, otros lugares | Columnas: `id`, `nombre`, `tipo` (`villa`, `villa_natal`, `hito`, `tarca`, `bosque`, `lugar`), `x`, `y` (**en píxeles de las PNG**, los que marca el cursor del programa de dibujo), `color` (solo `bosque`), `estilo` (opcional: silueta y hojas del Bosque), `notas` | — |

- Las coordenadas del CSV están en los mismos píxeles que las PNG, así que el dueño las copia del cursor de su programa sin hacer cuentas de chunks.
- En `bosques.png` basta pintar el chunk o los chunks del Bosque. El generador extiende el Bosque procedural alrededor si hace falta respetar los 4–16 chunks.
- La **villa natal** del CSV sustituye a `start_chunk`.

**Herramienta** (`tools/world/preview_region.sh`, que llama a un script headless de Godot):
1. **Valida**: colores desconocidos con sus coordenadas (antialiasing), lugares fuera del mapa o en el agua, villas sin acceso a pie, Bosques clave fuera del rango de 4–16 chunks, un río pintado que se corta.
2. **Genera** la región con una seed y escribe `build/preview_<region>_<seed>.png` a 1 px = 1 tile, con la rejilla de chunks, sus coordenadas y los nombres de los lugares.
3. Guía paso a paso para el dueño en `docs/design/world/autoria.md` (programa, lápiz sin suavizado, capas, cómo exportar y cómo probar). Si usa Aseprite, `--split-layers` exporta cada capa a su PNG; en Krita, "Exportar capas".

**Punto de partida.** El primer PR de autoría **exporta las PNG desde el generador actual** (lo que hoy sale del ruido), para que el dueño tenga algo que retocar en vez de un lienzo en blanco y el juego siga pareciéndose al de hoy hasta que pinte el Valle del Sara sobre su mapa.

### 5. Generación procedural del relleno
Dos pasadas, ambas deterministas por `(seed, region_id, authoring_hash, generator_version)`.

**Pasada de región** (`RegionPlan`, una vez por partida, un solo hilo, objetivo ≤ 1,5 s). Resultado en memoria durante toda la partida (también lo usa el mapa M):
- **Altura gruesa** (240×320): lo pintado manda; donde es transparente, la elevación de `ChunkGenerator.Terrain` cuantizada en 4 niveles con los umbrales del spike (`-0.1 / 0.32 / 0.62`), sin celdas sueltas. Se calcula una vez para toda la región, sin los márgenes (`PAD`) ni la caché por diccionario del spike.
- **Agua**: ríos y lagos pintados, rasterizados con meandro de ruido de poca amplitud (±1 celda gruesa) para que no se vean los píxeles. El río procedural de la ADR 0006 solo se usa si `agua.png` no existe. Los arroyos de montaña siguen siendo procedurales.
- **Bosques** (`BosqueMap` ampliado): los Bosques clave se fijan desde la autoría y el resto se reparte como hoy (4–16 chunks contiguos, estilos sin repetir hoja con los vecinos).
- **Villas y lugares** desde el CSV. Las villas que no son del CSV las decide `game-designer` (parámetro de región `procedural_villa_chance`; por defecto 0: solo hay villas con nombre).
- **Caminos**: los pintados, más la red de `BosqueMap` (Prim + 15 % de ciclos) entre villas sin camino pintado.
- **Puertas entre chunks**: cada borde tiene sendero si lleva camino o, si no, con probabilidad del 70 %. Para que todo Bosque se recorra a pie, se calcula un árbol de expansión de bordes por Bosque (como los caminos) que obliga a abrir las puertas necesarias. La posición de cada puerta sale de un hash del borde.
- **Refugios**: el reparto de la ADR 0006 sin cambios (`per_bosque`, `min_spacing`, `max_distance`).

**Pasada de chunk** (`ChunkBuilder`, en hilos, objetivo ≤ 80 ms). Solo lee el `RegionPlan` (inmutable) y escribe su propio `WorldChunk`, así que se puede ejecutar en cualquier orden y en paralelo:
1. Suelo base y pedregal.
2. Riscos desde la altura gruesa: caras, bordes y cascadas.
3. **Puntos de interés** (2 o 3; 1 junto a una villa o un Nujio) con pesos por latitud: laguna, hito 3×3, colina con escalera, círculo de piedras, pradera de flores, arboleda. En posiciones al azar con el RNG del chunk, **nunca en el centro fijo**. Los lugares del CSV que caen en el chunk ocupan su sitio y cuentan como punto de interés.
4. **Red de senderos**: nodos = puertas + puntos de interés + ancla (villa, Nujio o el primer punto de interés). Árbol de expansión mínimo (Prim), con las aristas entre puertas de camino a mitad de precio, trazado con **A\*** (`AStarGrid2D`) sobre la rejilla gruesa: el agua, las caras, las casas y el Nujio cuestan, y lo ya trazado abarata. Tramos rectos de 4 casillas como mínimo; las escaleras cruzan las caras de frente. Caminos de 3 casillas y senderos de 2, con puentes. Sin la X: salen Y, cadenas y ramales.
5. **Formas grandes**: bosque en manchas de árboles 2×2 (ruido de baja frecuencia, al menos 4 vecinos de bosque, sin árboles sueltos), rocas 2×2 en el pedregal y en la montaña, villa con casas 4×3, Nujio (zona aplanada a un nivel).
6. **Decoración variada** (entregable 3 del dueño; detalle en la spec de `pixel-artist`):
   - Árboles: por silueta de Bosque, **4 variantes de 2×2** más volteo horizontal (8 aspectos), un árbol joven de 1×1, un árbol grande de 3×3 y un árbol seco. La variante sale de un hash de la posición con **rechazo de repetición**: dos vecinos nunca usan la misma variante y el mismo volteo.
   - Suelo: 4 variantes de hierba elegidas por **ruido de baja frecuencia** (manchas grandes), nunca por hash por casilla, para no volver al grano.
   - Decoración que no bloquea: al menos **16 piezas por tipo de Bosque** (flores de 3 colores de su paleta, matas, helechos, piedrecitas, hojarasca, setas, raíces), colocadas en **grupos** (muestreo de Poisson dentro de manchas de ruido) con un borde de matas alrededor de las flores. Las combinaciones de pieza, color y volteo dan cientos de aspectos.
   - Tocones, troncos caídos y rocas pequeñas: raros y bloquean.
7. Letreros, refugio (preferencia: **cueva en una cara de risco**; si no hay, árbol hueco 2×2 junto a un sendero), frutales (árboles 2×2 elegidos, ADR 0006 "Frutales"), colisión derivada (`blocked[]`) y comprobación de accesibilidad.

**Sin la X ni el grano**: hub no central, red por árbol de expansión, puertas opcionales, formas de 2×2 o más y ruido solo de baja frecuencia. Un test mide que el hub no coincide con el centro en más del 20 % de los chunks y que ningún árbol queda aislado.

**Datos del chunk** (`WorldChunk`, sustituye a `ChunkData`): capas `PackedByteArray` de 80×80 (`ground`, `level`, `cliff`, `decor`, `blocked`, `variant`), `occupant` (`PackedInt32Array`), `objects` (lista de `{kind, cell, size, variant}`), letreros, `hub`, `nujio_rect`, `has_villa` y el resto de lo que hoy tiene `ChunkData`. Son los mismos datos que `ZeldaChunk`, más la capa de variantes.

### 6. Rendimiento: cero tirones
**Objetivo**: ningún fotograma de más de 20 ms por culpa del mundo, ni al andar ni al correr, en el PC de referencia (el del dueño).

**Pregeneración al crear la partida.**
1. **Pasada de región** (≤ 1,5 s).
2. **Anillo inicial**: los chunks a ≤ 2 chunks de la villa natal (hasta 25), en `WorkerThreadPool` con `OS.get_processor_count() - 1` tareas a la vez. Pantalla "Creando el mundo…" con barra de progreso (`ui-ux-dev`). Objetivo: ≤ 3 s.
3. **Resto de la región en segundo plano** mientras se juega, con `max(1, núcleos - 2)` tareas a la vez y una **cola por prioridad** (distancia al jugador, que se recalcula al cambiar de chunk). Con 192 chunks a 80 ms y 2 hilos, son unos 8 s.
4. Nunca se llega a un chunk sin generar: el anillo de precarga es de 2 chunks (160 tiles; corriendo, más de 12 s) y un chunk tarda < 0,1 s. Si aun así pasara (PC muy lento), se genera en el acto con un aviso en el registro, y un test de rendimiento lo trata como fallo.

**Reglas de hilos.**
- Cada tarea crea sus propios `FastNoiseLite`, `RandomNumberGenerator` y `AStarGrid2D` (nada compartido y mutable).
- Solo lee el `RegionPlan`, que es inmutable tras la pasada de región.
- No toca el árbol de escena.
- Entrega el `WorldChunk` al hilo principal con `call_deferred` o con una cola protegida por `Mutex`.
- El resultado no depende del orden de ejecución. Un test genera la misma región en serie y en paralelo y compara byte a byte.

**Caché en disco.**
- Ruta: `user://world_cache/<world_key>/`, donde `world_key = hash(seed, region_id, generator_version, authoring_hash)`.
- Archivos: `region.bin` (el `RegionPlan`) y un `c_<x>_<y>.bin` por chunk. Cabecera con magia `NBW2`, versión y clave; las capas van con `var_to_bytes` sobre tipos simples (sin objetos) y se escriben con `FileAccess.open_compressed(..., COMPRESSION_ZSTD)`. Unos 5–8 KB por chunk (~1,5 MB por región).
- La caché es **derivable**: si falta o no coincide la clave (otro PC, Steam Cloud, versión nueva), se regenera igual que en una partida nueva. No va en el guardado ni en Steam Cloud.
- Limpieza: al guardar, `SaveManager` borra las cachés que no use ningún slot.
- Los **cambios del jugador** (frutales vaciados, refugios saqueados y, más adelante, las diferencias de la ADR 0005 #54) siguen en `GameState` como capa encima del chunk. Nunca se escriben en la caché.

**Streaming en juego** (`WorldStreamer`, en la escena de exploración):
- **En memoria**: los `WorldChunk` del chunk del jugador y sus 8 vecinos, leídos de la caché en un hilo (descomprimir ~1–2 ms) con un anillo de prefetch de 5×5.
- **Dibujados**: los sectores visibles más un margen de 1 sector, con histéresis de otro sector para no cargar y descargar en el límite. Unos 5×4 sectores.
- **Presupuesto del hilo principal**: ≤ 2 ms por fotograma para montar sectores (1 sector por fotograma; si hay cola, se monta antes el que va hacia donde se mueve el jugador). Los nodos de un sector se construyen **fuera del árbol** en el hilo de trabajo y el principal solo hace `add_child`. Si `TileMapLayer.set_cell` fuera del árbol no resulta seguro en hilos (se comprueba en el PR del streaming), se monta en el principal dentro del mismo presupuesto.
- Desaparecen el fundido de `TRANSITION_TIME`, el redibujado de 9 chunks y la franja de 12 casillas de los vecinos (`NEIGHBOUR_MARGIN`): el mundo es continuo.

**Presupuesto del generador y optimización del spike** (de ~450 ms a ≤ 80 ms por chunk; objetivo interno, 50 ms):
| Coste en el spike | Cambio |
|---|---|
| Ruido muestreado casilla a casilla desde GDScript (3+ ruidos × 6.400 casillas) | Bloques nativos con `FastNoiseLite.get_image()` (con `offset` en el origen del chunk) o filas cacheadas en `PackedFloat32Array` |
| `_raw_level` / `_level_macro` recalculan la elevación 5 veces por celda gruesa, con un `Dictionary` como caché y márgenes `PAD` por chunk | La altura gruesa se calcula una vez en la pasada de región |
| Literales de array dentro de bucles (`x in [C.FACE_TOP, ...]`) y `Vector2i` en bucles internos | Constantes, máscaras de bits e índices enteros |
| `_route` prueba todas las profundidades del tramo lateral | A\* sobre la rejilla gruesa (20×20), con los pesos montados una vez por chunk; MST de ≤ 8 nodos |
| Flood fills con `Array[Vector2i]` | Colas en `PackedInt32Array` |

- **Medición**: `tools/world/bench_chunks.gd` (50 chunks, seed 42: mediana y p95). Se ejecuta en la CI como aviso, no como fallo, porque las máquinas de CI varían.
- **Último recurso**, si no se llega a 80 ms: el `ChunkBuilder` en C# o GDExtension, con un ADR propio (el STACK permite C# "solo si un sistema lo exige por rendimiento").

**Límite de escala.** La pregeneración completa vale para regiones de hasta unos 400 chunks. Si una región futura es mayor, se pregenera por subregiones bajo demanda, con la misma caché. Necesitaría un ADR propio.

### 7. Impacto en lo existente
| Sistema | Qué pasa |
|---|---|
| `ChunkGenerator`, `ChunkData`, `PlaceholderTileset` (terreno) | Se sustituyen por `RegionPlan`, `ChunkBuilder` y `WorldChunk`, construidos **con nombres nuevos y en paralelo**, de modo que `main` sigue jugable. Los viejos se borran en el PR del cambio. Se reutilizan `Terrain` (elevación), `hash_ints` y la lógica de puertas. |
| `BosqueMap` | Se conservan el reparto, los estilos, los caminos y los refugios. Nuevo: Bosques clave desde la autoría, villas desde el CSV y el árbol de puertas por Bosque. |
| Bosques: límite, peaje, relación y memoria | Las reglas no cambian (ADR 0013, `bosques-y-relacion.md`). El límite pasa de "borde de chunk" a "casilla de otro Bosque" (§2). La recoloración por Bosque sigue (un atlas por Bosque). |
| Botarramas (`BotarramasPosts`) | Los puestos siguen en las puertas de los bordes entre Bosques, ahora con el nuevo trazado (y solo donde hay puerta). Si el jugador cruza fuera de una puerta (entre árboles), el choque con el límite lanza el mismo flujo de cruce y acude el Botarramas más cercano. `post_cell` se reescribe con `WorldChunk`. |
| Monstruos del mundo (`MonsterField`, `OverworldMonster`) | Movimiento continuo (§2). `MonsterSteering` no cambia. Se activan por los chunks activos. Los Únicos de la 0.3 (Ofomni perseguidores, Aledra nocturna, envíos del Bosque) se portan igual, porque su lógica está en casillas. |
| Frutales | Pasan a árboles 2×2. La clave de `FruitRules` y de `emptied_fruit_trees` (`Vector4i`: chunk y casilla) pasa a ser la **esquina noroeste** del objeto. El fruto se toma desde cualquier casilla vecina. |
| Nujio | Sprite de varias casillas en el nodo con orden en Y; su zona se aplana a un nivel. Para los Bosques clave, el Nujio va donde diga el CSV. |
| Villas | Las villas con nombre salen del CSV; su trazado (casas 4×3, plaza, huertos) es procedural. La plaza sigue siendo refugio (`AdventureRules.is_villa_rest`). |
| Letreros | La misma lógica (hacia la villa del Bosque y hacia la villa natal por el camino), colocados junto al camino de 3. |
| Refugios | El reparto no cambia. La colocación prefiere una cueva en una cara de risco y, si no hay, un árbol hueco. `is_refuge` pasa a mirar el objeto. |
| NPC (`npc.gd`) | Posición en `world_pos`; se habla con el sondeo (§2). |
| Mapa M (`MapLogic`, `region_map`) | Sigue por chunks. Mejora: puede dibujar una vista de la región a partir del `RegionPlan` (altura, agua, Bosques, caminos) en lugar de cuadros de color. |
| Brújula | Los objetivos pasan a `world_pos`, que es más preciso. `objective_chunk` + `objective_cell` se conservan en el guardado. |
| Exploración (`exploration.gd`) | Es el cambio mayor: escena nueva con `WorldStreamer`, el jugador con `GridMover` y la cámara sin transiciones. La lógica de interacción, el riutash, la luz de luna y los combates se mueven tal cual. |
| `PlayerWalker` | Se sustituye por `PlayerController` (nodo) + `GridMover` (lógica). Se conservan la hoja de sprites, el contorno y el placeholder. |
| Guardado | Ver abajo. |
| UI | Sin cambios, salvo la pantalla de "Creando el mundo…" y la vista del mapa M. |
| Tests | Ver abajo. |

**Guardado.**
- `SAVE_VERSION` sube a la siguiente versión libre cuando entra el Mundo 2.0 (hoy es 13; la 0.3 puede subirla antes).
- Claves nuevas: `generator_version` (= 2), `world_key` y `player_facing`.
- **Migración: las partidas anteriores al Mundo 2.0 no se cargan.** Las coordenadas de chunk y casilla, los ids de Bosque, los frutales, los refugios saqueados, los monstruos vistos y los objetivos dependen del mundo viejo, y escalarlos daría posiciones dentro de rocas o en otros Bosques.
- `SaveManager` detecta `save_version` < la nueva y devuelve un error propio (`ERR_SAVE_OLD_WORLD`). El menú muestra: "Esta partida es de una versión anterior del mundo y no se puede continuar. Empieza una partida nueva." (texto en `sistema.json`), y el `CHANGELOG` de la 0.4 lo avisa.
- Mientras el juego no esté publicado (0.x) es aceptable. Desde la 1.0, todo cambio de generador necesitará migración o conservar el generador viejo.
- Opción a decidir por el dueño: conservar al adoc (nivel, XP, Luz, inventario, fama) en una partida nueva (ver preguntas).

**Tests (GUT).**
- Se rehacen: `test_chunk_generator`, `test_roads`, `test_refuges`, `test_fruit_trees` y `test_terrain_tileset`, sobre `ChunkBuilder` y `RegionPlan`.
- Se ajustan: `test_bosque_map` (Bosques clave), `test_interaction` (sondeo y objetos de varias casillas), `test_signpost`, `test_monsters` (movimiento continuo; la lógica de `MonsterSteering` no cambia) y `test_game_state` (versión y rechazo de partidas viejas).
- Nuevos:
  - `test_grid_mover`: deslizamiento, esquinas, diagonales bloqueadas, velocidad constante en diagonal, `cell_changed`.
  - `test_relief`: niveles conectados solo por escaleras o rampas, cascadas.
  - `test_region_authoring`: colores, validación, lugares.
  - `test_world_cache`: ida y vuelta byte a byte, clave distinta, caché corrupta.
  - `test_region_plan`: determinismo; Bosques conexos a pie; red de senderos conexa; puntos de interés distintos; hub no central; sin árboles sueltos.
  - Determinismo en serie frente a en paralelo.
- `bench_chunks` como aviso en la CI.

### 8. Relación con otros ADR
| ADR | Queda |
|---|---|
| 0002 | Vigente. "Top-down" = cenital 3/4 con relieve. |
| 0003 | **Ampliado.** El mapa mundial sigue siendo la guía, y ahora además hay **autoría por región** (PNG + CSV). "Se genera con seed + region_id" pasa a ser "la región se pregenera entera con `seed + region_id + autoría`". |
| 0004 | **Sustituido en el tamaño del chunk**: 80×80 (antes 64×64), con permiso del dueño. Derrota y modos, vigentes. |
| 0005 | **Ampliado.** Los lugares ya no "se generan al entrar": la región se genera al crear la partida y se cachea. Lo esencial sigue: distinto en cada partida, igual al volver, persistencia de los cambios del jugador. Las villas con nombre y los lugares clave son ahora fijos entre partidas. |
| 0006 | **Sustituido en**: terreno base (relieve en niveles en vez de afloramientos), senderos (red en vez de X), hub (no central), tamaño, "los tiles no se guardan" (siguen sin ir en el guardado, pero se cachean en disco) y la escena con franja de vecinos. **Vigente en**: identidad y determinismo por hash, `hash_ints`, `BosqueMap` (reparto, estilos, caminos, refugios), frutales (reglas) y letreros (reglas). |
| 0007 | Vigente: Bosques de 4–16 chunks (más grandes al ser chunks de 80; `game-designer` revisa el riutash). |
| 0012 | Vigente. `GridMover` se mueve en `_physics_process` y el `WorldStreamer` monta sectores por presupuesto: son las dos excepciones nuevas a "nada en `_process`", porque dependen del fotograma por naturaleza. |

## Consecuencias
- La 0.4 entera es el Mundo 2.0. Las dinámicas de la 0.3 se hacen sobre el mundo viejo y se portan; para que el porte sea barato, la lógica nueva de la 0.3 (sigilo, visión, Únicos, estados de Bosque) debe quedar en clases puras que trabajen con casillas e ids de Bosque, no con la escena ni con `ChunkData`.
- `docs/STACK.md` y `docs/CONVENCIONES.md` cambian: escala, coordenadas y movimiento. Lo nuevo rige **desde el PR del cambio** (M17 de la hoja de ruta); hasta entonces sigue el movimiento por casillas.
- `game-designer` reequilibra tiempos de viaje, riutash y densidad de refugios para chunks de 80 y movimiento libre, y fija los pesos de los puntos de interés y las velocidades.
- `pixel-artist` escribe la spec de relieve, objetos de varias casillas y decoración variada antes del arte final. El arte del spike (`tools/art/make_tiles_zelda.py`) se trae como placeholder.
- El dueño tiene una tarea propia: pintar el Valle del Sara y rellenar el CSV de lugares. El juego funciona sin ella (con las PNG exportadas del generador actual).
- Cambiar la autoría tras publicar cambia los mundos de las partidas guardadas (`authoring_hash`). Desde la 1.0 hará falta versionar la autoría o migrar posiciones (al hub más cercano).
- El determinismo sigue dependiendo de `FastNoiseLite` entre versiones de Godot; ahora hay menos ruido en juego, porque la geografía grande es autoría.
- Riesgo pendiente del ADR 0006: el dueño dijo en la v2 que las terrazas rectas "se notan muy falsas". Las caras de Z son rectas en tramos cortos (4 tiles) y con extremos redondeados. Si no le convencen, la spec de arte añade esquinas interiores y tramos diagonales.

---

## Anexo: propuesta original del spike (2026-10-24)
> Texto de `docs/decisions/0014-propuesta-mapa-estilo-zelda.md` en la rama local `spike/mapa-estilo-zelda`, copiado sin cambios salvo el nivel de los títulos. Las capturas y los GIF (`comparacion_*.png`, `andar_*.gif`) y el código (`scripts/spike/`, `scenes/spike/`, `tools/art/make_tiles_zelda.py`, `tools/art/make_iso_test.py`, `assets/tilesets/spike/`) siguen en esa rama.

### Mapa "estilo Zelda" con relieve en capas (y prueba isométrica)

> **Estado: PROPUESTA.** No hay nada integrado. Prototipo comparativo en la rama `spike/mapa-estilo-zelda` (sin push), código aislado en `scripts/spike/`, `scenes/spike/`, `tools/art/make_tiles_zelda.py`, `tools/art/make_iso_test.py` y `assets/tilesets/spike/`. El juego no se toca. Decide el dueño; implementan `engine-architect`, `world-gen-dev`, `pixel-artist` y los agentes de dominio.

#### Contexto
El dueño, tras jugar la 0.3 (2026-10-24):

> "siento el mapa muy plano y la jugabilidad un poco tosca. Que te parece si traes como referencia la forma de hacer mapas de legend of zelda. Quizas asi se vea mucho mejor el mapa. Podemos aumentar un poco el tamaño de los chunks y asi escalar mejor los graficos. Porque esta todo muy diminuto y comprimido."

> "zelda con relive en capas pero quisiera probar el isometrico, solo para ver si hay mejoras o se siente diferente. Qizas le da un mejor toque y mas fluidez al juego, no lo sé. provemos". (Quiere más sensación de relieve: montañas, colinas.)

> "el estilo de creación de mapa, se ve muy repetitivo y se nota el patrón utilizado en forma de X y fractal".

Diagnóstico del estado actual (ADR 0006, `ChunkGenerator`):
- **Diminuto y comprimido**: árboles de 1×1 que bloquean, repartidos por ruido casilla a casilla. Cada casilla es una decisión distinta y el ojo ve "grano".
- **Plano**: el risco es un afloramiento de una casilla con una cara de 5–8 px; no hay niveles ni forma de subir.
- **La "X"**: cada chunk talla un sendero desde cada uno de sus 4 bordes hasta el hub, que es el **centro** del chunk (con un claro redondo). Visto el mapa entero, es una rejilla de estrellas de 4 brazos, una por chunk (`comparacion_composicion.png`, columna izquierda).
- **El "fractal"**: bosque, claros, pedregal y huecos salen de ruido (FBM) muestreado por casilla, más un hash por casilla para los huecos. El mismo patrón a todas las escalas y en todas partes.

Referencia Zelda (ALttP, Link's Awakening, Minish Cap): pantallas compuestas con formas grandes (muros de árboles de 2×2, rocas de 2×2, casas de 4×3), relieve en niveles con caras de acantilado y escaleras, decoración que no estorba, hitos para orientarse y caminos que se notan.

#### Opciones prototipadas
Seed 42, Valle del Sara, los mismos chunks en las tres columnas. Capturas en ventana (320×180) en la hoja de comparación (ver "Material").

##### Opción Z — "Zelda con relieve en capas" (cenital 3/4, 320×180, tile de 16 px)
Lo que hace el prototipo (`ZeldaGenerator`, `ZeldaChunk`, `ZeldaView`, escena `scenes/spike/zelda_relief.tscn`, jugable):

**Chunk de 80×80** (hoy 64×64). Medido: 80 casillas = 4 pantallas de ancho (hoy 3,2) y 7,1 de alto; cruzarlo andando son 12,8 s (hoy 10,2 s). Con objetos de 2×2 hay la mitad de "decisiones" por casilla, así que hace falta algo más de superficie para que quepan una villa, 2–3 puntos de interés y relieve. 96 se hace largo (15,4 s por chunk; los Bosques de hasta 16 chunks serían enormes y habría que reequilibrar el riutash). El ruido de la región se muestrea escalado (64/80), así que montañas y río caen en los mismos chunks que hoy.

**Relieve en capas**
- La altura sale de la **misma elevación** de `ChunkGenerator.Terrain` (gradiente norte-sur + ruido), cuantizada en 4 niveles (0–3) con umbrales `-0.1 / 0.32 / 0.62` sobre una rejilla gruesa de 4×4 casillas, sin celdas sueltas. Resultado: colinas sueltas en el centro y el sur, mesetas y montañas en el norte.
- Cada salto de nivel hacia el sur es una **cara de risco de 2 filas por nivel** (16 px × 2 = 32 px de alto por nivel, con labio de hierba, lajas y base oscura) y **sombra** al pie. Hacia el norte, el este y el oeste, un **borde** (pared lateral o labio). Caras y bordes bloquean.
- **Colisión por nivel**: no hay casilla transitable entre dos niveles salvo **escaleras** (un sendero que cruza una cara: la columna entera de la cara se vuelve escalera) y **rampas** (un sendero que cruza un borde lateral o norte).
- **Cascadas**: donde el río o un arroyo cruza una cara, la cara se dibuja como agua que cae (con espuma).
- Las montañas son formas grandes: mesetas de varios niveles con rocas de 2×2 y menos bosque (se quitan rodales enteros, no árboles sueltos).

**Composición por formas grandes (respuesta al "fractal")**
- Bosque en **manchas de 2×2**: un árbol de 2×2 por celda gruesa, con ruido de baja frecuencia y sin celdas sueltas (necesita 4 vecinos de bosque). Desaparece el grano de 1×1.
- **Puntos de interés** por chunk (2–3, o 1 junto a una villa/Nujio), elegidos con el RNG del chunk entre tipos distintos y pesos según la latitud (más colinas al norte, más lagunas y praderas al sur), en posiciones al azar, nunca en el centro fijo:
  - *laguna* (unión de 3 elipses con orilla de claro), *hito* (árbol de 3×3 en un claro irregular), *colina* (meseta estampada de un nivel más, con un árbol hito encima y escalera por su cara sur), *círculo de piedras* (6 rocas de 2×2), *pradera de flores*, *arboleda* (rodal denso de árboles 2×2 con un hueco dentro).
- Decoración que no bloquea (flores en manchas de pradera, matas, piedrecitas; tocones y setas raros). El tocón sí bloquea.
- Rocas de 2×2 en el pedregal del terreno actual y en la montaña.

**Red de senderos (respuesta a la "X")**
- **Puertas**: un borde tiene sendero si lleva camino principal o, si no, con probabilidad 70 % (decisión compartida por los dos chunks del borde). No todos los chunks tienen 4 puertas, y la posición de cada puerta en su borde sigue siendo un hash del borde.
- **Nodos**: puertas + puntos de interés + el ancla (el primer punto de interés, o la plaza en el chunk de villa). El **hub** del chunk deja de ser el centro: es ese ancla.
- **Árbol de expansión mínimo** (Prim) entre nodos, con las aristas entre puertas de camino a mitad de precio (el camino principal va primero). Salen Y, cadenas y ramales, no estrellas.
- Cada arista se traza con **A\*** (`AStarGrid2D`) sobre la rejilla gruesa de 4×4: agua, caras, bordes, casas y Nujio cuestan; un ruido suave curva el trazado; lo ya trazado abarata, así los senderos se juntan. Tramos rectos de 4 casillas como mínimo, alineados con los riscos (las escaleras los cruzan de frente).
- Caminos de **3 casillas** y senderos de 2, con puente sobre el agua.

**Cámara y arte**: igual que hoy (320×180, escala entera, tile de 16, `Camera2D` sin zoom). Objetos de varias casillas como `Sprite2D` en un nodo con orden en Y junto al jugador; suelo y riscos en un canvas por chunk. Arte de prueba por script (`make_tiles_zelda.py`): árboles 2×2 en las 6 formas (+ frutal, vaciado y hueco), árbol hito 3×3, rocas 2×2, 8 decoraciones, riscos (caras de 2–3 filas con extremos, escaleras, bordes, rampas, sombra, cueva 2×2, cascada), casas 4×3 en barro y piedra. Usa las claves de color de `TerrainTileset` (se recolorea por Bosque) más **una clave nueva**: sombra de hoja (`3a4466`), con una tabla de 12 sombras de la paleta.

##### Opción I — prueba isométrica (pequeña, solo para sentirla)
`scenes/spike/iso_test.tscn`: los **mismos datos** de Z (un chunk de `ZeldaGenerator`; solo cambia el dibujo) en un `TileMapLayer` isométrico (rombos de 32×16, `TILE_LAYOUT_DIAMOND_DOWN`), con altura en **bloques apilados** de 16 px por nivel (caras laterales clara y oscura) y **orden en Y** (`y_sort_enabled` en el `TileMapLayer` y en el padre; árboles, rocas, casas, Nujio y Adoc como hijos ordenados). Arte por script (`make_iso_test.py`: 9 materiales × 4 alturas); árbol, rocas y casas reutilizan los de Z; el Adoc reutiliza su hoja (frente, espalda y lados) en las 4 diagonales.
- **Control** (documentado en la escena): W = casilla de arriba de la cuadrícula, que en pantalla va **arriba-derecha**; D = derecha → **abajo-derecha**; S = abajo → **abajo-izquierda**; A = izquierda → **arriba-izquierda**. Es el mapeo "rotado 45°" de los juegos isométricos por casillas. La alternativa (W = arriba en pantalla) obliga a pasos diagonales de dos ejes o a movimiento libre: no es "por casillas".
- **Colisión por nivel**: en isométrico la cara del risco es el lado del bloque; se pasa entre casillas del mismo nivel o a uno contiguo por escalera o rampa (las de Z).

#### Comparación

| | Actual (0.3) | Z: Zelda con relieve | I: isométrico |
|---|---|---|---|
| Sensación de relieve | Plano | Clara en las caras sur (32 px por nivel, sombra); los bordes este/oeste se leen menos | **La más fuerte**: cada salto se ve como un bloque |
| Legibilidad a 320×180 | Grano de 1×1, "diminuto" | Formas grandes, se lee bien; unas 20×11 casillas visibles | Mismo área (≈225 casillas) pero en rombo: se ve menos hacia delante en los ejes; los objetos altos tapan al jugador (hará falta transparencia o silueta) |
| Control | WASD = ejes | Igual que hoy | WASD sobre diagonales: hay que aprenderlo; con mando, mejor |
| "X" y "fractal" | Sí | Resueltos (red + puntos de interés + manchas) | Igual que Z (mismos datos) |
| Generación (GDScript, por chunk) | ~60 ms (64×64) | **~450 ms** (80×80) en el prototipo: hay que optimizar | Igual que Z |
| Arte nuevo | — | Objetos 2×2/3×3/4×3, riscos con altura, decoración | **Todo** de nuevo en isométrico |

Tiempos medidos en el prototipo (`scripts/spike/dump_chunk.gd`): 306 ms a 64, 448 ms a 80 y 665 ms a 96. El coste está en el muestreo por casilla y en los pesos del A\*; con caché por fila de ruido, el A\* por celda gruesa ya montado una vez y generación en hilo (o precarga de vecinos) debería volver a < 100 ms. Sin eso, entrar en un chunk (que genera el chunk y sus 8 vecinos) se congelaría unos segundos.

#### Qué cambia y qué se rompe

##### Opción Z
| Sistema | Qué pasa |
|---|---|
| `ChunkData` | Pasa de un byte por casilla a **capas**: suelo, nivel, risco, decoración, objetos de varias casillas, colisión derivada. `SIZE` = 80. `BLOCKING` deja de bastar: la colisión es `blocked[]` + nivel. |
| `ChunkGenerator` | Se reescribe sobre la base de `ZeldaGenerator` (relieve, red, puntos de interés). Se conservan `Terrain` (elevación, río, vados), `hash_ints`, `gate_index`, la red de caminos de `BosqueMap` y el reparto de refugios. |
| Bosques (`BosqueMap`) | Sin cambios: reparto, estilos, villas, Nujio, caminos, refugios. Si las puertas pasan a ser opcionales (70 %), hace falta un árbol de expansión de bordes por Bosque (como los caminos) para garantizar que todo el Bosque se recorre a pie. |
| Nujio | Igual (centro del chunk, sprite procedural). La zona se aplana a un nivel. |
| Villa | Casas de 4×3 con vano y huerto; plaza más pequeña; los caminos rodean casas y Nujio. |
| Frutales | Pasan a árbol 2×2. `FruitRules` usa la casilla como clave: pasa a la esquina del objeto; se toma el fruto desde cualquier casilla vecina del objeto. |
| Letreros | Igual (1×1 junto al camino de 3); colocación según el nuevo trazado. |
| Refugios | Preferencia nueva: **cueva en una cara de risco** (2×2, la boca se pisa); si no hay, árbol hueco 2×2 junto a un sendero. `is_refuge` y el reparto de `BosqueMap` no cambian. |
| Botarramas / `MonsterField` | La rejilla sigue siendo de casillas: `area_walkable` y el steering funcionan con `is_walkable`. Hay que ajustar márgenes (`NEIGHBOUR_MARGIN`) y que los monstruos respeten niveles (ya lo hacen si consultan `is_walkable`). |
| `PlayerWalker` | Usa `ChunkData.in_bounds`: vale con el nuevo `SIZE`. La escalera no necesita lógica nueva (es transitable). |
| `Interaction` | Buscar objetos de varias casillas (frutal 2×2, árbol hueco, cueva). |
| Mapa M (`MapLogic`, `region_map`) | Trabaja por chunks: sin cambios. Si algún día dibuja casillas, se adapta. |
| Guardado | Los tiles no se guardan (ADR 0006). `player_cell` cambia de rango (0–79): **`SAVE_VERSION` 3** con migración (escalar la casilla ×80/64, o mandar al jugador al hub del chunk). |
| Tests | Se rehacen los de mundo (`test_chunk_generator`, accesibilidad, refugios, frutales, continuidad entre chunks) y se añaden: niveles solo conectados por escaleras/rampas, red conexa, puntos de interés distintos, determinismo de la red y de las cascadas. |
| UI | Sin cambios (HUD en capa ≥ 2). |
| Rendimiento | Optimizar la generación (ver arriba). |

##### Opción I (además de todo lo de Z, porque usa sus datos)
| Sistema | Qué pasa |
|---|---|
| Dibujo | Nuevo: `TileMapLayer` isométrico con bloques apilados y orden en Y; conversión casilla → pantalla (`map_to_local`) para jugador, NPC, monstruos, Nujio, letreros, marcadores de brújula y mapa, efectos. |
| Arte | **Todo de nuevo**: rombos de cada suelo con sus transiciones (las máscaras de borde en rombo son más difíciles), lados de bloque por material, agua y puentes en 2 orientaciones, casas y Nujio en isométrico, y **todos los personajes en 4 diagonales** (Adoc, sfida, Botarramas, Ofomni) y los Únicos procedurales (`UnicoArt`) en isométrico. |
| Control | Input en diagonales (ver arriba) y textos de ayuda. |
| Legibilidad | Oclusión: los árboles y casas tapan al jugador; hace falta silueta o transparencia. |
| Lo demás | Igual que Z. |

#### Esfuerzo estimado (en PR)
| | Código | Arte | Total |
|---|---|---|---|
| **Z** | 8: (1) `ChunkData` en capas + `SAVE_VERSION` 3; (2) relieve, caras, escaleras, rampas, cascadas + tests; (3) puntos de interés y formas + tests; (4) red de senderos con puertas opcionales y conexión del Bosque + tests; (5) dibujo por capas y objetos con orden en Y; (6) frutales 2×2, refugio-cueva, `Interaction`; (7) Botarramas, letreros, villa; (8) rendimiento | 4: spec + árboles 2×2 (6 formas, frutal, hueco) y hito 3×3; riscos completos (caras, esquinas interiores, escaleras, rampas, cascada animada, cueva); casas 4×3, puente de 3, decoración; repaso de paleta | **~12** |
| **I** | Los 8 de Z menos (5), más 5: dibujo isométrico y apilado; conversión de posiciones de todo lo que se dibuja; input y cámara; oclusión; ajustes de UI/brújula | 7–8: suelos en rombo con transiciones; bloques por material; agua/puentes; casas y Nujio; Adoc en 4 diagonales; NPC y monstruos; Únicos procedurales | **~19–20** |

#### Recomendación
**Opción Z**, con la composición nueva (red de senderos entre puertas y puntos de interés, formas grandes) como parte del mismo cambio.
- Resuelve las tres quejas: deja de verse diminuto (objetos de 2×2 y 3×3, caminos de 3), gana relieve (niveles, caras de 32 px, escaleras, cascadas) y quita la X y el grano del ruido.
- No toca la cámara, la escala entera, la UI ni el control, y conserva todo el modelo de mundo (Bosques, caminos, refugios, Nujio, seed).
- El isométrico se **siente distinto** y, honestamente, **lee mejor el relieve** (ver `comparacion_principal.png`, fila de riscos), pero cuesta casi el doble, obliga a rehacer todo el arte (incluidos los Únicos procedurales y 4 diagonales por personaje) y cambia el control a diagonales. "Más fluidez" no sale del isométrico en sí: el movimiento sigue siendo por casillas igual que en Z.
- Lo que conviene **tomar del isométrico** para Z: que los bordes este/oeste de las mesetas se lean como pared (más anchos y con sombra proyectada hacia el este) y, si se quiere más, una sombra de nivel (las mesetas altas con la hierba un tono más clara). Se puede probar sin cambiar de vista.

Riesgo a confirmar con el dueño: en la v2 dijo que las terrazas rectas "se notan muy falsas" (ADR 0006). En Z las caras son rectas a propósito, como en Zelda, pero en tramos cortos (rejilla de 4) y con extremos redondeados; si no le convence, la opción es esquinas interiores y tramos diagonales en el arte de riscos (1 PR de arte más).

#### Material del spike
- Hojas: `comparacion_principal.png` (actual / Z / I en villa natal y riscos del norte), `comparacion_lugares.png` (puente y borde entre Bosques, actual frente a Z), `comparacion_composicion.png` (3×3 chunks: la X y el ruido actuales frente a la red de Z). GIF: `andar_a.gif`, `andar_z.gif` (subir una escalera), `andar_i.gif`.
- Probar: `godot --path <worktree> res://scenes/spike/zelda_relief.tscn` (WASD, Shift, 1–4 para saltar a los lugares, cruza chunks por los bordes) y `godot --path <worktree> res://scenes/spike/iso_test.tscn` (W/D/S/A sobre los ejes isométricos, 1 riscos, 2 villa).
- Capturas automáticas: `sh tools/spike_capture.sh <carpeta>`.
- Los tests GUT no se han ejecutado en la rama (GUT no está instalado en el worktree); el spike no modifica ningún script del juego.

#### Consecuencias (si se aprueba Z)
- ADR 0006 queda parcialmente sustituido (terreno base, senderos, hub, riscos, tamaño del chunk) y ADR 0004 (64×64) también.
- `docs/STACK.md` no cambia (320×180, tile de 16, escala entera).
- `game-designer` reequilibra tiempos de viaje y riutash para chunks de 80 y fija los pesos de los puntos de interés; `pixel-artist` escribe la spec de riscos con altura y objetos de varias casillas antes del arte final.
