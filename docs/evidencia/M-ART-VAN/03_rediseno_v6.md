# 03 — Rediseño v6 tras rechazo del dueño

Fecha: 2026-09-24. **No es aprobación humana.**

## Rechazo

El dueño rechazó v1: «quedo horrible, revisalo denuevo». Seis revisiones independientes confirmaron causas en código: carrocería prismática, arcos negros rectangulares, rueda de buggy, atlas con luz horneada, material único sin jerarquía y capturas que ocultaban defectos.

v5 volvió a fallar en revisión adversarial: seguía leyendo autobús, faltaba vidrio lateral de cabina, trasera sin terminar y rueda deportiva. v6 corrige esos puntos sin tocar física.

## Resultado v6

| Área | Cambio |
|---|---|
| Exterior | cab-over con pilares inclinados, vidrio lateral de cabina, frente escalonado, faros con bisel, parrilla, parachoques, techo crema continuo; flanco de carga ciego; franja roja 0,13 m |
| Trasera | dos hojas abiertas, bisagras, pestillos, paneles embutidos, pilotos, marcadores superiores, fascia/estribo amarillo, placa neutra; hueco físico de 1,40 m sin cambio |
| Puerta derecha | jambas, dintel, umbral, riel y hoja estacionada; sin escalón que cruce la rueda D90 |
| Interior | asientos sobre markers, volante/consola/cinturones, gabinetes bajos, estantes parciales, cinco paquetes visuales, piso con nervaduras, guardabarros cerrados y umbral trasero |
| Rueda | neumático comercial liso de mayor segmentación, disco de acero, buje, tuercas, ventilaciones y válvula asimétrica; genérico, sin marca |
| Atlas | paleta canónica exacta + microdetalle high-pass de las fuentes ComfyUI/FLUX; sin tintes ni luz horneada |
| Capturas | 12 vistas desde fuera del casco, perfil con lente larga, luz neutra y relleno interior solo para tomas interiores |

## Validación automática

- `blender_van_test.py`: 9.844 tris, determinista.
- `blender_bus_interior_test.py`: 6.872 tris, pasillo 1,204 m, determinista.
- `blender_bus_wheel_test.py`: 1.476 tris, radio 0,500 m, total visible 22.620/25.000.
- `build_van_atlases_test.py`: tres atlas 1024², RGB exacto por región, determinista.
- Suite: 271/271; red 1 host + 3 clientes verde.

Capturas: `integracion/van_*.png`.

## Límites que solo resuelve una decisión física

- D90 coloca la puerta derecha sobre la rueda delantera derecha. v6 la enmarca, pero no puede convertirla en una puerta canónica sin mover colisiones.
- El hueco trasero físico mide 1,40 m. v6 lo termina visualmente, pero no lo ensancha para no crear paredes invisibles.
- Flicker, legibilidad y feel siguen requiriendo gate humano.
