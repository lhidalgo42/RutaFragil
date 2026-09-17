# 12 — Orden de escritura: g2.1 retirado en revisión 03

**Resolución de ronda 3b:** `docs/revisiones/M2-GATE_revision_03.md` retira
el requisito y autoriza eliminar su test (187 → 186 en ambos arneses).
Se conservan íntegros los diagnósticos siguientes como histórico. No se
ajustó el umbral. D95 exige ahora observador dedicado postnodos, prioridad
física 1000, igual para todas las filas y ambas instancias. El punto de
escritura no constituye un gate. NetBusSync mantuvo physics_frame al cerrar
fase 0; la elección posterior de nodo a −100 se documenta separadamente en
`04_timing_resolution.md`. No restablece el requisito retirado.

2026-09-16. Motor `4.7.2.stable.official.ed1daf0bf`, Windows, Jolt. No es una
iteración del gate de 300 s (D96), ni decide A/B. Se detuvo la búsqueda de arreglos
tras tres ensayos dirigidos; la fuente original aportada después permitió
replantear la instrumentación y reproducir la discrepancia sin cambiar la física.

## Resultado verificable

La sonda original del revisor se reproduce intacta. Un observador añadido a
ese mismo montaje conserva la medición original y toma una segunda lectura
después de los nodos: ambas escrituras dan máximo **0.600858509540558 m**.
Las 1800 filas completas de las once columnas comunes coinciden exactamente;
la lectura original de señal da **0.158623680472374 m** en esa misma corrida.
La separación original depende del reloj de medición. La contraprueba y sus
CSV pareados están detallados más abajo.

El test independiente con escenas reales y variantes explícitas también da
el mismo deslizamiento en ambos órdenes: **0.616668701171875 m** por tick.
El criterio pedido `< 0.3 m` para la señal falla. No hay rojo/verde: g2.1 sigue
rojo y no se modificó su umbral.

| Ensayo | Escritura | Deslizamiento máximo m | Plataforma cero en saltos | Código |
|---|---|---:|---:|---:|
| Fixture plano inicial, diagnóstico | señal | no registrado | 58/58 | 100 |
| Escenas reales, mismo criterio inicial | señal | 0.6167 | 58/58 | 100 |
| Escenas reales, notificación forzada | señal + `force_update_transform()` | 0.6167 | 58/58 | 100 |
| Test final, criterio de deslizamiento | señal / nodo explícitos | 0.616668701 / 0.616668701 | 58/58 en ambos (solo diagnóstico) | 100 |

Logs: `12_diagnosis.log`, `12_real_bus_signal.log`,
`12_real_bus_signal_force.log`, `12_slip_common_phase.log`.
`force_update_transform()` se retiró después de comprobar que no cambiaba nada.

El test final tiene una sola prueba. Crea `bus.tscn` congelado en KINEMATIC a
`(0,1,0)` y `crew_member.tscn` a `(0,0.4,0.5)`, espera 30 ticks y suministra 120
ticks de trayectoria recta a 18.5 m/s, con una foto cada dos ticks. El muestreador
corre en `_physics_process` con **process_physics_priority=1000** en ambas
variantes. `NodeWriter`, subclase exclusiva del test, sustituye la conexión de
`NetBusSync._ready()` por una llamada a `advance()` desde `_physics_process`.
La producción permanece conectada a `physics_frame`; no se edita entre mitades.
Se exige actividad (`moving_ticks > 40`) en ambas, deslizamiento de señal `<0.3`
y de nodo `>0.5`. La expectativa de velocidad en el mismo tick fue retirada por
la aclaración del dueño; la velocidad se conserva como diagnóstico.

Traza común a ambas mitades: tick 3 bus.z=0.6167, crew.z=0.5000,
plataforma=0; tick 4 bus.z=0.6167, crew.z=1.1167, plataforma=37 m/s.
El suelo sí se reconoce en ambos ticks. Esto registra un desfase de un tick;
no autoriza a afirmar que no existe transporte de plataforma.

Los logs antiguos `12_write_bad.log` y `12_write_good.log` proceden del ensayo
inicial del agente principal. Los nombres no son veredictos: ambos fallaron.
El principal cambió entonces el punto de escritura entre ejecuciones; como no
se archivaron sus bytes en cada estado, el test final usa variantes explícitas.

## Fuente original reproducida sin modificar

`src/tooling/run_write_order_probe.gd` fue aportado durante la sesión, después de
los tres ensayos. No se modificó. Se ejecutaron, en orden, `mode=rec`,
`mode=run path=step order=frame` y `mode=run path=step order=before`, todos con
`--headless --fixed-fps 60`, límite de 60 s por proceso y código **0**.

| Fuente original | p95 m | p99 m | p99.9 m | máximo m | razón plataforma/bus | ticks plataforma cero |
|---|---:|---:|---:|---:|---:|---:|
| step/frame | 0.0085 | 0.0165 | 0.0265 | 0.1586 | 1.01 | 900/1800 |
| step/before | 0.5751 | 0.5948 | 0.5997 | 0.6009 | 0.00 | 900/1800 |

Logs completos: `12_original_record.log`, `12_original_frame.log`,
`12_original_before.log`. Grabación de 2400 muestras conservada en
`12_original_recording.json`.

**Hecho visible en la fuente:** `_tick()` escribe la nueva pose antes de
`_measure()` solo en `order=frame`. Esa medición lee la tripulante y la velocidad
de plataforma producidas por el paso anterior. En `order=before`, `_measure()`
ocurre antes de que el nodo escriba la pose siguiente. Además, `_ratios` solo
incluye muestras donde `bus_speed > 1`, por lo que la selección a 30 Hz depende
de esa fase. Se reproducen sus cifras, pero las dos filas no emparejan la misma
edad de pose del bus y de la tripulante.

**Inferencia:** ese emparejamiento diferente explica la separación aparente de
la sonda original; la comparación con muestreo común no muestra la ventaja
atribuida exclusivamente a la señal. No se afirma una causa interna de Jolt.

## Contraprueba controlada: ambos relojes en el mismo montaje original

Para aislar el reloj sin cambiar montaje, trayectoria, ventana ni tripulante,
se añadió `src/tooling/run_write_order_audit.gd` (113 líneas), que **hereda** la
sonda original intacta. Conserva `_boot`, `_tick`, `_sample_at` y la medición
original; agrega un observador con `process_physics_priority=1000` y pospone
únicamente el reporte final hasta capturar la segunda observación del último
tick. Ambas observaciones usan los mismos 1800 ticks, 151 a 1950 inclusive.
El archivo de grabación es el mismo SHA-256 F8A45B6D…EE2A35 conservado arriba.

Dos ejecuciones `mode=run path=step order=frame|before`, `--fixed-fps 60`, plazo
60 s cada una, terminaron **0**, sin ERROR/WARNING. Los logs son
`12_audit_frame.log` y `12_audit_before.log`; cada uno tiene JSON de resumen y
CSV con las dos observaciones emparejadas en una fila. El import posterior
para generar `uid://cemltr3v2ljba` terminó 0 (`12_audit_import.log`).

| Escritura | Reloj observado | p95 m | p99 m | p99.9 m | máximo m | razón media |
|---|---|---:|---:|---:|---:|---:|
| frame | original | 0.008481703 | 0.016455956 | 0.026516613 | 0.158623680 | 1.005982526 |
| frame | después de nodos | 0.575080991 | 0.594772160 | 0.599694490 | 0.600858510 | 0.000000119 |
| before | original | 0.575082004 | 0.594772279 | 0.599695444 | 0.600857556 | 0.000000119 |
| before | después de nodos | 0.575080991 | 0.594772160 | 0.599694490 | 0.600858510 | 0.000000119 |

Las cuatro lecturas tienen 1800 muestras de deslizamiento, 866 muestras de razón
y 900 ticks con plataforma cero. Al comparar los dos CSV, **las 11 columnas
`common_*` coinciden en las 1800 filas** (0 diferencias entre 19 800 celdas a
nueve decimales): pose del bus, pose de la tripulante, posición local, velocidad
de plataforma y velocidad calculada del bus. Las cifras originales también
se conservan hasta los decimales impresos por el original.

Ejemplo emparejado, tick 151: en `frame`, la lectura original encuentra
bus.z=25.409635544 y plataforma=13.752020836 m/s; la lectura tras nodos mantiene
esa pose del bus y registra plataforma=0. En `before`, la lectura original
todavía encuentra bus.z=25.641773224; tras nodos encuentra exactamente los mismos
valores comunes que `frame`. Tick 152: la tripulante avanza con plataforma
13.928259850 m/s, mientras el bus mantiene su pose.

**Alcance de esta contraprueba:** en el montaje original y la grabación exacta,
la separación informada por el reloj original desaparece al observar ambas
vías en un reloj común. Esto refuerza la atribución a la fase de observación;
no identifica una causa interna del motor ni prueba que otro momento de
escritura arregle el transporte. El gate y su criterio siguen abiertos.

```text
godot --headless --fixed-fps 60 --path . -s res://src/tooling/run_write_order_audit.gd ++ mode=run path=step order=frame
godot --headless --fixed-fps 60 --path . -s res://src/tooling/run_write_order_audit.gd ++ mode=run path=step order=before
```

SHA-256 del auditor ejecutado:
`5576807D0E885A4EEFE5238259BFDAE42F9277F320EE4EBB9EFD0BBF9ABA53FC`.
La fuente original conserva SHA-256 `299E19EB…AA1575`.

Otra limitación de la fuente: `process_priority=±100` no cambia la prioridad de
`_physics_process` en Godot 4.7, cuya propiedad es `process_physics_priority`.
Por tanto las etiquetas `before/after` no demuestran los dos órdenes físicos.
Documentación oficial consultada:
[Node](https://docs.godotengine.org/en/4.7/classes/class_node.html#class-node-property-process-physics-priority),
[SceneTree.physics_frame](https://docs.godotengine.org/en/4.7/classes/class_scenetree.html#class-scenetree-signal-physics-frame),
[Node3D.force_update_transform](https://docs.godotengine.org/en/4.7/classes/class_node3d.html#class-node3d-method-force-update-transform).

## Sonda carry corregida y procedencia de los archivos

Los artefactos **finales** son `03_raw/final_physics_frame*` y
`03_raw/final_physics_process*`: ambos procesos terminaron en 0, sin ERROR ni
WARNING en sus logs. Cada modo conserva exactamente ocho CSV (3600 ticks cada
uno), un JSON de resumen y el log. El sampler se conecta a `physics_frame`
**antes** de crear cualquier escritor de replay. Así lee el último paso físico
terminado antes de que cualquiera de las dos vías reemplace la pose para el
siguiente. Ambos JSON declaran
`sampling_phase="before_all_writers_after_previous_physics"`.

Se grabaron por separado las trayectorias de pie y caminando; cada replay usa
la de su régimen. La distancia muestra a muestra entre trayectorias da
p95 **3.5358579158783 m**, máximo **3.84059858322144 m**, N=3600 en ambos modos.
El checksum con signos fue retirado. La tabla completa está en evidencia 03.

| Carry final | Escritura | p95 slip m | p99 slip m | p99.9 slip m | máximo m |
|---|---|---:|---:|---:|---:|
| Real de pie | baseline | 0.0040 | 0.0072 | 0.0217 | 0.0782 |
| Real caminando | baseline | 0.0675 | 0.0700 | 0.0780 | 0.1432 |
| KINEMATIC de pie | señal | 0.5919 | 0.6129 | 0.6189 | 0.6191 |
| KINEMATIC de pie | nodo | 0.5919 | 0.6129 | 0.6189 | 0.6191 |
| KINEMATIC caminando | señal | 0.6321 | 0.6798 | 0.6870 | 0.6873 |
| KINEMATIC caminando | nodo | 0.6319 | 0.6798 | 0.6870 | 0.6873 |

Los `03_raw/codex_physics_*` son un diagnóstico intermedio con muestreo común
**posterior a nodos**, prioridad 1000. No son la tabla final: el cuerpo dinámico
y el cinemático pueden tener sincronizaciones diferentes respecto del servidor
de física. En ese método el baseline de pie dio p99=0.0062 y máximo=0.0085,
por lo que no debe mezclarse con el baseline histórico o con los `final_*`.
Sus dos `*_speed.json` eran residuos preexistentes en user:// copiados por error;
se conservaron identificados con `valid_for_this_run=false`. Las velocidades
de esas ejecuciones solo están respaldadas por su línea `SPEED` del log.

`03_raw/codex_carry.log` es anterior a la importación y contiene ParseError de
NetAuthority ausente de la caché: es **inválido**, aunque el proceso retornó 0.
Se conserva para declarar el fallo. Después, dos imports dieron 0
(`12_import_1.log`, `12_import_2.log`); un import final para los UID nuevos dio 0
(`12_import_final.log`). No se borraron registros fallidos.

## Reproducción y hashes SHA-256

Las ejecuciones se lanzaron con `Start-Process -WindowStyle Hidden -PassThru`,
`WaitForExit(60000)` para test/original/import y `WaitForExit(120000)` para carry;
se habría terminado únicamente ese proceso si vencía el plazo. Se preservó el
código del proceso, sin interpretar 0 de la sonda como ausencia de errores.

```text
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests/net/bus_write_order_test.gd -rd res://reports/order_common
godot --headless --fixed-fps 60 --path . -s res://src/tooling/run_write_order_probe.gd ++ mode=rec
godot --headless --fixed-fps 60 --path . -s res://src/tooling/run_write_order_probe.gd ++ mode=run path=step order=frame
godot --headless --fixed-fps 60 --path . -s res://src/tooling/run_write_order_probe.gd ++ mode=run path=step order=before
godot --headless --fixed-fps 60 --path . -s res://src/tooling/run_carry_probe.gd ++ window_s=60 save_raw=1 write=physics_frame
godot --headless --fixed-fps 60 --path . -s res://src/tooling/run_carry_probe.gd ++ window_s=60 save_raw=1 write=physics_process
```

| Archivo | SHA-256 |
|---|---|
| run_write_order_probe.gd original intacto | 299E19EB83A7C2759F811FF100FA7AB7028A61D54A7F4F864B3E367754AA1575 |
| 12_original_recording.json | F8A45B6DFDEF3B5AB9A35AED2839CB42A22B735750B081A4719D44D919EE2A35 |
| run_carry_probe.gd final | 8FBE6FA10B817BACB60BC3CBB5E896105D1A7DD10CD4139A65723F70552A47A5 |
| carry_probe_replay.gd final | 9BEF16D729249B8287F825C950BC401327B4B1228A29E4BC3FB41FC204E69E04 |
| carry_probe_sampler.gd final | 18C2CAA235B461C2DE665D4ED2D1B27EBF8B53D0CCDA57EE7B84385CB4A6B69E |
| bus_write_order_test.gd final | BAF68EA57976512F997B74CE45DCB126EAAEB7D23E131A2BD1B2075D13F78F1D |
| net_bus_sync.gd (señal, sin force) | E226BC6108CB0F616D01422F88DB0538A355BBB25BDA5F2D30CE7E499F0E7502 |
| project.godot | 029F4F5E6D62D55F7396376C1B344A20356A420C5B579466E91F254465D40940 |
| bus.gd | 1589DF928447477FF22B740B40FA8263C876F256E596ACC23A3FD0B303F24498 |
| bus.tscn | 61781601A95B67954602D648792540BF020B637C90612FAD107C2E39EF730C4D |
| crew_member.gd | 4C355A01236F7E096A4BF140EA3C46C8E7CB52FAB902F9B7AA5A6C2E768480FE |
| crew_member.tscn | 59DA1FACD67EFE2EAD4B1A6C328ABB7249AABB55B4EAC53FD08F5183ADF96CB5 |

`12_receiver_signal.gd.txt` y `12_real_fixture.gd.txt` conservan el receptor y
el fixture del ensayo inicial real (antes de cambiar al criterio final de
deslizamiento). El test final está versionable en tests/net; no confundir esos
bytes previos con el hash final de la tabla.

Estado histórico anterior a revisión 03: se pedía reconciliar g2.1 antes de
aprobar fase 0. La revisión lo retiró y autorizó eliminar el test; su hash y
la frase de test versionable de arriba describen únicamente aquel diagnóstico.
Las corridas D95 posteriores están en 04_gate_iteration_N.md.
