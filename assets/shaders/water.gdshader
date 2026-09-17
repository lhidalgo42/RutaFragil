shader_type spatial;
render_mode cull_disabled;

// Agua de fuente y de canal (D76). Antes el agua era un cilindro pintado de azul: «parece
// una pintura, no agua cayendo», dijo el dueño. Aquí dos capas del mismo ruido se
// desplazan en direcciones distintas: el gradiente del ruido mueve la normal (el brillo
// baila) y las crestas sacan espuma. `flow` cambia el modo: 0 es superficie quieta con
// ondas en espacio mundo; 1 es un chorro, y el patrón corre hacia abajo por las UV.

uniform sampler2D noise_map : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 shallow : source_color = vec3(0.4, 0.66, 0.7);
uniform vec3 deep : source_color = vec3(0.1, 0.28, 0.36);
uniform float speed = 0.35;
// Metros por repetición del ruido en la superficie.
uniform float scale_m = 1.6;
// 0 = agua quieta con ondas; 1 = chorro que cae.
uniform float flow : hint_range(0.0, 1.0) = 0.0;
uniform float ripple : hint_range(0.0, 2.0) = 0.7;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 base = v_world.xz / max(scale_m, 0.01);
	// el chorro corre hacia abajo: UV.y crece hacia abajo en la caja del hilo
	vec2 fall = vec2(UV.x * 2.0, UV.y * 4.0 + TIME * 1.8);
	vec2 uv1 = mix(base + vec2(TIME * speed * 0.7, TIME * speed * 0.4), fall, flow);
	vec2 uv2 = mix(base * 1.7 - vec2(TIME * speed * 0.5, -TIME * speed * 0.6), fall * 1.3 + vec2(0.3, 0.0), flow);
	float n1 = texture(noise_map, uv1).r;
	float n2 = texture(noise_map, uv2).r;
	float h = (n1 + n2) * 0.5;

	vec3 colour = mix(deep, shallow, smoothstep(0.35, 0.8, h));
	// espuma en las crestas; más en el chorro, que va roto
	colour += vec3(0.3) * smoothstep(0.76, 0.9, h) * (0.4 + 0.6 * flow);
	ALBEDO = colour * COLOR.rgb;
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
	METALLIC = 0.0;

	// normal desde el gradiente del ruido: con eso el sol se refleja moviéndose
	float e = 0.012;
	float dx = texture(noise_map, uv1 + vec2(e, 0.0)).r - n1;
	float dy = texture(noise_map, uv1 + vec2(0.0, e)).r - n1;
	NORMAL_MAP = normalize(vec3(-dx * ripple * 18.0, -dy * ripple * 18.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
