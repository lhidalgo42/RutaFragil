# Experimento final de 300 s — precondición D incumplida

**Se detiene la ronda. No se lanza el tercer gate ni otra reducción.** D96
conserva dos fallos válidos (corridas2 y4), con el tercero sin consumir.
La acotación E sigue pendiente del dueño; se actúa como firme según su prompt.
El revisor redactará el plan B; aquí no se redacta ni implementa.

Código: `25c7a72206666cccfd748ee67c1a3de94068373b`, árbol fuente limpio verificado por el
lanzador. Configuración íntegra, incluidos tuning/mods efectivos, en
[summary.json](18_raw/r5_final_300/summary.json). 300s, 18000ticks por instancia,
carga on, ciclos activos, human=none, ambas ventanas, VSync off y max_fps=0.
Solo se aplica candidato(a), sincronización de fase de las peticiones; candidato(b)
se rechazó en el banco. No hay cambios de física después de este experimento.

Muestreo: **GateMetrics independiente postnodos, process_priority=1000 y
process_physics_priority=1000**, mismo punto en las dos instancias. El bus
cliente y la carga escriben antes; la identidad de plataforma se infiere por
velocidad de contacto porque no hay get_platform_rid() público en este motor.

| Precondición D | Anfitrión | Cliente | Requisito |
|---|---:|---:|---|
| Apoyo % | 99.983333 | 27.333333 | ≥95% |
| Ticks apoyados | 17997 | 4920 | sobre18000 |
| Apoyo en último tick | Sí | No | sí |
| Mayor pérdida, ticks | 2 | 13078 | ≤30 |

El cliente queda definitivamente sin apoyo desde tick4923 (82,05s), durante
13078ticks /217,967s hasta el final. La mejora de liberación no basta para
viajar. El código0 del lanzador significa experimento terminado, **no D verde**.
La guardia informa también `host: incomplete observation`: faltan formas
activas de Package_2 yPackage_3 en alguna transición. Las18000 muestras de
apoyo y17999 desplazamientos sí están completas; no se borra aquella alerta.
No cambia el incumplimiento inequívoco del cliente en los tres requisitos D.

## Cada flanco y su recuperación

| Instancia | Pierde en tick | Tiempo s | Recupera en tick | Ticks sin apoyo | Estado final del flanco |
|---|---:|---:|---:|---:|---|
| host | 1592 | 26.533333 | 1594 | 2 | Recuperada |
| host | 2237 | 37.283333 | 2238 | 1 | Recuperada |
| client | 1040 | 17.333333 | 1042 | 2 | Recuperada |
| client | 4923 | 82.050000 | — | 13078 | NO recuperada |

Volcados íntegros, con los tres ticks previos y ambos lados del flanco:
[anfitrión](18_raw/r5_final_300/host_support_losses.json),
[cliente](18_raw/r5_final_300/client_support_losses.json).
[CSV anfitrión](18_raw/r5_final_300/host_ticks.csv) y
[CSV cliente](18_raw/r5_final_300/client_ticks.csv) permiten reconstruir todas
las rachas, sin deducir recuperación del porcentaje global.

En el tick1039 anterior a la primera pérdida cliente, plataforma
(−17,288702;0,003224;−2,163170)m/s coincide con Package_2. El contacto del bus
publica(−18,799116;0,000966;−2,081796)m/s. Hay caja y bus simultáneamente.
Esto conserva el mecanismo de adopción en la corrida real pese al arreglo
específico de fase. No demuestra que sea la única causa de la pérdida final;
no se hace otra reducción para perseguirla fuera del límite E.

## Métricas descriptivas, sin veredicto de gate

| Métrica | Anfitrión | Cliente |
|---|---:|---:|
| Desplazamiento p95_m | 0.033607 | 0.828852 |
| Desplazamiento p99_m | 0.033865 | 1.201795 |
| Desplazamiento p999_m | 0.035788 | 1.565183 |
| Desplazamiento max_m | 0.423723 | 1.805547 |
| Penetración local observada max_depth_m | 0.027387 | 0.128690 |
| Penetración local observada max_run_ticks | 0 | 9 |
| FPS p1 | 250.312891 | 272.553829 |
| FPS percent_below_60 | 0.002713 | 0.002548 |
| hold_requested | 117 | 456 |
| hold_granted | 117 | 34 |
| hold_denied | 0 | 422 |
| release | 116 | 34 |
| strap_ok | 116 | 34 |
| strap_denied | 0 | 0 |
| unstrap | 116 | 34 |
| authority_transfers | 0 | 136 |
| complete_cycles | 116 | 34 |
| Cámaras mín/máx | 1 / 1 | 1 / 1 |
| Simulación carga sin autoridad | 0 | 0 |
| Simulación crew remota | 0 | 0 |

El p99 cliente **no es jitter** porque no viaja. No se juzga el cociente1,5×.
Los FPS son medidos sin VSync ni tope; no conceden aprobación humana.

| Error remoto al mismo UTC | Anfitrión | Cliente |
|---|---:|---:|
| bus p95_m | No aplica | 1.920082 |
| bus max_m | No aplica | 2.006786 |
| bus p95_deg | No aplica | 3.342343 |
| bus max_deg | No aplica | 6.478232 |
| crew p95_m | 0.944109 | 1.168346 |
| crew max_m | 1.217764 | 1.268329 |
| crew p95_deg | 4.123883 | 36.367940 |
| crew max_deg | 167.469709 | 174.948944 |
| cargo p95_m | 1.573142 | 2.285631 |
| cargo max_m | 1.924220 | 3.350526 |
| cargo p95_deg | 12.658297 | 8.410365 |
| cargo max_deg | 88.489841 | 160.666540 |

El p95 remoto de bus cliente, 1,920082 m, equivale a unos 87 ms a 22 m/s.
Estos errores incluyen latencia de interpolación en metros: no son error de
simulación aislado. Como escala, dividir por22m/s aproxima el retardo espacial;
para crew/carga también intervienen sus movimientos propios y expulsiones.
No se compensó latencia ni se aisló el residuo.

## Logs y capturas

Hijos0/0, lanzador0; cero ERROR y cero WARNING en
[host.log](18_raw/r5_final_300/host.log) y
[client.log](18_raw/r5_final_300/client.log).
Capturas automáticas: [cliente inicial](18_raw/r5_final_300/client_ready.png),
[cliente durante corrida](18_raw/r5_final_300/client_running.png),
[anfitrión](18_raw/r5_final_300/host_running.png).
La captura cliente durante corrida es una vista muy próxima de geometría y
no acredita legibilidad ni interacción manual. No se jugó manualmente esta
configuración durante el experimento guionizado ni se declara el gate aprobado.
El contador D96 y los históricos permanecen intactos.
