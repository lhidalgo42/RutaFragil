# Gate — corrida 4, reemisión histórica con D95 v5 / D98

**Reemisión de penetración, revisión 05:** el máximo sigue limitado a 5 cm;
la racha se juzga solo por encima de 3 cm. Las rachas históricas de abajo
contaban >1 µm y quedan como diagnóstico, no como criterio vigente.
No se guardó profundidad/estado por cuerpo y tick para reconstruir todas las
rachas o un histograma fino. Véase [reemisión y límites](17_penetration_revision_05.md).
El veredicto fallido se conserva por salida del casco, empujón >45 ticks y penetración local >5 cm.

Resultado histórico conservado: **failed**; válida: **True**.
Aprobación humana pendiente. Reemisión documental D95 v5, 2026-09-17;
no se vuelve a ejecutar la corrida ni se modifican sus JSON/CSV.

Código de simulación: `19836c7`. Motor 4.7.2, Jolt. Dos ventanas, VSync=0, max_fps=0. Véase el ledger para el recuento de intentos válidos; los experimentos 13 no consumen D96.

Muestreo común: observador independiente `GateMetrics`, después de los nodos, `process_priority=1000`, `process_physics_priority=1000`. No escribe transformadas ni input.

| Métrica | Anfitrión | Cliente |
|---|---:|---:|
| **hull_exit_ticks — exigido 0 (D95 v5)** | **0** | **14.494 — falla** |
| Apoyo local en bus (%), descriptivo | 99.988889 | 19.411111 |
| Empujones v5 confirmados | No reconstruible (0–1) | 5 |
| Duración máxima de empujón (ticks) | No reconstruible; pérdida observada de 2 ticks | ≥14.499, abierto — falla |
| p95/p99/p99,9/máximo filtrados v5 | No reconstruibles | No reconstruibles |
| Ticks apoyados / total | 17998/18000 | 3494/18000 |
| duration_s | 300.000000 | 300.000000 |
| ticks | 18000.000000 | 18000.000000 |
| off_bus_support_ticks | 2.000000 | 14506.000000 |
| support_loss_count | 1.000000 | 5.000000 |
| Desplazamiento sin filtrar p95_m (descriptivo) | 0.033638 | 0.843047 |
| Desplazamiento sin filtrar p99_m (descriptivo) | 0.033875 | 1.214998 |
| Desplazamiento sin filtrar p999_m (descriptivo) | 0.034045 | 1.572733 |
| Desplazamiento sin filtrar max_m (descriptivo) | 0.444929 | 1.803960 |
| Desplazamiento sin filtrar samples (descriptivo) | 17999.000000 | 17999.000000 |
| p99 filtrado v5 juzgado | No: falta historial de contactos | No: falta historial de contactos |
| Límite p99 histórico sin filtrar, no juzgado | — | 0.050812 |
| Cociente p99 sin filtrar, no juzgado | — | 35.867146 |
| Penetración de cuerpos simulados max_depth_m | 0.035662 | 0.066812 |
| Racha simulada >3 cm, revisión 05 | No reconstruible: 1–23; Package_3 = 0 | No reconstruible: 1–216 |
| FPS p1 | 146.713615 | 175.777817 |
| FPS percent_below_60 | 0.001774 | 0.001548 |
| FPS frames | 281861.000000 | 258376.000000 |
| Render verificado | True | True |
| Cámaras mínimo/máximo | 1.0/1.0 | 1.0/1.0 |
| unauthorized_cargo_simulation_ticks | 0.000000 | 0.000000 |
| remote_crew_simulation_ticks | 0.000000 | 0.000000 |
| ERROR / WARNING | 0/0 | 0/0 |
| Salida del hijo | 0.000000 | 0.000000 |

D95 v5 retira el umbral de apoyo. Los percentiles publicados son históricos
sin filtrar; falta contacto de carga por tick para seleccionar únicamente
apoyo sin contactos en los tres ticks anteriores. No se pueden juzgar con
el filtro v5. El máximo solo se reporta. Penetración: casco finito con hueco
de puerta excluido; máximo 5 cm y rachas ≤3 ticks por encima de 3 cm, solo
cuerpos simulados localmente. Réplicas y cuerpos congelados quedan en diagnóstico.

Recuento sobre los CSV [host](04_raw/iteration_4/host_ticks.csv) y
[cliente](04_raw/iteration_4/client_ticks.csv), ambos con ticks 1–18.000
consecutivos. Aplicado literalmente `BusInterior.is_inside_local`:
`abs(x)<=1.15`, `-0.65<=y<=1.30`, `-3.8<=z<=3.8`; límites inclusivos,
sin tolerancia adicional. Cliente fuera desde 3.507 hasta 18.000 inclusive;
anfitrión siempre dentro.

Los volcados de pérdidas de apoyo guardan aquí solo el tick inmediatamente
anterior, no los tres. En el [cliente](04_raw/iteration_4/client_support_losses.json)
ese tick ya contiene contacto de carga en los cinco eventos: los cinco
califican como empujón v5. En el [host](04_raw/iteration_4/host_support_losses.json)
no lo contiene y faltan los otros dos: su único evento no es clasificable.
Las recuperaciones y duraciones se reconstruyen del CSV:

| Instancia | Pérdida | Recuperación | Ticks sin apoyo observados | Empujón v5 |
|---|---:|---:|---:|---|
| Host | 5795 | 5797 | 2 | Desconocido |
| Cliente | 415 | 417 | 2 | Sí |
| Cliente | 571 | 572 | 1 | Sí |
| Cliente | 2496 | 2498 | 2 | Sí |
| Cliente | 3486 | 3488 | 2 | Sí |
| Cliente | 3502 | Sin recuperación al tick 18000 | ≥14.499 | Sí; abierto |

La duración del evento abierto es un límite inferior de su duración total.
No se reemite un máximo de desplazamiento por empujón en este histórico.

| Actividad confirmada | Anfitrión | Cliente |
|---|---:|---:|
| authority_transfers | 0.000000 | 100.000000 |
| complete_cycles | 120.000000 | 25.000000 |
| hold_denied | 0.000000 | 467.000000 |
| hold_granted | 121.000000 | 25.000000 |
| hold_requested | 121.000000 | 492.000000 |
| release | 120.000000 | 25.000000 |
| strap_denied | 0.000000 | 0.000000 |
| strap_ok | 121.000000 | 25.000000 |
| unstrap | 121.000000 | 25.000000 |

| Error remoto | Anfitrión | Cliente |
|---|---:|---:|
| bus p95_m | no aplica | 1.869117 |
| bus max_m | no aplica | 2.117781 |
| bus p95_deg | no aplica | 3.266986 |
| bus max_deg | no aplica | 6.407748 |
| bus matched | 0.000000 | 3000.000000 |
| bus unmatched | 0.000000 | 1.000000 |
| crew p95_m | 0.974641 | 1.120404 |
| crew max_m | 1.181645 | 1.985883 |
| crew p95_deg | 3.328961 | 36.520021 |
| crew max_deg | 151.487899 | 144.360966 |
| crew matched | 3000.000000 | 3000.000000 |
| crew unmatched | 1.000000 | 1.000000 |
| cargo p95_m | 1.465845 | 2.230757 |
| cargo max_m | 2.161266 | 3.193004 |
| cargo p95_deg | 11.364755 | 8.462645 |
| cargo max_deg | 88.214598 | 156.722392 |
| cargo matched | 323.000000 | 11580.000000 |
| cargo unmatched | 47.000000 | 51.000000 |

Error contra la autoridad al mismo UTC local; trazas 10 Hz interpoladas, sin extrapolar ni cruzar transferencias de autoridad. No se inventan umbrales.

| Penetración histórica por cuerpo: profundidad / racha >1 µm (no juzgada desde revisión 05) | Anfitrión | Cliente |
|---|---:|---:|
| cargo/Package_0 | 0.000000 m / 0 ticks; 18000 excluidos | 0.000000 m / 0 ticks; 18000 excluidos |
| cargo/Package_1 | 0.000000 m / 0 ticks; 18000 excluidos | 0.000000 m / 0 ticks; 18000 excluidos |
| cargo/Package_2 | 0.035662 m / 23 ticks; 14879 excluidos | 0.000000 m / 0 ticks; 18000 excluidos |
| cargo/Package_3 | 0.025533 m / 4391 ticks; 2872 excluidos | 0.000000 m / 0 ticks; 18000 excluidos |
| crew/1 | 0.000636 m / 4 ticks; 0 excluidos | 0.000000 m / 0 ticks; 18000 excluidos |
| crew/1386637681 | 0.000000 m / 0 ticks; 18000 excluidos | 0.066812 m / 216 ticks; 0 excluidos |

Motivos de fallo conservados al reemitir con v5:

- Revisión 05: duración de penetración anfitrión no reconstruible; se retira este motivo histórico.
- client: 14.494 ticks fuera del casco (D95 v5 exige cero).
- client: empujón abierto durante al menos 14.499 ticks (máximo permitido 45).
- client: hull penetration exceeds 0.05 m
- Revisión 05: duración de penetración cliente no reconstruible; se retira este motivo histórico.

Ruta y velocidades medidas: `{"bump_ticks": 1509.0, "bumps_max_kmh": 82.6990081787109, "bumps_mean_kmh": 62.9953328354458, "bumps_min_kmh": 42.2814743041992, "entry_speeds_kmh": [66.4168785095215, 80.9707077026367, 82.6710754394531, 82.4042037963867, 82.6839775085449, 80.9212280273438, 82.5053604125977, 80.9296943664551, 82.6990081787109, 81.1575439453125, 80.9206237792969, 81.1539665222168, 81.0046691894531], "laps": 12.0, "route": "straight_x30_with_outer_return"}`.

Datos completos: [summary.json](04_raw/iteration_4/summary.json). Logs: [anfitrión](04_raw/iteration_4/host.log), [cliente](04_raw/iteration_4/client.log). Los JSON incluyen diagnóstico de penetraciones excluidas y contadores por entidad.

Interpretación del error remoto: se compara al mismo UTC sin compensar
interpolación. El bus p95 ~1,87 m a ~22 m/s equivale a ~85 ms; la tripulante
p95 ~1 m incluye su propio retardo. No se ha aislado todo el error residual.
