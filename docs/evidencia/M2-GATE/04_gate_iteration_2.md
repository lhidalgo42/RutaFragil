# Gate — corrida 2, reemisión histórica con D95 v5 / D98

**Reemisión de penetración, revisión 05:** el máximo sigue limitado a 5 cm;
la racha se juzga solo por encima de 3 cm. Las rachas históricas de abajo
contaban >1 µm y quedan como diagnóstico, no como criterio vigente.
No se guardó profundidad/estado por cuerpo y tick para reconstruir todas las
rachas o un histograma fino. Véase [reemisión y límites](17_penetration_revision_05.md).
El veredicto fallido se conserva por salida del casco y penetración local >5 cm.

Veredicto conservado: **failed**, válida: **True**. Aprobación humana: pendiente.

**Reemisión D95 v5, 2026-09-17:** la tripulante cliente está fuera del casco
**16.784 ticks**. El apoyo 6,633333 % queda descriptivo, sin umbral.
El p99 publicado no está filtrado; falta contacto de carga por tick para
reconstruir el filtro v5 de apoyo y ausencia de contacto en los tres ticks
anteriores. No se juzga como jitter. FPS históricos conservados, pero no
evaluables: VSync=1 y max_fps=120. No se vuelve a ejecutar la corrida ni se
modifican sus JSON/CSV originales.
Reducción derivada: [04_iteration_2_revision_04.json](04_iteration_2_revision_04.json).

La corrección de penetraciones excluye las réplicas, pero los datos de las
tripulantes **locales** aún superan el límite de profundidad. Esto contradice la frase
«queda un motivo» de revisión04 y se declaró antes de editar. La carga histórica
no tiene profundidad, estado y autoridad por tick suficientes para reconstruir
su agregado dinámico; sus cifras se conservan únicamente como diagnóstico.

Muestreo idéntico: observador independiente `GateMetrics`, `_physics_process`, `process_physics_priority=1000`, `process_priority=1000`, después de todos los escritores y del movimiento. El observador no escribe transformadas ni manda input.

El deslizamiento histórico sin filtrar es el desplazamiento local total por
tick: incluye caminar y quedar fuera del bus. Se conserva como descriptivo.

Recuento sobre los CSV [host](04_raw/iteration_2/host_ticks.csv) y
[cliente](04_raw/iteration_2/client_ticks.csv), ambos con ticks 1–18.000
consecutivos. Aplicado literalmente `BusInterior.is_inside_local`:
`abs(x)<=1.15`, `-0.65<=y<=1.30`, `-3.8<=z<=3.8`; límites inclusivos,
sin tolerancia adicional. Cliente fuera en 334–372 y 1.256–18.000, intervalos
inclusivos; anfitrión siempre dentro. Salida de volumen y penetración son
métricas distintas. Los contactos históricos no permiten clasificar todos
los empujones con la ventana v5; no se infiere cero.

| Métrica | Anfitrión | Cliente |
|---|---:|---:|
| **hull_exit_ticks — exigido 0 (D95 v5)** | **0** | **16.784 — falla** |
| Apoyo local: ticks / total (%), descriptivo | 17921 / 18000 (99,561111 %) | 1194 / 18000 (6,633333 %) |
| Empujones v5: cantidad / duración máxima | No reconstruible | No reconstruible |
| p95/p99/p99,9/máximo filtrados v5 | No reconstruibles | No reconstruibles |
| duration_s | 300.000000 | 300.000000 |
| ticks | 18000.000000 | 18000.000000 |
| Desplazamiento sin filtrar p95_m (descriptivo) | 0.033688 | 0.898092 |
| Desplazamiento sin filtrar p99_m (descriptivo) | 0.140457 | 1.191739 |
| Desplazamiento sin filtrar p999_m (descriptivo) | 0.250584 | 1.581391 |
| Desplazamiento sin filtrar max_m (descriptivo) | 0.351916 | 1.969739 |
| Desplazamiento sin filtrar samples (descriptivo) | 17999.000000 | 17999.000000 |
| Umbral p99 histórico; juicio no evaluable | — | 0.210685 |
| Cociente p99 sin filtrar, no juzgado | — | 8.484750 |
| Ticks sin apoyo en el bus | 79.000000 | 16806.000000 |
| Penetración local comprobada max_depth_m | 0.074849 | 0.200542 |
| Racha local >3 cm, revisión 05 | No reconstruible: 1–7 | No reconstruible: 1–58 |
| FPS p1 | 53.101105 | 52.372473 |
| FPS percent_below_60 | 74.915254 | 74.909697 |
| FPS frames | 17995.000000 | 17995.000000 |
| Render VSync / max_fps / viewport | {'max_fps': 120.0, 'viewport_size': [1152.0, 648.0], 'vsync_mode': 1.0} | {'max_fps': 120.0, 'viewport_size': [1152.0, 648.0], 'vsync_mode': 1.0} |
| Cámaras activas mínimo/máximo | 1/1 | 1/1 |
| unauthorized_cargo_simulation_ticks | 0.000000 | 0.000000 |
| remote_crew_simulation_ticks | 0.000000 | 0.000000 |
| ERROR / WARNING | 0/0 | 0/0 |
| Código de salida del proceso | 0 | 0 |

El máximo de deslizamiento se informa; no decide el resultado. Penetración: cajas finitas del casco, hueco de la puerta excluido; límites 0,05 m y 3 ticks por encima de 0,03 m. Se juzgan únicamente cuerpos que la instancia simula; las réplicas y la carga congelada quedan fuera. En este histórico se acredita la penetración de la tripulante local; no hay datos por tick para filtrar la carga.

| Actividad confirmada | Anfitrión | Cliente |
|---|---:|---:|
| authority_transfers | 0.000000 | 41.000000 |
| complete_cycles | 118.000000 | 10.000000 |
| hold_denied | 46.000000 | 0.000000 |
| hold_granted | 119.000000 | 11.000000 |
| hold_requested | 165.000000 | 11.000000 |
| release | 118.000000 | 10.000000 |
| strap_denied | 0.000000 | 0.000000 |
| strap_ok | 119.000000 | 10.000000 |
| unstrap | 119.000000 | 10.000000 |

| Error remoto | Anfitrión | Cliente |
|---|---:|---:|
| bus p95_m | no aplica | 2.456814 |
| bus max_m | no aplica | 2.566308 |
| bus p95_deg | no aplica | 4.034685 |
| bus max_deg | no aplica | 7.580382 |
| bus matched | 0 | 3001 |
| bus unmatched | 0 | 0 |
| crew p95_m | 0.538393 | 1.392757 |
| crew max_m | 1.465500 | 2.328886 |
| crew p95_deg | 2.199981 | 25.823127 |
| crew max_deg | 132.934838 | 169.424987 |
| crew matched | 2999 | 3001 |
| crew unmatched | 2 | 0 |
| cargo p95_m | 61.720501 | 2.737669 |
| cargo max_m | 126.513336 | 4.033123 |
| cargo p95_deg | 38.739645 | 18.113843 |
| cargo max_deg | 75.361766 | 179.535634 |
| cargo matched | 2896 | 9086 |
| cargo unmatched | 11 | 11 |

Errores contra la autoridad al mismo instante UTC, sin corregir la latencia por desplazamiento del reloj. Interpolación entre muestras de traza a 10 Hz; sin extrapolar ni cruzar cambios de autoridad.

| Diagnóstico histórico de todos los cuerpos (no agregado juzgado): profundidad / racha | Anfitrión | Cliente |
|---|---:|---:|
| cargo/Package_0 | 0.000000 m / 0 ticks | 0.000000 m / 0 ticks |
| cargo/Package_1 | 0.000000 m / 0 ticks | 0.000000 m / 0 ticks |
| cargo/Package_2 | 0.105043 m / 26 ticks | 0.147216 m / 26 ticks |
| cargo/Package_3 | 0.020001 m / 27 ticks | 0.020001 m / 27 ticks |
| crew/1 | 0.074849 m / 7 ticks | 0.386598 m / 51 ticks |
| crew/1320164969 | 0.410978 m / 164 ticks | 0.200542 m / 58 ticks |

Motivos corregidos (D96 sigue acumulando un fallo válido):

- client: 16.784 ticks fuera del casco (D95 v5 exige cero).
- host: local crew hull penetration exceeds 0.05 m
- client: local crew hull penetration exceeds 0.05 m

Ruta: recta por x=30, con retorno exterior sin teletransportar. Vueltas: 12. Velocidades de entrada (km/h): 66.417, 82.389, 80.989, 81.096, 80.807, 82.471, 82.446, 81.014, 82.706, 82.404, 80.896, 82.463, 81.147. Velocidad media/mínima/máxima del tramo medido: 62.657 / 42.281 / 82.706 km/h. El contador histórico de velocidades cubre z=[2,46], no los últimos metros de la última rampa.

Margen de interpolación del bus: 0.0666666666666667.

Datos íntegros: [iteration_2/summary.json](04_raw/iteration_2/summary.json); [log anfitrión](04_raw/iteration_2/host.log), [log cliente](04_raw/iteration_2/client.log). Los JSON por instancia incluyen contadores de integración por cuerpo.

Interpretación del error remoto: se compara al mismo UTC sin compensar
interpolación. El bus p95 2,456814 m a ~22 m/s equivale a ~112 ms; la tripulante
p95 ~1 m incluye su propio retardo. No se ha aislado todo el error residual.
