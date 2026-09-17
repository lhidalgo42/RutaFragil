# 25 — Sesión del dueño: qué dijo, qué medí, y qué queda

**Fecha:** 2026-09-17 · Corrida `user://gate/run_20260917_115149`, `kind: "human"` · `tools/run_gate.ps1 -Seconds 300 -Human client`.

## El veredicto del dueño, literal

> «se siente bien al estar en el auto manejando, sin embargo, cuando una caja se cae y uno la va a recoger, como que quedan con la inercia pero sin moverse entonces uno la toma la lanza y saltan lejos»

Dos cosas, y conviene separarlas: **el núcleo se siente bien** —que es exactamente lo que ADR-003 pone en duda— y hay una queja sobre la carga.

## Lo que la queja resultó ser

No era lo que parecía. Medí el rastro del anfitrión (10 Hz, 3.001 muestras del bus, 300 s completos) y las cuatro cajas salen por el **mismo** sitio:

| Caja | Sale en | Posición local (x · y · z) |
|---|---:|---|
| `Package_3` | **5,4 s** | 0,27 · −0,74 · **4,72** |
| `Package_0` | 210,3 s | −0,48 · −0,65 · **4,97** |
| `Package_1` | 189,0 s | −0,97 · −0,67 · **4,52** |
| `Package_2` | 96,6 s | 0,62 · −0,41 · **5,77** |

Todas a ras de suelo y por detrás: el suelo termina en `z = 3,9`. Contrastado con la geometría de `bus_interior.tscn`: las dos paredes traseras miden 0,55 m y dejan **1,4 m de hueco** entre ellas. La caja mide 0,4 m.

**Es la puerta de carga** (D99, confirmado por el dueño: «sí es una puerta, no la detallé en el plan»). Cuando el bus acelera, una caja suelta se queda atrás respecto al suelo —física correcta— y se desliza hasta salir. `Package_3` se fue a los 5,4 s sin que nadie la tocara, así que **no es el lanzamiento**: es que la carga suelta se pierde, que es la razón de ser de las correas.

## Dos hipótesis mías, descartadas midiendo antes de "arreglarlas"

1. **«El lanzamiento no hereda la velocidad del bus.»** Falso: `NetBusSync` sí se registra en el grupo `net_bus_sync` (`net_bus_sync.gd:34`) que `point_velocity` consulta, así que el cliente usa la velocidad replicada y la conversión a marco de bus es simétrica.
2. **«Alguna caja queda FREE pero congelada en el anfitrión, que es quien debe simularla.»** Falso: cero casos en los volcados de flancos; las cajas FREE aparecen con `freeze = false` y desplazamiento por tick igual al del bus cuando están dentro (`Package_0` en el tick 3925, `local [−0,39, −0,40, −0,67]`, 0,3348 m/tick).

Queda anotado porque las dos eran plausibles y las dos habrían producido un "arreglo" que rompía algo que funciona.

## Lo que esta sesión NO acredita

**La ventana del cliente se cerró antes de los 300 s** (`"error": "client did not finish"`, `exit 1` del anfitrión, `status: invalid`). El anfitrión sí completó la corrida, y de ahí salen los datos de arriba, pero **la sesión no cuenta como el gate humano completo de D97**, que pide cinco minutos.

Tampoco hay veredicto automático: una corrida con jugador humano se registra como `played` con `human_gate_approval: pending_owner` y sale con código 0 pase lo que pase, porque el veredicto es del dueño (arreglado hoy; antes la guardia del tercer intento la rechazaba con código 3, que era un defecto del revisor).

## Estado

- **Criterio automático: aprobado** en la iteración 6 (evidencia 23), con dos fallos válidos de D96 y el tercero intacto.
- **Gate humano: pendiente de una sesión completa**, o de que el dueño dé por buena la que jugó.
- La queja de la carga **no era un fallo del acarreo**, así que no toca ADR-003.
