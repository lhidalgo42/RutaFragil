# Ronda5 — logs íntegros del experimento final300s

[Host](18_raw/r5_final_300/host.log): **0 ERROR /0 WARNING**.
[Cliente](18_raw/r5_final_300/client.log): **0 ERROR /0 WARNING**.
Ambos procesos0; lanzador0. El experimento termina y **D no pasa**.
[Resumen con recuentos](18_raw/r5_final_300/summary.json), fuentes25c7a72,
ambas ventanas, VSync off y max_fps0. No hay tercera iteración del gate.

El baseline120s de ronda5 también tiene logs0/0 por instancia:
[host](13_raw/r5_motion_baseline_01/host.log),
[client](13_raw/r5_motion_baseline_01/client.log).
La sonda masked_encounter sí conserva avisoJolt de jobs en su stderr;
no se extiende la afirmación de limpieza a todas las sondas ni a gdUnit.

REGISTRO HISTÓRICO ANTERIOR (no sustituye el estado de ronda5)

# Logs de ventana — ronda 4

| Ejecución | Anfitrión ERROR / WARNING | Cliente ERROR / WARNING | Salidas hijos |
|---|---:|---:|---:|
| [Corrida4, segundo fallo válido](04_raw/iteration_4/summary.json) | 0 / 0 | 0 / 0 | 0 / 0 |
| [Sin carga60 s](13_raw/r4_no_cargo_01/summary.json) | 0 / 0 | 0 / 0 | 0 / 0 |
| [Carga, solo caminar60 s](13_raw/r4_cargo_walk_01/summary.json) | 0 / 0 | 0 / 0 | 0 / 0 |
| [Carga, ciclos originales60 s](13_raw/r4_cargo_cycles_01/summary.json) | 0 / 0 | 0 / 0 | 0 / 0 |
| [Colocación corregida60 s](13_raw/r4_release_fix_01/summary.json) | 0 / 0 | 0 / 0 | 0 / 0 |
| [Transición corregida60 s](13_raw/r4_transition_fix_01/summary.json) | 0 / 0 | 0 / 0 | 0 / 0 |
| [Espera FREE corregida120 s](13_raw/r4_free_wait_fix_01/summary.json) | 0 / 0 | 0 / 0 | 0 / 0 |
| [Cliente manual120 s](05_raw/r4_manual_01/summary.json) | 0 / 0 | 0 / 0 | 0 / 0 |

Los logs de la corrida4 están íntegros: [anfitrión](04_raw/iteration_4/host.log)
 y [cliente](04_raw/iteration_4/client.log). Los del experimento final:
[anfitrión](13_raw/r4_free_wait_fix_01/host.log),
[cliente](13_raw/r4_free_wait_fix_01/client.log).
Recuento literal, no equivalencia entre log limpio y gate aprobado.
Resumen de experimentos: [13_experiments_summary.json](13_experiments_summary.json).

---

# Logs de las dos instancias con ventana

Motor 4.7.2. Recuento literal de `ERROR:` y `WARNING:` en los logs de Godot,
no solo en el resumen del lanzador. Ambos procesos terminaron con código 0.
Un log limpio no significa que D95 haya pasado.

| Corrida | Anfitrión ERROR / WARNING | Cliente ERROR / WARNING | Resultado del gate |
|---|---:|---:|---|
| 1, 300 s, VSync on | 0 / 0 | 0 / 0 | Inválida: 5 ciclos cliente |
| 2, 300 s, VSync on | 0 / 0 | 0 / 0 | Válida y fallida |
| 3, 300 s, VSync off | 0 / 0 | 0 / 0 | Inválida: 4 ciclos cliente |

Logs íntegros de la corrida válida:
[anfitrión](04_raw/iteration_2/host.log) y [cliente](04_raw/iteration_2/client.log).
La tercera conserva también [anfitrión](04_raw/iteration_3/host.log) y
[cliente](04_raw/iteration_3/client.log).

Prueba manual de 180 s, cliente visible y anfitrión sin ventana:
[anfitrión](05_raw/manual_02/host.log) y [cliente](05_raw/manual_02/client.log),
ambos 0 ERROR / 0 WARNING. No hubo ciclos manuales de carga completados.

Estos recuentos no describen los logs de gdUnit: las suites ejercitan rutas
negativas que imprimen errores esperados y fixtures con avisos ya documentados.
