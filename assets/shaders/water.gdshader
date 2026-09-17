shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;

// Agua de fuente y de canal (D76, rehecha en D77). La primera versión era opaca, saturada
// y con el ruido muy fino: en una foto quieta se leía como un mosaico azul. Lo que hace
// que agua parezca agua en una imagen fija es otra cosa: se VE A TRAVÉS (el fondo claro del
// estanque), brilla con el sol en las ondas, y es más blanca donde rompe. En movimiento,
// las dos capas de ruido corren en direcciones distintas y el brillo baila.
// `flow` 0 = superficie quieta; 1 = chorro que cae, el patrón corre hacia abajo.

uniform sampler2D noise_map : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 shallow : source_color = vec3(0.55, 0.78, 0.8);
uniform vec3 deep : source_color = vec3(0.16, 0.42, 0.5);
uniform float speed = 0.8;
// Metros por repetición del ruido en la superficie: ondas anchas, no grano.
uniform float scale_m = 3.2;
// 0 = agua quieta con ondas; 1 = chorro que cae.
uniform float flow : hint_range(0.0, 1.0) = 0.0;
uniform float ripple : hint_range(0.0, 2.0) = 0.9;
// Transparencia: el fondo del estanque se ve a través. Un chorro va más opaco y blanco.
uniform float opacity : hint_range(0.0, 1.0) = 0.62;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 base = v_world.xz / max(scale_m, 0.01);
	// el chorro corre hacia abajo por las UV de la caja, rápido y estirado
	vec2 fall = vec2(UV.x * 1.5, UV.y * 6.0 + TIME * 3.0);
	vec2 uv1 = mix(base + vec2(TIME * speed * 0.35, TIME * speed * 0.2), fall, flow);
	vec2 uv2 = mix(base * 1.6 - vec2(TIME * speed * 0.25, -TIME * speed * 0.3), fall * 1.3 + vec2(0.37, 0.0), flow);
	float n1 = texture(noise_map, uv1).r;
	float n2 = texture(noise_map, uv2).r;
	float h = (n1 + n2) * 0.5;

	// Fresnel: de frente se ve el fondo, de refilón el cielo
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	vec3 colour = mix(deep, shallow, smoothstep(0.3, 0.75, h) * 0.6 + fresnel * 0.4);
	// espuma donde rompe: poca en el estanque, mucha en el chorro
	float foam = smoothstep(0.7, 0.88, h) * (0.35 + 0.65 * flow);
	colour = mix(colour, vec3(0.92, 0.96, 0.97), foam);

	ALBEDO = colour * COLOR.rgb;
	ALPHA = clamp(opacity + fresnel * 0.3 + foam * 0.4 + flow * 0.25, 0.0, 1.0);
	ROUGHNESS = 0.05;
	SPECULAR = 0.8;
	METALLIC = 0.0;

	// normal desde el gradiente del ruido: el reflejo del sol se mueve con las ondas
	float e = 0.012;
	float dx = texture(noise_map, uv1 + vec2(e, 0.0)).r - n1;
	float dy = texture(noise_map, uv1 + vec2(0.0, e)).r - n1;
	NORMAL_MAP = normalize(vec3(-dx * ripple * 14.0, -dy * ripple * 14.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
