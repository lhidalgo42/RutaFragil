shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

// Greybox grass tuft (D64): two crossed quads per tuft, tapered by discarding
// pixels outside a blade triangle (no texture, so nothing goes through LFS).
// Sways with the wind and bends away from `bus_position`, set per frame by
// GrassStrip. Height weight = UV.y (0 at the root, 1 at the tip).

uniform vec3 bus_position = vec3(0.0, -100.0, 0.0);
uniform vec3 base_colour : source_color = vec3(0.22, 0.42, 0.18);
uniform vec3 tip_colour : source_color = vec3(0.55, 0.75, 0.3);
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.4;
uniform float bend_radius = 2.6;
uniform float bend_strength = 0.9;

varying float v_h;
varying vec3 v_tint;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = UV.y;
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
	// Silueta de hoja: se angosta rápido al principio y termina en punta fina.
	float half_w = 0.5 * pow(1.0 - UV.y, 0.55) * (1.0 - UV.y * 0.55);
	if (abs(UV.x - 0.5) > half_w) {
		discard;
	}
	ALBEDO = mix(base_colour, tip_colour, v_h) * v_tint;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
