# Ronda5 — regresiones sobre25c7a72

[Resultados](06_r5_results.json): demo0, conducción0, red larga0. Sin timeout.
[Demo](06_r5_demo.log): lap_completed,27,3s,17waypoints,64,6km/h máximos,
upright0,97. [Red larga](06_r5_net_long.log): host+tres clientes,16waypoints,
convergencia y salidas correctas. Red corta pasa en las tres suites y strict.

| Cifra | Medida | Referencia |
|---|---:|---:|
| Altura reposo |0,977m|0,977m|
|0–60km/h|6,93s|6,93s|
|Velocidad máxima|90,0km/h|90,0km/h|
|Radio giro|12,4m|12,4m|
|Frenada desde50km/h|6,7m|6,7m|
|Tiempo frenada|0,98s|0,98s|

[Medición](06_r5_handling.log). Bus, suspensión, tuning, escenas y ajustes
persistentes del proyecto no cambiaron. No se emite un nuevo juicio de sensación.

REGISTRO HISTÓRICO

# Regresiones de ronda 4

Motor 4.7.2, Jolt. Fuentes finales `1eeb635`, verificadas desde `266f459`
(el commit intermedio solo añade evidencia). Plazos externos de 120 s para
la demo y la medición de conducción, y 350 s para la red larga.

| Prueba | Resultado | Evidencia |
|---|---|---|
| run_demo, fixed-fps 60 | Código 0; lap_completed, 27,3 s, 17 waypoints, máximo 64,6 km/h, upright 0,97 | [Log](06_r4_demo.log) |
| Red larga, 16 waypoints | Código 0; anfitrión + 3 clientes, 4 marcadores por cliente; desviación y yaw finales 0 | [Log](06_r4_net_long.log) |
| Red corta | Código 0 en cada uno de los tres arneses y en la sonda estricta | [Arnés 1](02_r4_run_1.log), [2](02_r4_run_2.log), [3](02_r4_run_3.log), [estricto](02_r4_unsafe.log) |

| Cifra de conducción | Referencia | Ronda 4 |
|---|---:|---:|
| Altura en reposo | 0,977 m | 0,977 m |
| 0–60 km/h | 6,93 s | 6,93 s |
| Velocidad máxima | 90,0 km/h | 90,0 km/h |
| Radio de giro | 12,4 m | 12,4 m |
| Distancia de frenada desde 50 km/h | 6,7 m | 6,7 m |
| Tiempo de frenada | 0,98 s | 0,98 s |

Las seis cifras coinciden con la referencia: [medición](06_r4_handling.log).
Son medidas de regresión automática; no constituyen un juicio nuevo de sensación.
Los tres procesos terminaron en código 0, sin timeout y con stderr vacío:
[resultados](06_r4_results.json). Bus, suspensión, tuning, escenas y ajustes
persistentes de proyecto conservan diff vacío respecto de `fefc4d8`.

Lo que sigue conserva el registro histórico anterior a esta ronda.

# Regresiones de integración — histórico anterior a ronda 4

Motor 4.7.2, Jolt. Regresiones históricas sobre el código de simulación
(47c3b41; el cambio posterior 95455f5 solo endurece el envoltorio PowerShell).
Plazos externos: demo 120 s, manejo 120 s, red larga 350 s. No se modificó
el código del bus, suspensión, tuning, escenas ni ajustes de proyecto.

| Prueba | Resultado | Evidencia |
|---|---|---|
| run_demo, fixed-fps 60 | código 0, lap_completed, 27,3 s, 17 waypoints, máximo 64,6 km/h, upright 0,97 | [log](06_final_demo.log) |
| Red larga, 16 waypoints | código 0, anfitrión + 3 clientes, 4 marcadores; desviación y yaw finales 0 | [log](06_final_net_long.log) |
| Red corta | código 0 dentro del arnés completo con avisos inseguros elevados a error | [log](02_final_unsafe.log) |

| Cifra de conducción | Medida |
|---|---:|
| Altura en reposo | 0,977 m |
| 0–60 km/h | 6,93 s |
| Velocidad máxima | 90,0 km/h |
| Radio de giro | 12,4 m |
| Distancia de frenada desde 50 km/h | 6,7 m |
| Tiempo de frenada | 0,98 s |

Las seis coinciden con la referencia aprobada: [salida de medición](06_final_handling.log).
Esto acredita cifras y regresión automática; no constituye un juicio nuevo de sensación.

[Resultados y códigos](06_final_results.json): 0 / 0 / 0; stderr vacío en
las tres regresiones. El primer intento del envoltorio de medición conservó
un ExitCode nulo (06_runner_initial_result.json), no se aceptó: se repitieron
las tres usando un Process con handle retenido.
