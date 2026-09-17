shader_type spatial;

// Suelo del pueblo (D73): dos juegos de texturas de ambientCG (CC0) mezclados por ruido.
//
// Tres decisiones que importan:
//
// 1. Las UV salen de la posición en el MUNDO, no de la malla. El suelo es una losa de
//    2600 m hecha con una caja unitaria escalada: con las UV de la caja, una baldosa de
//    pasto se estiraría los 2600 m enteros. En mundo, `tile_m` es lo que mide de verdad.
// 2. La mezcla la manda un ruido de baja frecuencia, así que los dos suelos se meten uno
//    en otro en manchas grandes y no en un damero.
// 3. Encima va una segunda pasada de la MISMA textura, muy estirada, que multiplica el
//    color. Sin eso, una baldosa de 3 m repetida 800 veces se lee como reja desde el aire
//    — es el defecto clásico de tilear y se ve desde la cámara cenital del mapa.

uniform sampler2D base_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D over_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D over_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D over_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D blend_noise : hint_default_white, filter_linear_mipmap, repeat_enable;

// Metros que mide una baldosa del suelo.
uniform float tile_m = 3.0;
// Tamaño de las manchas de la mezcla, en metros.
uniform float patch_m = 85.0;
// Cuánto del segundo juego se ve: 0 = nada, 1 = todo.
uniform float over_amount : hint_range(0.0, 1.0) = 0.35;
// Qué tan cortado es el borde entre los dos: bajo difumina, alto recorta.
uniform float blend_sharpness : hint_range(1.0, 24.0) = 7.0;
// Cuánto desvía el color la pasada estirada que rompe el mosaico.
uniform float macro_strength : hint_range(0.0, 1.0) = 0.4;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = v_world.xz / max(tile_m, 0.01);
	vec2 patch_uv = v_world.xz / max(patch_m, 1.0);
	float mask = texture(blend_noise, patch_uv).r;
	// over_amount 0 deja la máscara entera bajo el umbral; 1 la deja entera encima.
	float w = clamp((mask - (1.0 - over_amount)) * blend_sharpness + 0.5, 0.0, 1.0);

	vec3 albedo = mix(texture(base_albedo, uv).rgb, texture(over_albedo, uv).rgb, w);
	float rough = mix(texture(base_rough, uv).r, texture(over_rough, uv).r, w);
	vec3 normal = mix(texture(base_normal, uv).rgb, texture(over_normal, uv).rgb, w);

	// Pasada estirada 9 veces: aclara y oscurece por zonas y mata la repetición.
	vec3 macro = mix(texture(base_albedo, uv / 9.0).rgb, texture(over_albedo, uv / 9.0).rgb, w);
	float macro_lum = dot(macro, vec3(0.299, 0.587, 0.114));
	albedo *= mix(1.0, macro_lum * 2.0, macro_strength);

	ALBEDO = albedo * tint * COLOR.rgb;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	SPECULAR = 0.15;
	NORMAL_MAP = normal;
	NORMAL_MAP_DEPTH = 0.8;
}
