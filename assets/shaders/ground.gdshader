shader_type spatial;

// Suelo del pueblo (D73, ampliado en D74). Cuatro texturas de ambientCG (CC0) y un
// terreno que decide dónde va cada una:
//
//   Grass008  — el pasto, la capa de base
//   Rocks005  — la piedra, donde el terreno dice que hay roca o suelo desnudo
//   Snow015   — la nieve, un dial aparte
//   Terrain001 — NO se repite como baldosa: es un escaneo de terreno de kilómetros.
//                Entra estirado sobre cientos de metros y manda tres cosas: el color a
//                gran escala, dónde hay tierra (`soil`) y dónde asoma roca (`protrusion`).
//                Ese es el papel que le corresponde: un escaneo único tileado se lee como
//                un estampado; estirado, es el mapa de la zona.
//
// Tres decisiones que importan:
//
// 1. Las UV salen de la posición en el MUNDO, no de la malla. El suelo es una losa de
//    2600 m hecha con una caja unitaria escalada: con las UV de la caja, una baldosa de
//    pasto se estiraría los 2600 m enteros. En mundo, `tile_m` son metros de verdad.
// 2. La mezcla la mueven las máscaras del terreno MÁS un ruido, porque una máscara sola
//    corta con borde de mapa y el ruido le devuelve el borde sucio.
// 3. El color del terreno multiplica el resultado en vez de reemplazarlo. Va normalizado
//    por su propio promedio medido (0,31) para que aclare y oscurezca por zonas sin teñir
//    el pueblo entero de verde oliva.

group_uniforms detalle;
uniform sampler2D base_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D over_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D over_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D over_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

group_uniforms terreno;
// Sin `source_color` a propósito: este mapa solo MODULA el color, no se ve tal cual, y así
// los valores que llegan son los mismos 0..1 del archivo, que es donde se midió su promedio.
uniform sampler2D terrain_color : filter_linear_mipmap, repeat_enable;
uniform sampler2D terrain_soil : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D terrain_protrusion : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D blend_noise : hint_default_white, filter_linear_mipmap, repeat_enable;

group_uniforms bosque;
// Suelo de bosque (Ground068) bajo las copas (D76). `canopy_mask` la arma MeshBatcher al
// colocar los árboles: 2 m por píxel, 1 bajo la copa, 0 fuera. Sin máscara no hay bosque.
uniform sampler2D forest_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D canopy_mask : hint_default_black, filter_linear, repeat_disable;
uniform vec2 canopy_origin = vec2(0.0, 0.0);
uniform vec2 canopy_size = vec2(0.0, 0.0);
uniform float forest_tile_m = 2.6;

group_uniforms escalas;
// Metros que mide una baldosa de pasto y una de piedra.
uniform float tile_m = 3.0;
uniform float rock_tile_m = 3.2;
// Metros que abarca el escaneo de terreno completo. Grande a propósito.
uniform float macro_m = 900.0;
// Metros por repetición del ruido de mezcla. Grande a propósito: a 85 m salía una mancha
// de nieve de 5 m cada 17 m en todo el mapa, y desde arriba se leía como punteado (D75).
uniform float patch_m = 420.0;

group_uniforms mezcla;
// Cuánta piedra asoma por el mapa de tierra del terreno.
uniform float soil_amount : hint_range(0.0, 1.0) = 0.45;
// Cuánta piedra asoma donde el terreno sobresale.
uniform float rock_amount : hint_range(0.0, 1.0) = 0.55;
// Cuánta nieve: 0 = nada, 1 = todo nevado.
uniform float over_amount : hint_range(0.0, 1.0) = 0.0;
// Qué tan cortado es el borde de la nieve.
uniform float blend_sharpness : hint_range(1.0, 24.0) = 7.0;
// Cuánto manda el color del terreno sobre el resultado.
uniform float macro_strength : hint_range(0.0, 1.0) = 0.3;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);

// Promedio de luz medido en terrain_color al reducirla (src/tooling/shrink_texture.gd).
// Divide el color del terreno para que module en vez de oscurecer todo.
const float TERRAIN_MEAN = 0.31;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = v_world.xz / max(tile_m, 0.01);
	vec2 uv_rock = v_world.xz / max(rock_tile_m, 0.01);
	vec2 macro_uv = v_world.xz / max(macro_m, 1.0);
	float noise = texture(blend_noise, v_world.xz / max(patch_m, 1.0)).r;

	// Dónde el terreno dice que no hay pasto: tierra desnuda o roca asomada.
	float soil = texture(terrain_soil, macro_uv).r;
	float prot = texture(terrain_protrusion, macro_uv).r;
	// Umbral alto a propósito: con el borde bajo en 0,1 quedaba una pizca de piedra en todo
	// el mapa, y desde arriba las piedras claras repetidas cada baldosa se leían como un
	// punteado regular (D75). La roca aparece solo donde el terreno de verdad la pide.
	float bare = (soil - 0.5) * 2.0 * soil_amount + (prot - 0.15) * 3.0 * rock_amount;
	bare = smoothstep(0.32, 0.8, bare + (noise - 0.5) * 0.3);

	vec3 albedo = mix(texture(base_albedo, uv).rgb, texture(rock_albedo, uv_rock).rgb, bare);
	float rough = mix(texture(base_rough, uv).r, texture(rock_rough, uv_rock).r, bare);
	vec3 normal = mix(texture(base_normal, uv).rgb, texture(rock_normal, uv_rock).rgb, bare);

	// Bajo las copas, suelo de bosque: hojas y musgo donde la máscara dice que hay árbol.
	float canopy = 0.0;
	if (canopy_size.x > 0.5 && canopy_size.y > 0.5) {
		vec2 cuv = (v_world.xz - canopy_origin) / canopy_size;
		if (cuv.x >= 0.0 && cuv.x <= 1.0 && cuv.y >= 0.0 && cuv.y <= 1.0) {
			canopy = texture(canopy_mask, cuv).r;
		}
	}
	canopy = smoothstep(0.05, 0.6, canopy + (noise - 0.5) * 0.25);
	vec2 uv_forest = v_world.xz / max(forest_tile_m, 0.01);
	albedo = mix(albedo, texture(forest_albedo, uv_forest).rgb, canopy);
	rough = mix(rough, texture(forest_rough, uv_forest).r, canopy);
	normal = mix(normal, texture(forest_normal, uv_forest).rgb, canopy);

	// La nieve va encima de todo, con su propio umbral.
	float snow = clamp((noise - (1.0 - over_amount)) * blend_sharpness + 0.5, 0.0, 1.0);
	albedo = mix(albedo, texture(over_albedo, uv).rgb, snow);
	rough = mix(rough, texture(over_rough, uv).r, snow);
	normal = mix(normal, texture(over_normal, uv).rgb, snow);

	// El terreno manda el color a gran escala: es lo que mata la sensación de baldosa.
	// Acotado: las quebradas del escaneo son casi negras y sin tope pintan vetas negras.
	vec3 macro = clamp(texture(terrain_color, macro_uv).rgb / TERRAIN_MEAN, 0.65, 1.35);
	albedo *= mix(vec3(1.0), macro, macro_strength);

	ALBEDO = albedo * tint * COLOR.rgb;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	SPECULAR = 0.15;
	NORMAL_MAP = normal;
	NORMAL_MAP_DEPTH = 0.8;
}
