> Histórico anterior a revisión 04: la corrida es inválida por actividad.
> P99 no acredita jitter cuando falta apoyo; FPS con max_fps=120 no se juzgan;
> las penetraciones remotas son diagnóstico. Véase la reemisión de corrida 2.

# Gate — corrida 3

Resultado registrado: **invalid**, válida: **False**. Aprobación humana: pendiente.

Muestreo idéntico: observador independiente `GateMetrics`, `_physics_process`, `process_physics_priority=1000`, `process_priority=1000`, después de todos los escritores y del movimiento. El observador no escribe transformadas ni manda input.

El deslizamiento es el desplazamiento local total por tick: incluye caminar y, si ocurre, quedar fuera del bus. No se descartan esas muestras.

| Métrica | Anfitrión | Cliente |
|---|---:|---:|
| duration_s | 300.000000 | 300.000000 |
| ticks | 18000.000000 | 18000.000000 |
| slip p95_m | 0.033726 | 0.835994 |
| slip p99_m | 0.146832 | 1.087736 |
| slip p999_m | 0.247698 | 1.340863 |
| slip max_m | 0.351907 | 1.363685 |
| slip samples | 17999.000000 | 17999.000000 |
| p99 cliente permitido (1,5 × anfitrión) | — | 0.220248 |
| Cociente p99 cliente/anfitrión | — | 7.408022 |
| Ticks sin apoyo en el bus | 103.000000 | 17562.000000 |
| Penetración max_depth_m | 0.307565 | 0.788603 |
| Penetración max_run_ticks | 2979.000000 | 2979.000000 |
| FPS p1 | 104.931794 | 106.292517 |
| FPS percent_below_60 | 0.016676 | 0.013895 |
| FPS frames | 35979.000000 | 35984.000000 |
| Render VSync / max_fps / viewport | {'max_fps': 120.0, 'viewport_size': [1152.0, 648.0], 'vsync_mode': 0.0} | {'max_fps': 120.0, 'viewport_size': [1152.0, 648.0], 'vsync_mode': 0.0} |
| Cámaras activas mínimo/máximo | 1/1 | 1/1 |
| unauthorized_cargo_simulation_ticks | 0.000000 | 0.000000 |
| remote_crew_simulation_ticks | 0.000000 | 0.000000 |
| ERROR / WARNING | 0/0 | 0/0 |
| Código de salida del proceso | 0 | 0 |

El máximo de deslizamiento se informa; no decide el resultado. Penetración: cajas finitas del casco, hueco de la puerta excluido; límites 0,05 m y 3 ticks. Se excluyen únicamente cuerpos con colisión desactivada por estado (tripulante sentada o carga HELD).

| Actividad confirmada | Anfitrión | Cliente |
|---|---:|---:|
| authority_transfers | 0.000000 | 16.000000 |
| complete_cycles | 128.000000 | 4.000000 |
| hold_denied | 0.000000 | 565.000000 |
| hold_granted | 129.000000 | 4.000000 |
| hold_requested | 129.000000 | 569.000000 |
| release | 128.000000 | 4.000000 |
| strap_denied | 0.000000 | 0.000000 |
| strap_ok | 128.000000 | 4.000000 |
| unstrap | 128.000000 | 4.000000 |

| Error remoto | Anfitrión | Cliente |
|---|---:|---:|
| bus p95_m | no aplica | 2.106252 |
| bus max_m | no aplica | 2.202744 |
| bus p95_deg | no aplica | 3.604674 |
| bus max_deg | no aplica | 6.859641 |
| bus matched | 0 | 3001 |
| bus unmatched | 0 | 0 |
| crew p95_m | 0.110001 | 1.375194 |
| crew max_m | 1.436413 | 1.482003 |
| crew p95_deg | 0.915998 | 17.699230 |
| crew max_deg | 103.881064 | 173.173149 |
| crew matched | 3000 | 3001 |
| crew unmatched | 1 | 0 |
| cargo p95_m | 1.077106 | 2.465798 |
| cargo max_m | 1.366080 | 4.582327 |
| cargo p95_deg | 46.903937 | 10.899556 |
| cargo max_deg | 96.654048 | 179.291687 |
| cargo matched | 37 | 11950 |
| cargo unmatched | 8 | 9 |

Errores contra la autoridad al mismo instante UTC, sin corregir la latencia por desplazamiento del reloj. Interpolación entre muestras de traza a 10 Hz; sin extrapolar ni cruzar cambios de autoridad.

| Cuerpo: penetración máxima / racha máxima | Anfitrión | Cliente |
|---|---:|---:|
| cargo/Package_0 | 0.000000 m / 0 ticks | 0.000000 m / 0 ticks |
| cargo/Package_1 | 0.000000 m / 0 ticks | 0.000000 m / 0 ticks |
| cargo/Package_2 | 0.180368 m / 26 ticks | 0.169187 m / 26 ticks |
| cargo/Package_3 | 0.023820 m / 2979 ticks | 0.022159 m / 2979 ticks |
| crew/1 | 0.074850 m / 5 ticks | 0.098974 m / 48 ticks |
| crew/1848947356 | 0.307565 m / 163 ticks | 0.788603 m / 12 ticks |

Motivos registrados:

- client: fewer than ten complete cargo cycles
- host: hull penetration exceeds 0.05 m
- host: hull penetration exceeds 3 ticks
- client: hull penetration exceeds 0.05 m
- client: hull penetration exceeds 3 ticks
- client slip p99 exceeds 1.5 times same-run host

Ruta: recta por x=30, con retorno exterior sin teletransportar. Vueltas: 12. Velocidades de entrada (km/h): 66.417, 80.971, 82.671, 82.404, 82.684, 80.921, 82.505, 80.930, 82.699, 81.158, 80.921, 81.154, 81.005. Velocidad media/mínima/máxima del tramo medido: 62.995 / 42.281 / 82.699 km/h. El contador histórico de velocidades cubre z=[2,46], no los últimos metros de la última rampa.

Margen de interpolación del bus: 0.0666666666666667.

Datos íntegros: [iteration_3/summary.json](04_raw/iteration_3/summary.json); [log anfitrión](04_raw/iteration_3/host.log), [log cliente](04_raw/iteration_3/client.log). Los JSON por instancia incluyen contadores de integración por cuerpo.
