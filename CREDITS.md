# CREDITS.md — Ruta Frágil

## Godot Engine

- Licencia: **MIT** — el aviso de licencia es **obligatorio en la distribución** del juego.
- Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
- https://godotengine.org/license
- Versión pineada del proyecto: `4.7.2.stable.official.ed1daf0bf` (ADR-000).

## Jolt Physics

- Licencia: **MIT**. Incluido en Godot; este proyecto lo usa como motor de física 3D (`physics/3d/physics_engine="Jolt Physics"`).
- Copyright 2021 Jorrit Rouwe.
- https://github.com/jrouwe/JoltPhysics

## gdUnit4

- Licencia: **MIT** — "Copyright (c) 2023-2026 Mike Schulze".
- Se cita el `LICENSE` de la raíz del repo `godot-gdunit-labs/gdUnit4` (no la copia desactualizada dentro del addon).
- https://github.com/godot-gdunit-labs/gdUnit4
- Versión pineada: tag **v6.2.1** (D32), commit `08ffc7c65b61b1b2edd545616061a99973c13ce1`.
- Se vendoriza la carpeta `addons/gdUnit4/` **sin `test/`**, igual que la distribución oficial (que la excluye por `export-ignore`). Borrado de `test/` autorizado por el dueño el 2026-09-08 por R12. `src/dotnet/GdUnit4CSharpApi.cs` es parte de la distribución oficial y queda inerte en build estándar (D32).

## Texturas

- **ambientCG** — licencia **CC0 1.0** (dominio público, sin atribución obligatoria; se
  deja igual por cortesía y para poder rastrear el origen). https://ambientcg.com
  - `Grass008` — https://ambientcg.com/view?id=Grass008 (pasto del suelo)
  - `Snow015` — https://ambientcg.com/view?id=Snow015 (nieve del suelo, dial)
  - `Rocks005` — https://ambientcg.com/view?id=Rocks005 (roca del suelo y ripio, D74)
  - `Road008B` — https://ambientcg.com/view?id=Road008B (calzada, con sus marcas pintadas, D74)
  - `Terrain001` — https://ambientcg.com/view?id=Terrain001 (escaneo de terreno; se usan
    `Color`, `Soil` y `Protrusion` del paquete 2K-JPG, estirados a 900 m como mapa de la
    zona, no como baldosa, D74)
  - `DayEnvironmentHDRI108` — https://ambientcg.com/view?id=DayEnvironmentHDRI108 (cielo,
    `_1K_HDR.exr` tal cual, 1,8 MB, D74)
  - Descargados el 2026-09-17 en 1K-JPG (Terrain001 en 2K-JPG, el único que ofrece). De
    cada material se usan solo **Color, NormalGL y Roughness**; no se versionan
    AmbientOcclusion, Displacement, `.blend`, `.usdc` ni `.mtlx`. Todo se **reduce** con
    `src/tooling/shrink_texture.gd` antes de entrar al repo —512 px los materiales,
    1024 px los tres mapas del terreno—: los objetos de Git LFS en GitHub son permanentes
    (nota de D36). Viven en `assets/textures/{ground,road,sky}/` y los usan
    `assets/shaders/ground.gdshader` (D73, D74) y `assets/shaders/ribbon.gdshader` (D74).

## Modelos generativos

*(Sección vacía — se llenará según §10.2 del maestro.)*

## Datos geográficos

- **OpenStreetMap** — © OpenStreetMap contributors, licencia ODbL 1.0 (https://www.openstreetmap.org/copyright). Extracto del 2026-09-14 vía Overpass API de Avenida Departamental y Gran Avenida José Miguel Carrera (San Miguel, Santiago de Chile): ejes viales, huellas de edificios, paraderos, semáforos, árboles, paso bajo nivel (`maxheight`). Archivos derivados: `tools/osm_departamental_compacto.json` (extracto en metros) y `data/b0_departamental.json` (generado por `tools/osm_to_b0.py`). Uso: trazado del greybox de B0 Ciudad (D65). Segundo extracto 2026-09-14 vía API 0.6: damero y sector norte de **Rancagua** (Plaza de los Héroes −34,17029 −70,74076), derivado `data/b0_rancagua.json` (`tools/osm_to_rancagua.py`), D68. Tercer extracto 2026-09-14 vía API 0.6: **Requínoa** (−34,2848586 −70,8175128), derivado `data/b0_requinoa.json` (`tools/osm_to_town.py`), D69: ejes viales con superficie, ferrocarril y andenes, estación, edificios, Plaza de Armas, iglesias, acequias, viñas y huertos, lomos de toro (`traffic_calming`) y la Ruta 5 Sur bajo el puente. Cuarto extracto 2026-09-16 vía API 0.6: **humedal del río Cruces** al norte de Valdivia (−39,731853 −73,256453), derivado `data/b2_pantano.json` (`tools/osm_to_swamp.py`), D71: Ruta T-360 y Pasaje Los Esteros con superficie, puente y vado, paños de humedal (`natural=wetland`), cauces (`waterway`), bosque y matorral, edificios y portones. Al publicar, la atribución va en los créditos del juego.
