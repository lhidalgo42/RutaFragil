shader_type spatial;

// Superficies con textura sobre una cinta de RoadRibbon (D74): la calzada y el ripio.
//
// Las cintas ya traen las UV que hacen falta: **UV.x son metros recorridos a lo largo** y
// **UV.y va de 0 a 1 de lado a lado de la banda**. Con eso la textura se acuesta sobre el
// camino en vez de quedar pegada al mundo — y eso importa porque Road008B **trae las
// marcas pintadas**: línea central discontinua y líneas de borde. Una baldosa a lo ancho
// es una calzada completa, así que las marcas caen solas donde corresponde.
//
// `across_scale` y `across_offset` recortan una franja de la textura a lo ancho. Sirven
// para la avenida, que son dos calzadas de un sentido cada una: ahí no va la línea central
// de la textura, así que se muestrea solo la parte de asfalto liso y las marcas de la
// avenida las sigue poniendo el código.

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grain_noise : hint_default_white, filter_linear_mipmap, repeat_enable;

// Metros que avanza el camino por cada baldosa de textura.
uniform float tile_m = 9.0;
// Franja de la textura que se usa a lo ancho: 1 y 0 = la banda entera, con sus marcas.
uniform float across_scale = 1.0;
uniform float across_offset = 0.0;
// Manchones de suciedad a lo largo, para que 5 km de calzada no sean la misma baldosa.
uniform float grain_m = 60.0;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.25;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = vec2(UV.y * across_scale + across_offset, UV.x / max(tile_m, 0.01));
	vec3 albedo = texture(albedo_map, uv).rgb;
	float grain = texture(grain_noise, v_world.xz / max(grain_m, 1.0)).r;
	albedo *= mix(1.0, grain * 1.35, grain_strength);
	ALBEDO = albedo * tint * COLOR.rgb;
	ROUGHNESS = clamp(texture(rough_map, uv).r, 0.05, 1.0);
	SPECULAR = 0.2;
	NORMAL_MAP = texture(normal_map, uv).rgb;
	NORMAL_MAP_DEPTH = 0.7;
}
