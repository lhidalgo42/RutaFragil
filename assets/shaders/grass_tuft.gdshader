shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

// Mata de pasto (D64, rehecha en D78). La primera versión recortaba un triángulo por
// shader sobre un quad sin textura: «el pasto se ve triangular», dijo el dueño, y sí.
// Ahora cada tarjeta lleva una mata PINTADA (assets/textures/grass/grass_clump.png,
// hojas finas y curvas con degradado) recortada por alfa. Sigue el viento y la flexión
// alrededor de `bus_position`, que GrassStrip entrega por cuadro. Peso de altura = UV.y
// invertida (la textura tiene la raíz abajo, v=1).

uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 bus_position = vec3(0.0, -100.0, 0.0);
uniform vec3 base_colour : source_color = vec3(0.22, 0.42, 0.18);
uniform vec3 tip_colour : source_color = vec3(0.55, 0.75, 0.3);
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.4;
uniform float bend_radius = 2.6;
uniform float bend_strength = 0.9;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.55;   // D82: corta el borde oscuro de la foto de pasto

varying float v_h;
varying vec3 v_tint;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// la raíz está en v=1 de la textura: la altura crece hacia v=0
	float h = 1.0 - UV.y;
	v_h = h;
	v_tint = COLOR.rgb;
	float phase = world.x * 0.7 + world.z * 0.9;
	float sway = sin(TIME * wind_speed + phase) * wind_strength * h * h;
	vec2 away = world.xz - bus_position.xz;
	float d = length(away);
	float bend = clamp(1.0 - d / bend_radius, 0.0, 1.0) * bend_strength * h;
	vec2 dir = d > 0.001 ? away / d : vec2(1.0, 0.0);
	world.x += sway + dir.x * bend;
	world.z += sway * 0.6 + dir.y * bend;
	world.y -= bend * 0.35 * h;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}

void fragment() {
	vec4 tex = texture(grass_tex, UV);
	if (tex.a < alpha_cut) {
		discard;
	}
	// el color pintado ya trae el degradado raíz→punta; base/tip lo tiñen para que un
	// potrero seco y una mediana regada no sean el mismo verde
	vec3 tint = mix(base_colour, tip_colour, v_h) / vec3(0.4, 0.58, 0.24);
	ALBEDO = tex.rgb * tint * v_tint;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
