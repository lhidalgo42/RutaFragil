# 01 — Integración visual de la van

Fecha: 2026-09-24. Alcance: integración y pruebas automáticas. El gate humano sigue pendiente.

## Assets finales

| Asset | Tris | Validación | Imagen |
|---|---:|---|---|
| `assets/models/bus_exterior_clean_v1.glb` | 3.856 | `glb_check --kind bus --pivot base`: 8/8 | `assets/textures/bus_exterior_atlas_v1.png` |
| `assets/models/bus_interior_clean_v1.glb` | 4.320 | `glb_check --kind bus --pivot center`: 8/8 | `assets/textures/bus_interior_atlas_v1.png` |
| `assets/models/bus_wheel_clean_v1.glb` | 996 | `glb_check --kind prop --pivot center`: 8/8 | `assets/textures/bus_wheel_atlas_v1.png` |

Suma instanciada: 12.160 / 25.000 tris. Generadores y pruebas: `tools/blender_van*.py`, `tools/blender_bus_*.py`. Geometría determinista; tests de UV por región y presupuesto agregado en verde.

## Integración

- `src/vehicle/bus.tscn`: 11 nodos. `MeshInstance3D` greybox `visible=false`; instancia `BusExteriorVisual`; `CopilotCamera` en x=+0,6.
- `src/vehicle/bus_interior.tscn`: 55 nodos. `Visuals.visible=false`; instancia `BusInteriorVisual`; `CopilotSeat` sin convertir `Positions/copilot`.
- Las 16 formas físicas, seis posiciones, doce restraints, masa/capas/tuning quedan sin cambios.
- Materiales externos: tres `.tres` con albedo a atlas ≤1024², filtros mipmaps anisotrópicos. Cada GLB: un material, cero imágenes.
- `tests/vehicle/bus_visuals_test.gd`: colliders intactos, greybox oculto, visuales sin colisión, presupuesto, dos asientos/cámara. 2/2.
- F1 copiloto: 5/5 de `playground_scene_test.gd`, incluido `test_leaving_the_demo_as_copilot_restores_the_passenger_view_without_drive_input`.

## Capturas

- `van_preview_bus_v3.png`: furgón amarillo, franja roja, techo crema, hueco trasero/lateral y cuatro ruedas.
- `van_exterior.png`, `van_cab.png`, `van_interior.png`: atlas aplicado, asientos, racks, suelo y parabrisas.
- `playground_van.png` se conserva como captura preliminar dentro del Playground, pero apunta al paquete; no demuestra la van y no se usa como criterio.
- Ruedas en movimiento/dirección: pendiente de captura dedicada y corrida en cliente.

## Limitaciones declaradas

- El flanco derecho comparte la columna física de la rueda delantera con la puerta D90. El visual conserva esa geometría; el dueño decide si el arco/step queda aceptable.
- La v1 de suelo seamless mantiene una cruz de reparación; el atlas toma la región central. El gate humano decide si el piso pasa.
- Ocupación de asientos en red: NO PROBADO (M4). Animación visual de ruedas sí debe comprobarse en cliente.
- Flicker perceptible no se puede certificar desde estas capturas; la política aplicada es una superficie visible por lugar y mipmaps anisotrópicos.
