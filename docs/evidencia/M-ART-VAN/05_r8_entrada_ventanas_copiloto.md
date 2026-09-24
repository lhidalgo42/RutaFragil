# 05 — r8: entrada corredera, ventanas de cabina y mirada del copiloto

Fecha: 2026-09-24. **No es aprobación humana.**

## Pedido

Gate F5 de r7: «las puertas traseras del bus quedaron muy buenas, sin embargo la puerta lateral de entrada sigue sin verse bien, tambien quiero agregar una venta al lado lateral del piloto y una venta lateral al lado del copiloto, y la capacidad del copiloto para mirar a todos los lados». El dueño eligió **corredera de furgón**.

## Cambios

| Área | Resultado |
|---|---|
| Corredera | Ahora de altura completa. Hoja escalonada sobre el arco FR: baja hasta el piso detrás del arco y queda sobre la franja delante de él. Tiene juntas perimetrales, paneles prensados, placa de manija, riel superior y riel central de cintura. El umbral y el estribo son oscuros. El vano está abierto hasta el piso. |
| Mecánica | Sin cambios: `side_pose` saca la hoja 0,035 m y la desliza 0,95 m. El pivote pasa a `(1.252, 0.24, -1.30)` porque la hoja ahora empieza más abajo. `BusDoors`, blockers, vano físico y red no se tocaron. |
| Ventanas | Aberturas reales y simétricas a ambos lados de la cabina, con marco oscuro y vidrio transparente (`Left/RightCabWindowPane`, mismo material que el parabrisas). Los liners interiores llevan el mismo recorte. La colisión sigue siendo pared ciega. |
| Copiloto | `CopilotCamera` (script nuevo): yaw ilimitado (360°) y pitch ±89°. Solo gira siendo `current` y con el puntero capturado. Es local y no se replica. El conductor sigue con su cono de ±120°. |
| Traseras | Sin cambios (aprobadas); el barrido de 0 a 132° sigue verificado. |

## Validación automática

- `blender_van_test.py`: 10.344 tris (límite 10.500), determinista. Verifica el vano abierto hasta el piso, el escalón sobre el arco, las ventanas abiertas, los pivotes, la corredera sin cruces y el barrido trasero.
- `blender_bus_interior_test.py`: 6.460 tris, 56 nodos, pasillo 1,204 m, recorte de ventana en ambos liners, determinista.
- Total visible: 22.708 / 25.000.
- Suite: **292/292** (conteo exacto 292; +4 `copilot_camera_test.gd`).
- Red: **1 host + 3 clientes**, pass.
- Demo abierta: `lap_completed t=27.3 waypoints=17 max_speed_kmh=64.6 min_upright=0.97`.
- Demo con puertas cerradas: mismas cifras.

## Capturas

- `integracion/van_side_door_closed.png`, `van_side_door_half.png`, `van_side_door.png`: corredera cerrada, a medias y abierta.
- `integracion/van_cab_window_left.png`, `van_exterior_side_*.png`: ventanas de cabina.
- `integracion/van_copilot_look_right.png`, `van_copilot_look_back.png`: vista del copiloto girada 80° y 170°.

## Límites declarados

- Ningún test decide si la entrada «se ve bien»: eso es del gate humano.
- La mirada del copiloto es local: los demás jugadores no ven hacia dónde mira.
- Las ventanas son solo visuales: no se abren y no dejan pasar objetos.
