shader_type spatial;
render_mode cull_back;

// Greybox facades (D67): the MultiMesh instance colour is the wall paint;
// windows, frames and a ground-floor door are drawn procedurally in world
// space per floor (no textures). Only vertical faces get openings; the top
// and the bottom of the box stay plain.

uniform float floor_h = 3.2;
uniform float window_step = 2.6;
uniform vec3 glass : source_color = vec3(0.16, 0.2, 0.28);
uniform vec3 frame : source_color = vec3(0.93, 0.93, 0.9);
uniform vec3 door : source_color = vec3(0.34, 0.2, 0.13);
uniform vec3 plinth : source_color = vec3(0.45, 0.42, 0.4);

varying vec3 world_pos;
varying vec3 world_n;
varying vec4 inst_col;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	inst_col = COLOR;
}

void fragment() {
	vec3 col = inst_col.rgb;
	float vertical = 1.0 - abs(world_n.y);
	// coordinate along the wall, perpendicular to its normal in the ground plane
	float u = dot(world_pos.xz, vec2(-world_n.z, world_n.x));
	float fu = fract(u / window_step);
	float fy = fract(world_pos.y / floor_h);
	float floor_i = floor(world_pos.y / floor_h);
	bool wall = vertical > 0.5;
	bool in_frame = wall && fu > 0.27 && fu < 0.73 && fy > 0.28 && fy < 0.82;
	bool in_glass = wall && fu > 0.31 && fu < 0.69 && fy > 0.32 && fy < 0.78;
	bool door_slot = wall && floor_i < 0.5 && fract(u / (window_step * 3.0)) < 0.3333 && fu > 0.3 && fu < 0.7 && world_pos.y < 2.15;
	float rough = 0.9;
	float spec = 0.2;
	if (wall && world_pos.y < 0.45) {
		col = plinth;
	}
	if (in_frame) {
		col = frame;
	}
	if (in_glass) {
		col = glass;
		rough = 0.25;
		spec = 0.6;
	}
	if (door_slot) {
		col = door;
		rough = 0.7;
		spec = 0.2;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
