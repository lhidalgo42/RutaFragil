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

## Modelos generativos

*(Sección vacía — se llenará según §10.2 del maestro.)*

## Datos geográficos

- **OpenStreetMap** — © OpenStreetMap contributors, licencia ODbL 1.0 (https://www.openstreetmap.org/copyright). Extracto del 2026-09-14 vía Overpass API de Avenida Departamental y Gran Avenida José Miguel Carrera (San Miguel, Santiago de Chile): ejes viales, huellas de edificios, paraderos, semáforos, árboles, paso bajo nivel (`maxheight`). Archivos derivados: `tools/osm_departamental_compacto.json` (extracto en metros) y `data/b0_departamental.json` (generado por `tools/osm_to_b0.py`). Uso: trazado del greybox de B0 Ciudad (D65). Segundo extracto 2026-09-14 vía API 0.6: damero y sector norte de **Rancagua** (Plaza de los Héroes −34,17029 −70,74076), derivado `data/b0_rancagua.json` (`tools/osm_to_rancagua.py`), D68. Tercer extracto 2026-09-14 vía API 0.6: **Requínoa** (−34,2848586 −70,8175128), derivado `data/b0_requinoa.json` (`tools/osm_to_town.py`), D69: ejes viales con superficie, ferrocarril y andenes, estación, edificios, Plaza de Armas, iglesias, acequias, viñas y huertos, lomos de toro (`traffic_calming`) y la Ruta 5 Sur bajo el puente. Cuarto extracto 2026-09-16 vía API 0.6: **humedal del río Cruces** al norte de Valdivia (−39,731853 −73,256453), derivado `data/b2_pantano.json` (`tools/osm_to_swamp.py`), D71: Ruta T-360 y Pasaje Los Esteros con superficie, puente y vado, paños de humedal (`natural=wetland`), cauces (`waterway`), bosque y matorral, edificios y portones. Al publicar, la atribución va en los créditos del juego.
