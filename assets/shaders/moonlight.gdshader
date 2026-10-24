shader_type canvas_item;
// Luz de luna del Momento de Riumna (ADR 0012): post-proceso sobre la capa del mundo, por debajo
// del HUD. Look plateado, no noche negra: desplaza el tono hacia un plata frío, apaga la saturación
// de los tonos medios, conserva o realza los claros (agua, caminos, hojas claras) y oscurece un
// poco las sombras. Saca colores fuera de la paleta de 32: excepción aceptada en el ADR 0012
// (iluminación, no arte). Valores por defecto = data/world/time.json ("moonlight").

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// 0 = día (sin efecto), 1 = noche completa. Se anima en la transición entre Momentos.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
// Tono plateado frío hacia el que se desplaza la imagen (8b9bb4 de la paleta).
uniform vec3 tint : source_color = vec3(0.545, 0.608, 0.706);
// Cuánto se desplaza el tono hacia `tint`, conservando la luminancia (0 = nada, 1 = monocromo).
uniform float tint_strength : hint_range(0.0, 1.0) = 0.5;
// Cuánta saturación se quita en los tonos medios (0 = nada, 1 = gris).
uniform float midtone_desaturation : hint_range(0.0, 1.0) = 0.5;
// Brillo de los tonos medios (1 = sin cambio).
uniform float midtone_level : hint_range(0.0, 1.5) = 0.9;
// Luminancia a partir de la que un color cuenta como claro y se realza.
uniform float highlight_threshold : hint_range(0.0, 1.0) = 0.6;
// Multiplicador de brillo de los claros (1 = conservar).
uniform float highlight_boost : hint_range(0.5, 2.0) = 1.15;
// Luminancia por debajo de la que un color cuenta como sombra.
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.3;
// Brillo de las sombras más oscuras (1 = sin cambio).
uniform float shadow_level : hint_range(0.0, 1.0) = 0.75;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = luma(c);
	// Máscara de tonos medios: 1 en el centro de la luminancia, 0 en los extremos.
	float mid = 1.0 - abs(l * 2.0 - 1.0);
	vec3 desat = mix(c, vec3(l), midtone_desaturation * mid);
	// Desplazamiento de tono hacia el plateado con la misma luminancia.
	vec3 silver = l * tint / max(luma(tint), 0.001);
	vec3 shifted = mix(desat, silver, tint_strength);
	// Claros realzados; medios algo apagados; sombras más oscuras.
	float hi = smoothstep(highlight_threshold, 1.0, l);
	float sh = 1.0 - smoothstep(0.0, shadow_threshold, l);
	float level = mix(midtone_level, highlight_boost, hi) * mix(1.0, shadow_level, sh);
	vec3 night = clamp(shifted * level, 0.0, 1.0);
	COLOR = vec4(mix(c, night, intensity), 1.0);
}
