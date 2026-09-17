# Ronda 5 — plataforma, réplica y banco determinista

Motor: 4.7.2.stable.official.ed1daf0bf. Todos los bancos muestrean mediante un
observador independiente después de los nodos, process_priority y
process_physics_priority = 1000; el escritor tiene prioridad física −100.
No se cambia el punto para ninguna fila. Son 1064 ticks a 60 Hz, una trayectoria
real grabada una vez y reproducida con bus cinemático, sin red ni reinicios.
El suelo ampliado existe solo en la instancia de la sonda; no se editan escenas.

## Resultado y límite causal

Se reproduce una expulsión sin red con caja lenta, pero **no queda aislada la
adopción de la caja como plataforma** en este banco. Durante los 18 contactos
duales del caso de pie, la velocidad de plataforma sigue siendo la del bus
(14,93–15,44 m/s), mientras la caja avanza a 9,95–10,29 m/s. La caja obstaculiza
a la tripulante, que retrocede hasta salir. La variante exacta de pie evita
el encuentro (cero contactos duales); por ello su mejora no demuestra por sí
sola la hipótesis del sobrescrito de plataforma. Caminando sí hay contactos
duales en ambas variantes, sin expulsión. Este límite se comunicó antes de
seguir; el mecanismo puro solicitado en A queda **sin reproducir aisladamente**.

## A y B, mismo banco

Caja inicial local (0,3; −0,4; 1,5), tripulante z=2,5. Desde índice 350,
ratio=0,665 impone déficit longitudinal; ratio=1 conserva la posición local.
El p99 incluye movimiento voluntario caminando; tras la expulsión no es jitter.
Aire usa is_on_floor, apoyo exige el bus y su casco: no son equivalentes.

| Caso | Apoyo % | Flancos | p99 m/tick | Aire ticks | Pérdida máxima | Apoyo final | Contactos duales |
|---|---:|---:|---:|---:|---:|---|---:|
| [A lenta, de pie](16_bank/slow_encounter.json) | 35.244361 | 1 | 3.558168888 | 13 | 689 | False | 18 |
| [(a) exacta, de pie](16_bank/exact_encounter.json) | 100.000000 | 0 | 0.010051608 | 0 | 0 | True | 0 |
| [A lenta, caminando](16_bank/slow_walk.json) | 100.000000 | 0 | 0.034487784 | 0 | 0 | True | 70 |
| [(a) exacta, caminando](16_bank/exact_walk.json) | 100.000000 | 0 | 0.034437280 | 0 | 0 | True | 118 |
| [(b) explícito + lenta, de pie](16_bank/explicit_slow.json) | 98.214286 | 12 | 0.016928397 | 19 | 7 | True | 7 |
| [(b) explícito + lenta, caminando](16_bank/explicit_walk.json) | 99.248120 | 7 | 0.037417125 | 8 | 2 | True | 72 |

## Baches y presión vertical

Sin cajas, misma grabación. Entrada a baches 85,515 km/h; máximo85,555,
mínimo53,709, salida53,946; 57 de136 ticks del tramo z=[2,46] están a≥80.
Es un ataque por encima de80 con desaceleración, **no 80 km/h sostenidos**.

| Acarreo | Marcha | Presión m/s | Apoyo % | Flancos | p99 m/tick | Aire ticks |
|---|---|---:|---:|---:|---:|---:|
| [Motor](16_bank/none_standing.json) | pie | -0.5 | 100.000000 | 0 | 0.010051608 | 0 |
| [Motor](16_bank/engine_none_walking.json) | camina | -0.5 | 100.000000 | 0 | 0.034497656 | 0 |
| [Motor](16_bank/engine_zero_press.json) | pie | 0 | 100.000000 | 0 | 0.009733295 | 0 |
| [Motor](16_bank/engine_zero_walking.json) | camina | 0 | 100.000000 | 0 | 0.034511760 | 0 |
| [Explícito](16_bank/explicit_none_standing.json) | pie | -0.5 | 98.496241 | 10 | 0.010466725 | 16 |
| [Explícito](16_bank/explicit_none_walking.json) | camina | -0.5 | 99.530075 | 4 | 0.037922062 | 5 |
| [Explícito](16_bank/explicit_zero_press.json) | pie | 0 | 94.548872 | 47 | 0.010481018 | 58 |
| [Explícito](16_bank/explicit_zero_walking.json) | camina | 0 | 94.454887 | 50 | 0.037992019 | 59 |

Los16/5 ticks en aire del explícito con−0,5 ocurren dentro de los baches.
**(b) se rechaza**: rompe el control de cero aire. No se cambia CrewMember
ni sus máscaras en producción. Con presión0 ambos controles del motor también
se sostienen: este banco no reproduce la necesidad de−0,5 de T2.2; conserva
el hecho anterior sin sustituirlo por una causalidad que aquí no aparece.
No se implementa la eliminación de colisiones tripulante–carga (c).

## Por qué apareció la razón 0,665

[Baseline120s instrumentado](13_raw/r5_motion_baseline_01/summary.json),
[contexto6454cea](r5_motion_baseline_01_context.json), sin afirmación de árbol limpio, con carga y ventanas/vsync off. [Flancos cliente](13_raw/r5_motion_baseline_01/client_support_losses.json)
conservan los tres ticks anteriores: desplazamientos mundiales de bus y cada
caja, velocidades físicas/contactos, RID de cada contacto e inferencia de
plataforma por igualdad de velocidad. Godot4.7.2 no expone get_platform_rid()
en GDScript; `platform_rid_api_available=false` evita inventarlo.

En el tramo previo al flanco497, la interpolación local pasa de z=0,1664648
(estado FREE fiable) a z=0,4802494 (primera foto física), corrigiendo0,3137846m
hacia atrás. La interpolación ocupa ticks493–495;493 se deduce del buffer/before_write,
no es una muestra guardada en previous_three. En las muestras494/495/496,
package_write_m=0,205019/0,205839/0,309581 y
bus_write_m=0,309606/0,310425/0,310425. En496 el nodo ya escribe casi
la velocidad del bus, pero el contacto aún publica12,349261m/s. Son fases
distintas y no se mezclan. No faltan escrituras dos de cada tres ticks: la
corrección local resta avance mientras se interpola.0,665 es la aproximación
usada como estímulo, no una razón exacta constante del baseline. Véanse los campos de buffer,
alfa, package_write_m y bus_write_m en el volcado enlazado.

El RPC se aplicaba en idle, cuando el servidor físico del bus está un tick
adelante de su Node3D. La liberación convertía a mundo con esa pose vieja.
La [sonda de fase sin contactos](16_bank/release_phase.json) reproduce:

| Fase de liberar | Separación servidor/nodo del bus | Error FREE local final |
|---|---:|---:|
| Física | 0 m | 0 m |
| Idle | 0,308333397 m | 0,308333397 m |

Se aplica una FIFO de las cuatro peticiones fiables en el siguiente tick
físico, después de sincronizar el nodo rígido. El peer se captura al recibir;
las reglas vuelven a validar al aplicar. La FIFO impide que un hold/strap
posterior adelante a release. El test exige que exista el desfase >0,25m:
[rojo de fase](16_release_phase_red.log) exit100, error0,308333;
[verde](16_release_phase_green.log) exit0, error0. El test ampliado verifica
hold→release→hold recibido en una tanda: [rojo](16_release_order_red.log)100,
[verde con accesos inseguros como error](16_release_order_green.log)0.
No se fuerza velocidad artificialmente en la réplica: se elimina la foto
inicial inconsistente. El efecto integral de(a) se mide en el experimento300s.

## Fuente del motor y máscaras

En [CharacterBody3D del commit del motor](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/scene/3d/physics/character_body_3d.cpp),
_set_collision_direction puede sustituir la plataforma del suelo por el
contacto de pared más profundo. En move_and_slide, excluir esa plataforma
por máscara deja current_platform_velocity=0, sin buscar otra vez el suelo.
Es comprobación del código fuente; la variante masked del banco dio lo mismo
que la lenta, pero no se observa adopción de la caja antes de perder apoyo
(sí después, en tick378), de modo que **no se presenta esa
variante como medición de la trampa**. El header confirma que no hay getter
GDScript para platform_rid. [Jolt body](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/modules/jolt_physics/objects/jolt_body_3d.cpp)
conserva objetivo cinemático hasta MoveKinematic. El orden de poll/sync se
contrasta con [main.cpp](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/main/main.cpp)
y [scene_tree.cpp](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/scene/main/scene_tree.cpp).
La sonda de fase, no esta lectura por sí sola, demuestra el desfase concreto.

## Reproducción y ensayos descartados

`python docs/evidencia/M2-GATE/run_r5_probe.py recording mode=rec`

`python docs/evidencia/M2-GATE/run_r5_probe.py slow_encounter candidate=engine ratio=0.665 walking=0 box_z=1.5 box_x=0.3`

Cambiar label/candidate/ratio/walking según los argumentos guardados en cada
JSON. Todos conservan CSV y pérdidas; usar otra etiqueta para no sobrescribir.
La grabación publicada vive en16_bank/recording.json.

Se conservan intentos iniciales:16_record.log falló por cargar clases antes
de los autoloads (arreglado con Node diferido);16_release_phase_fixture_invalid.log
no tenía mano y denegaba soltar, por lo que no cuenta como prueba roja causal.
slow_standing/exact_standing tenían contacto antes del déficit y no ejercitaban
el encuentro; los casos centered son variantes de posición, no resultados
principales. masked_encounter_stderr contiene un aviso Jolt de máximo de jobs;
no se declara limpio ese log ni se atribuye sin prueba a una causa concreta.

La primera suite descubrió241 tests, todos verdes, pero el arnés aún esperaba236
y salió1. Strict detectó dos métodos Variant y después tres argumentos Vector3;
se conservan los dos105. El roundtrip JSON detectó desigualdad int/float en
la firma (100); se normalizan ambas por JSON y la suite net strict pasa0.
La guardia CLI sin precondición devuelve3 antes de lanzar procesos:
[log](18_guard_refusal.log). El conteo final es241 en ambos arneses.

Los contextos del banco registran HEAD6454cea y fuentes sin confirmar; no
acreditan un checkout limpio idéntico para todas las filas. El commit posterior
conserva las sondas, argumentos y grabación. dual_contact identifica ambos
cuerpos, sin exigir una normal de suelo; press=0 cambia un límite condicionado
por velocity.y, no fuerza velocidad vertical cero cada tick.
