> Histórico anterior a revisión 04: la corrida es inválida por actividad.
> P99 no acredita jitter cuando falta apoyo; FPS con max_fps=120 no se juzgan;
> las penetraciones remotas son diagnóstico. Véase la reemisión de corrida 2.

# Gate — corrida 1

Resultado registrado: **invalid**, válida: **False**. Aprobación humana: pendiente.

Muestreo idéntico: observador independiente `GateMetrics`, `_physics_process`, `process_physics_priority=1000`, `process_priority=1000`, después de todos los escritores y del movimiento. El observador no escribe transformadas ni manda input.

El deslizamiento es el desplazamiento local total por tick: incluye caminar y, si ocurre, quedar fuera del bus. No se descartan esas muestras.

| Métrica | Anfitrión | Cliente |
|---|---:|---:|
| duration_s | 300.000000 | 300.000000 |
| ticks | 18000.000000 | 18000.000000 |
| slip p95_m | 0.033740 | 0.910274 |
| slip p99_m | 0.118148 | 1.299582 |
| slip p999_m | 0.245364 | 1.744079 |
| slip max_m | 0.444941 | 2.782799 |
| slip samples | 17999.000000 | 17999.000000 |
| p99 cliente permitido (1,5 × anfitrión) | — | 0.177222 |
| Cociente p99 cliente/anfitrión | — | 10.999588 |
| Ticks sin apoyo en el bus | 74.000000 | 17340.000000 |
| Penetración max_depth_m | 0.211209 | 0.133839 |
| Penetración max_run_ticks | 386.000000 | 26.000000 |
| FPS p1 | 52.460392 | 52.454889 |
| FPS percent_below_60 | 74.915254 | 74.931926 |
| FPS frames | 17995.000000 | 17995.000000 |
| Render VSync / max_fps / viewport | VSync proyecto, max_fps=120 | VSync proyecto, max_fps=120 |
| Cámaras activas mínimo/máximo | 1/1 | 1/1 |
| unauthorized_cargo_simulation_ticks | 0.000000 | 0.000000 |
| remote_crew_simulation_ticks | 0.000000 | 0.000000 |
| ERROR / WARNING | 0/0 | 0/0 |
| Código de salida del proceso | 0 | 0 |

El máximo de deslizamiento se informa; no decide el resultado. Penetración: cajas finitas del casco, hueco de la puerta excluido; límites 0,05 m y 3 ticks. Se excluyen únicamente cuerpos con colisión desactivada por estado (tripulante sentada o carga HELD).

| Actividad confirmada | Anfitrión | Cliente |
|---|---:|---:|
| authority_transfers | 0.000000 | 22.000000 |
| complete_cycles | 130.000000 | 5.000000 |
| hold_denied | 0.000000 | 0.000000 |
| hold_granted | 131.000000 | 6.000000 |
| hold_requested | 131.000000 | 6.000000 |
| release | 130.000000 | 5.000000 |
| strap_denied | 0.000000 | 0.000000 |
| strap_ok | 131.000000 | 6.000000 |
| unstrap | 130.000000 | 5.000000 |

| Error remoto | Anfitrión | Cliente |
|---|---:|---:|
| bus p95_m | no aplica | 1.228840 |
| bus max_m | no aplica | 1.857352 |
| bus p95_deg | no aplica | 2.161932 |
| bus max_deg | no aplica | 4.121983 |
| bus matched | 0 | 3001 |
| bus unmatched | 0 | 0 |
| crew p95_m | 0.106764 | 1.474476 |
| crew max_m | 1.196004 | 2.200601 |
| crew p95_deg | 1.542562 | 43.859045 |
| crew max_deg | 111.886948 | 159.482895 |
| crew matched | 3000 | 3001 |
| crew unmatched | 1 | 0 |
| cargo p95_m | 0.695635 | 1.618872 |
| cargo max_m | 0.739959 | 3.201451 |
| cargo p95_deg | 33.050025 | 10.494938 |
| cargo max_deg | 45.195563 | 179.071905 |
| cargo matched | 52 | 11930 |
| cargo unmatched | 11 | 11 |

Errores contra la autoridad al mismo instante UTC, sin corregir la latencia por desplazamiento del reloj. Interpolación entre muestras de traza a 10 Hz; sin extrapolar ni cruzar cambios de autoridad.

| Cuerpo: penetración máxima / racha máxima | Anfitrión | Cliente |
|---|---:|---:|
| cargo/Package_0 | 0.000000 m / 0 ticks | 0.000000 m / 0 ticks |
| cargo/Package_1 | 0.000000 m / 0 ticks | 0.000000 m / 0 ticks |
| cargo/Package_2 | 0.098337 m / 26 ticks | 0.128634 m / 26 ticks |
| cargo/Package_3 | 0.066724 m / 26 ticks | 0.032083 m / 23 ticks |
| crew/1 | 0.135387 m / 14 ticks | 0.133839 m / 13 ticks |
| crew/463068487 | 0.211209 m / 386 ticks | 0.056446 m / 17 ticks |

Motivos registrados:

- client: fewer than ten complete cargo cycles
- host: hull penetration exceeds 0.05 m
- host: hull penetration exceeds 3 ticks
- host: FPS p1 below 60
- client: hull penetration exceeds 0.05 m
- client: hull penetration exceeds 3 ticks
- client: FPS p1 below 60
- client slip p99 exceeds 1.5 times same-run host

Ruta: recta por x=30, con retorno exterior sin teletransportar. Vueltas: 12. Velocidades de entrada (km/h): 66.417, 82.385, 82.710, 81.165, 82.722, 82.180, 82.512, 81.156, 82.654, 82.501, 82.381, 82.706, 81.163. Velocidad media/mínima/máxima del tramo medido: 62.952 / 42.281 / 82.722 km/h. El contador histórico de velocidades cubre z=[2,46], no los últimos metros de la última rampa.

Margen de interpolación del bus: receptor reiniciado por llegada, un intervalo nominal.

Datos íntegros: [iteration_1/summary.json](04_raw/iteration_1/summary.json); [log anfitrión](04_raw/iteration_1/host.log), [log cliente](04_raw/iteration_1/client.log). Los JSON por instancia incluyen contadores de integración por cuerpo.
