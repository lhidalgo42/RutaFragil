# 04 — Puertas funcionales y asientos automotrices

Fecha: 2026-09-24. **No es aprobación humana.**

## Pedido

El dueño dijo: «va mejorando sin embargo esta incompleto, se detallista ya que es lo mas llamativo al usuario, los asientos no parecen asientos, no existe la puerta para subirse, falta la opcion de abrir y cerrar la puerta de atras y se vea con animacion». Luego eligió que la puerta lateral también abra y cierre.

## Implementado

| Área | Resultado |
|---|---|
| Puerta lateral | Corredera animada con E. Hueco físico movido de z [-3,2,-2,3] a [-2,2,-1,3], fuera de la rueda FR. |
| Puertas traseras | Dos hojas con pivote real detrás del marco; animación hasta ∓132° sin atravesar carrocería. |
| Colisión | Dos blockers en `AnimatableBody3D` separado, capa carga: deshabilitados abiertos; activos solo cerrados. No cambian inercia del bus. |
| Seguridad | Cierre rechazado o revertido si hay carga/tripulante en el vano o en el barrido de la hoja. |
| Red | Host-authoritative: pedido RPC del cliente, validación de fase y alcance, replicación de estado, snapshot de entrada tardía. |
| Asientos | Una malla por asiento: bucket, bolsters, respaldo reclinado hacia atrás, cabezal con postes, pedestal, rieles y cinturón. |

Ambas puertas arrancan abiertas por defecto, conservando D75/D99. Cambiarlo es un booleano del `.tscn`.

## Validación automática

- `blender_van_test.py`: 9.844 tris, jerarquía de 7 nodos observada y límite R8 ≤60, pivotes, hueco lateral nuevo, barrido de rueda y determinismo.
- `blender_bus_interior_test.py`: 6.100 tris, 56 nodos, asientos de 304 tris cada uno, pasillo 1,204 m, determinista.
- `blender_bus_wheel_test.py`: total visible 21.848 / 25.000 tris.
- Suite: **288/288**, conteo exacto 288.
- Barrido trasero 0–132°: cero cruces hoja/shell en el test generador.
- Inercia: igual con puertas abiertas y cerradas.
- Red: **1 host + 3 clientes**, convergencia de puertas cerradas.
- Demo base: vuelta completa, 64,6 km/h, upright 0,97.
- Sonda cerrada reproducible (`timeout 180 "$GODOT_BIN" --headless --fixed-fps 60 --path . -s res://src/tooling/run_closed_doors_demo.gd`): `DOORS_CLOSED result=lap_completed t=27.3 waypoints=17 max_speed_kmh=64.6 min_upright=0.97`.

## Capturas

- `integracion/van_side_door.png`, `van_side_door_half.png`, `van_side_door_closed.png`: animación lateral.
- `integracion/van_rear_doors_closed.png`: traseras cerradas.
- `integracion/van_seats_close.png`, `van_cab_seats.png`: asientos nuevos.

## Límites declarados

- Ningún test automático juzga si se ve bien; eso lo decide el gate humano.
- El 1+3 prueba que el estado cerrado del host llega a los tres clientes. No cubre el RPC de un cliente pulsando E; cliente humano con latencia real sigue siendo gate manual.
- La trasera no cambia `aboard`: es puerta de carga, no de abordaje.
