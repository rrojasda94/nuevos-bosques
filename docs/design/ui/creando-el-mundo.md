# UI: pantalla "Creando el mundo…"

> Dueño: `ui-ux-dev`. Motivo: ADR 0014 §6 (pregeneración al crear la partida, anillo inicial ≤ 3 s). Código: `scenes/ui/world_loading.tscn` + `scripts/ui/world_loading.gd`. Lógica que sigue: `WorldPregen` (`scripts/world/world_pregen.gd`). Se enchufa al flujo de partida en M17.

## Posición (320×180)
```
+--------------------------------------------------------------+
|                                                              |
|                                                              |
|                      Creando el mundo…                       |  <- TitleLabel, y 70
|          [#################.......................]          |  <- barra 160×6, x 80–240, y 88
|            Preparando los alrededores de tu villa            |  <- HintLabel, y 100
|                                                              |
|                                                              |
+--------------------------------------------------------------+
```
- Fondo opaco a pantalla completa (`MapPanel` del tema), capa 2: tapa la escena y la luz de luna.
- La barra mide el **anillo inicial** (hasta 25 chunks alrededor de la villa natal), no la región entera: el resto se genera en segundo plano mientras se juega.
- Barra dibujada al píxel: marco blanco `ffffff` de 1 px, fondo `262b44` y relleno `fee761` (el dorado de `TitleLabel`), con ancho entero. Sin porcentaje ni números: con ≤ 3 s no hacen falta.
- Textos en `data/text/sistema.json`: `world_loading_title`, `world_loading_hint`.
- Sin entrada del jugador: no hay nada que pulsar. Cuando el anillo termina, la pantalla emite `finished` y quien la abrió la quita.

## Pendiente
- Cuando el tema central tenga estilo de `ProgressBar`, la barra pasa a ser un `ProgressBar` normal con ese estilo.
