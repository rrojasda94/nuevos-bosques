shader_type canvas_item;
// Copas que se mecen (docs/art/direccion-de-arte.md, "Movimiento sutil"): desplaza 1 px a los lados
// las filas altas de cada casilla, en píxeles enteros y sin salir de la casilla del atlas. Cada
// casilla va con su propio desfase para que el bosque no se mueva en bloque.

// Velocidad del vaivén (radianes por segundo).
uniform float speed : hint_range(0.0, 4.0) = 0.9;
// Filas de arriba de la casilla que se mueven (la copa); las de abajo (tronco) quedan quietas.
uniform float canopy_rows : hint_range(0.0, 16.0) = 11.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
	vec2 origin = floor(px / 16.0) * 16.0;
	vec2 tile = floor(world / 16.0);
	// round(sin) da -1, 0 o 1: casi siempre quieto, a ratos un píxel a un lado o al otro.
	float shift = round(sin(TIME * speed + tile.x * 0.7 + tile.y * 0.3));
	if (px.y - origin.y >= canopy_rows) {
		shift = 0.0;
	}
	px.x = clamp(px.x - shift, origin.x, origin.x + 15.0);
	COLOR = texture(TEXTURE, (px + 0.5) * TEXTURE_PIXEL_SIZE);
}
