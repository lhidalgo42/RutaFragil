# 22 — Experimento de 300 s: la precondición v5 pasa, y un fallo del filtro que la habría tumbado

**Fecha:** 2026-09-17 · **Autor:** revisor (relevo del ejecutor, agotado su presupuesto) · Código de simulación: árbol de trabajo sobre `91ffbb7` con el arreglo de inercia de D98. Motor `4.7.2.stable.official.ed1daf0bf`, Jolt. Dos ventanas, VSync off, `max_fps = 0`. 300 s / 18.000 ticks por instancia, carga activa, ciclos activos, `human=none`. **No es una iteración D96** (`experiment=1`, `d96_consumed: false`).

Muestreo: observador independiente `GateMetrics` posterior a los nodos, `process_priority` y `process_physics_priority` = 1000, idéntico en las dos instancias, solo lectura.

## La precondición v5 pasa

| Requisito D (D95 v5) | Anfitrión | Cliente | Exigencia | |
|---|---:|---:|---|:--:|
| `hull_exit_ticks` | **0** | **0** | = 0 | ✔ |
| Empujón más largo | 0 ticks | **14 ticks** | ≤ 45 | ✔ |
| Empujones abiertos al terminar | 0 | **0** | 0 | ✔ |
| Ciclos completos | 114 | 125 | ≥ 10 | ✔ |
| Apoyo en el último tick | sí | **sí** | sí | ✔ |

Y lo que se reporta sin juzgar: apoyo **100 % / 99,456 %**; 19 empujones en el cliente, ninguno en el anfitrión; desplazamiento local máximo por empujón 0,558 m; penetración 0,0362 / 0,0294 m con rachas de 1 y 0 ticks; fps p1 277 / 289; cámaras 1/1; carga sin autoridad 0; tripulante remota simulada 0.

**Para situar el cambio:** la corrida equivalente de la ronda 5 daba 27,33 % de apoyo en el cliente y expulsión definitiva a los 82 s. El arreglo de inercia de D98 convierte las expulsiones en tropiezos: 19 empujones, el peor de 14 ticks (0,23 s), y de todos vuelve al bus.

## El fallo del filtro, y por qué importaba

Con las métricas tal como estaban, el criterio (3) del gate **fallaba**:

| | Anfitrión | Cliente | Razón |
|---|---:|---:|---:|
| p95 | 0,03361 | 0,03412 | **1,015** |
| p99 | 0,03387 | **0,07541** | **2,226** ✗ (límite 1,5) |
| p99,9 | 0,03496 | 0,28728 | 8,2 |
| máx | 0,03814 | 0,51030 | 13,4 |

El cliente calca al anfitrión hasta el p95 y se dispara después. Fui a buscar esos ticks al CSV: **los quince deslizamientos «elegibles» mayores tienen distancia CERO al contacto de carga más cercano** — es decir, la caja le está empujando en ese mismo tick y el filtro los dejaba pasar. De las 152 muestras elegibles por encima del límite, **137 (90,1 %) son el propio tick del contacto**; solo 2 están a más de 90 ticks de cualquier contacto, y valen 0,0618 y 0,0587, apenas por encima del límite.

La causa, en `gate_travel_metrics.gd`: `slip_eligible` excluía `cargo_contact_previous_three` pero **no el tick actual**. El tick del empujón es la muestra **más** contaminada, no la menos. Mi propio pliego decía «sin contacto de carga en los tres ticks previos» y no nombraba el actual: ambigüedad mía, implementada literalmente.

Recalculando desde el mismo CSV, excluyendo el tick del contacto además de los previos:

| Ventana de exclusión | Muestras | p95 | **p99** | Razón vs anfitrión | máx |
|---|---:|---:|---:|---:|---:|
| tick actual + 3 previos | 13.677 | 0,03402 | **0,03493** | **1,031** ✔ | 0,21703 |
| + 10 previos | 11.873 | 0,03388 | 0,03469 | 1,024 | 0,08780 |
| + 45 previos | 5.675 | 0,03348 | 0,03387 | 1,000 | 0,07829 |

**Con el tick del empujón excluido, el cliente va a 1,031× del anfitrión.** El criterio de 1,5× se cumple con margen, y la cifra es estable frente a la ventana elegida — 1,03, 1,02, 1,00 — lo que dice que no es un artefacto de dónde se corte.

Arreglado en `GateTravelMetrics.observe()`, que ahora recibe el contacto actual y el reciente como dos banderas y excluye con cualquiera de las dos. Fijado por `gate_v5_test.gd::test_the_cargo_contact_tick_itself_is_excluded_from_the_filtered_series`, que además comprueba que la serie cruda conserva el empujón. `slip_filter` pasa a declarar `supported_and_no_cargo_contact_this_tick_or_previous_three`.

**El rojo de este arreglo no es sintético: es esta corrida.** Con el fallo, 2,226× y gate suspendido; sin él, 1,031× sobre los mismos datos.

## Lo que esto NO dice

- **No es una iteración D96.** El contador sigue en dos fallos válidos y el tercero intacto.
- **No hay aprobación humana.** Nadie ha jugado esta configuración; D97 sigue pendiente y el gate no está aprobado hasta que el dueño juegue la ventana cliente.
- El p99,9 crudo del cliente (0,376) y el máximo (0,510) son reales y se reportan: hay ticks con medio metro de desplazamiento relativo durante los empujones. El criterio no juzga el máximo, pero eso es exactamente lo que el dueño tiene que sentir en el gate humano.
- La corrida se hizo con la sonda de penetración que ya declaró cobertura incompleta en transiciones (evidencia 17): los máximos y rachas publicados son observados, no certificados.
