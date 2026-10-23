# Guía de estilo visual — Nardaram

- Paleta: `assets/palettes/palette_nuevos_bosques.gpl` (32 colores). Sin excepciones.
- Resolución lógica 320×180. Tile 16×16.
- Personajes: 16×16 ciudadanos, 16×24 héroes. Outline 1 px en tono oscuro de la rampa.
- Perspectiva: **top-down 3/4** (estilo Zelda 2D). Fachadas de edificios visibles; techos ocupan ~60 % del sprite.
- Luz: fuente arriba-izquierda. Sombras con un tono de la rampa, nunca negro.
- Prohibido: anti-aliasing, degradados, alpha parcial, rotación libre.
- Hay artista humano. Mientras no llega un asset, `pixel-artist` genera un placeholder `[PLACEHOLDER]` con la misma spec (tamaño, frames) para no bloquear a los devs.
- Cada región del mapa mundial tiene su tileset con la misma paleta pero distinta rampa dominante (ver `docs/art/specs/tilesets.md` cuando exista).
