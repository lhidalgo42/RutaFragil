# Prompt para el agente ejecutor — M2-GATE Ronda 3 (fase 0 con tres correcciones, y a repartir el enjambre)

Copiar desde `CONTEXTO:` hasta el final. **Esta vez no hay parada intermedia**: fase 0 en un commit y los dos agentes en paralelo. La siguiente parada es la primera iteración del gate.

---

CONTEXTO: Proyecto "Ruta Frágil" (Godot 4.7.2, GDScript tipado). Obedece R1–R14: están textuales en `AGENTS.md` §0.3. Repo local: `C:\Users\Leo\Documents\RutaFragil`, rama `m2/gate-two-instances` (HEAD `d9ad291`; `main` en `2b16e99`). Hay archivos del revisor sin commitear (`docs/revisiones/M2-GATE_revision_02.md`, `docs/planes/M2-GATE_ronda3_prompt.md`, y `docs/planes/M2-GATE_plan.md` con D92 y D95 reescritos): cométealos tal cual primero.

**EL PASO 1 PASA Y LA FASE 0 SE APRUEBA.** El revisor corrió **tu sonda commiteada** en su máquina y reprodujo tu tabla dígito a dígito, las nueve filas y la de velocidad. Eso es lo que faltaba en la ronda 1. La decisión (c) queda adoptada y (a) y (b) descartadas con dos sondas independientes.

Tres correcciones van **dentro** del commit de la fase 0, no después. Lee entera `docs/revisiones/M2-GATE_revision_02.md`; esto es el resumen operativo.

> ⚠️ **RETIRADO el 2026-09-16.** Todo lo relativo a g2.1 en este documento queda sin efecto: la diferencia entre escribir desde `physics_frame` y desde el `_physics_process` de un nodo era un artefacto del punto de muestreo, no del punto de escritura. Véase `docs/revisiones/M2-GATE_revision_03.md`. La decisión de interpolar no depende de esto y sigue vigente.

**1. (g2.1, BLOQUEANTE) El requisito de escritura está al revés, y lo está en código commiteado.** Tu sonda afirma en `run_carry_probe.gd:12-16` que la escritura debe caer en el `_physics_process` de un nodo con prioridad anterior a la tripulante, y que desde `physics_frame` la velocidad de plataforma "llega un paso tarde". El revisor lo midió variando **solo** el punto de escritura, con el mismo camino y la misma grabación:

   | Camino | Dónde se escribe | desliz./tick máx | v. plataforma recibida / v. real del bus |
   |---|---|---|---|
   | paso a 30 Hz | señal `physics_frame` | **0,1586** | **1,00** |
   | paso a 30 Hz | nodo `_physics_process`, prioridad −100 (antes) | **0,6009** | **0,00** |
   | paso a 30 Hz | nodo `_physics_process`, prioridad +100 (después) | **0,6009** | **0,00** |
   | paso a 30 Hz | nodo + fijar `linear_velocity` a mano | **2,8039** | 0,00 |
   | interpolado | los tres órdenes | 0,079 | 1,00 |

   Con el estadístico bueno (p99, ver el punto 2): el salto a 30 Hz da **0,0165 escrito bien** y **0,5948 escrito mal**, frente a 0,0072 del anfitrión — o sea 2,3× y 83×. (b) falla las dos veces, así que la decisión no cambia; lo que cambia es cómo hay que escribir. Y mi (c) con la escritura buena da p99 0,0096 frente a tu 0,0100: las dos sondas coinciden en todo el cuerpo de la distribución.

   No es un retardo de un paso: **es cero**. Y el `process_priority` no cambia nada (antes y después dan el mismo número). El apaño de fijar `linear_velocity` lo empeora cuatro veces. **Con interpolación el orden da igual, así que el defecto es invisible mientras la red va bien y aparece justo al perder paquetes.**

   Qué hacer: **el receptor del bus escribe la transformada replicada desde `physics_frame`** (o un punto equivalente anterior al procesado de nodos), no desde el `_physics_process` de un nodo. **Un test lo pinea**: camino a saltos de 30 Hz, tripulante de pie, y afirmar que la velocidad de plataforma que recibe no es cero en los ticks en que el bus se mueve (o, como consecuencia, que el deslizamiento máximo se queda por debajo de 0,3 m en vez de irse a 0,6). Y **corrige el docstring de la sonda**: es código del repo y el siguiente que lo lea se lo va a creer.

**2. (g2.2, error del revisor, ya corregido en el plan) D95 cambia por tercera vez, y ahora sale de tus crudos.** El revisor fue a `03_raw/` y miró la cola: vuestros p95 de (c) coinciden al cuarto decimal (0,0060 los dos) y solo discrepa el **máximo**, que lo sostienen una o dos muestras. Peor: el máximo del anfitrión (0,0782) son dos golpes de bache, y la interpolación los recorta — así que (c) marca 0,51× en el pico **mientras está en 1,4–1,5× en p95, p99 y p99,9**. El criterio del pico premiaba alisar la realidad.

   | Pasada (tus CSV) | p95 | p99 | p99,9 | máx |
   |---|---|---|---|---|
   | anfitrión, de pie | 0,0040 | 0,0072 | 0,0217 | 0,0782 |
   | (c), de pie | 0,0060 | 0,0100 | 0,0333 | 0,0401 |
   | (b), de pie | 0,5919 | 0,6129 | 0,6189 | 0,6191 |

   **Criterio nuevo: el p99 del deslizamiento por tick del cliente no supera 1,5× el del anfitrión de la misma corrida.** (c) pasa a 1,39× de pie y 1,02× caminando; (b) falla a 85× y 9,7×. El máximo se reporta, no se juzga. Se reportan p95, p99 y p99,9 de las dos instancias.

**3. (g2.3) Falta la métrica que mide la fidelidad de la réplica.** El JSON lleva error remoto de tripulante y de carga, pero **no del bus**, que es justo lo que se replica y lo que la interpolación puede alisar. Añade `bus_remote_error {p95_m, max_m, p95_deg, max_deg}`: la transformada que el anfitrión tenía en ese instante contra la que el cliente estaba mostrando. Sin esa columna, una réplica que suavice la realidad pasa el gate y nadie se entera.

**4. (g2.7, BLOQUEANTE) La mitad caminando de tu tabla compara dos vueltas distintas.** En `_run_table()` grabas la trayectoria de pie, grabas la de caminando, imprimes los dos checksums y después haces `_recording = recording_standing`, **descartando la grabación caminando**. Las tres filas de cliente caminando se reproducen sobre la trayectoria **de pie**, mientras el anfitrión caminando corrió sobre la **de caminando** — y las dos difieren de verdad, como demuestran tus propios checksums. Eso incumple el "en la misma corrida" de D95. Además el comentario del código dice *"the checksum proves the trajectory does not depend on the crew"*, lo contrario de lo que tus datos muestran. **Guarda las dos grabaciones, reproduce cada régimen con la suya, corrige el comentario y repite la mitad caminando de la tabla.**

**5. (g2.8 y g2.9, BLOQUEANTES para la fase 0) Dos firmas no son construibles tal cual:**
- **`Package` no está en ningún grupo**, así que la identidad "por grupo + nombre" de los cuatro RPC no resuelve nada hoy. Los grupos que existen son `bus`, `bus_input`, `cabin_camera`, `chase_camera`, `crew`, `crew_hands`, `crew_input`, `eye_camera`, `seat` y `restraint_anchor`. Añade el grupo `package` en `Package._ready()` en la fase 0.
- **Las búsquedas de tripulante se resuelven una sola vez y no reintentan:** `crew_input.gd:83` y `door_transit.gd:29` guardan la referencia en un `_find*()` diferido desde `_ready` y, si no hay nadie, sueltan `push_error` y se quedan con `null` para siempre. Con las tripulantes creadas por el spawner, que llegan después, esos nodos quedan muertos. No basta con decidir *cuál* tripulante buscan: hay que **reintentar** o engancharse a la señal de aparición.

**6. (g2.10) `apply_replicated_state` necesita el sostenedor.** Tal como la propones no dice **quién** sostiene la caja cuando el estado es `HELD`, y con dos tripulantes el cliente no puede colgarla de la mano correcta. Añade el peer al argumento y enumera en la fase 0 qué hace la función en **cada** transición, incluida `STRAPPED → FREE` replicado, que hoy solo existe pasando por la mano.

**Cuatro líneas más, en el mismo commit:**
- **g2.11:** `run_carry_probe.gd` no aparece en `README.md` ni en `AGENTS.md`, donde sí están `run_demo` y el arnés. Una línea en cada sitio con el comando.
- **g2.13 (error del revisor, hay que arreglarlo igual):** la columna "ticks sin suelo" la especifiqué mal y tú la implementaste literalmente. `is_on_floor()` dice **cualquier** suelo, incluido el `Ground` de 200×200: en tu `static_standing.csv`, el tick 1200 tiene 59,6 m de deriva del bus y `on_floor = 1`, y 3.291 de 3.600 ticks tienen deriva > 10 m con `on_floor = 1`. Para el gate la columna tiene que significar "**no apoyada en el bus**": comprueba el cuerpo del apoyo (`get_platform_rid()` o el colisionador del último `get_slide_collision()`) contra el bus y su interior, o exige además que la posición local esté dentro del casco. Y renómbrala.
- **g2.14:** `_recording_checksum` es una suma **con signo** de `x+y+z`, así que la diferencia de 892,46 entre regímenes no son "0,25 m por vuelta" (eso lo dijimos mal los dos) y las cancelaciones pueden esconder divergencia. Sustitúyelo por máximo y p95 de `a[i].origin.distance_to(b[i].origin)`, que sí es una distancia, y entonces el número del BACKLOG de g2.6 será citable.
- **La sonda también necesita ponerse al día con D95:** hoy `_reading()` no calcula ni el **p99** ni el **error remoto del bus**, que son las dos métricas nuevas del criterio.
- **Precisión sobre g1.3:** hay **dos** puertas, no una. Cambiar la llamada (`if cargo_spawn and not demo_mode:` en `_ready`) no basta, porque `_spawn_cargo()` vuelve a comprobar lo mismo en su primera línea (`if not cargo_spawn or demo_mode: return`, puesta a propósito porque la llamada es diferida). Si solo tocas la de fuera, el anfitrión del gate sigue sin carga y el síntoma es idéntico al de hoy. **Y la fórmula que propones tampoco sirve tal cual:** el rol cliente tiene `demo_mode = false`, así que "salvo que `demo_mode and network_role == single`" **no lo excluye** y el cliente generaría sus cuatro cajas locales **además** de las que le llegan replicadas — duplicados, choque de nombres bajo `Cargo/` y justo lo que el plan prohíbe ("ninguna instancia simula física de una caja que no le pertenece"). Condiciona por **autoridad**: `cargo_spawn and network_role != "client" and not (demo_mode and network_role == "single")`, con la **misma** condición en las dos puertas, extraída a un solo método para que no puedan divergir. Comprobado además que esto deja `run_demo` intacto y no rompe ningún test — pero **añade `cargo_spawn = false` en `tests/net/playground_client_mode_test.gd`**, que instancia el rol cliente y con la regla nueva se pondría a crear cuatro `RigidBody3D` dentro de una suite unitaria.
- **g2.4:** tu corrida deja un aviso del motor en `03_raw/carry_final.log` (`Jolt Physics job system exceeded the maximum number of jobs`), en el caso patológico (a). Declara en la 03 dónde sale y por qué crees que sale. El estándar es declarar los avisos, no que aparezcan solo en el log.
- **g2.5:** la sonda imprime `recording checksums standing=… walking=… (must match)` y **no coinciden**, porque la tripulante caminando perturba el bus. La etiqueta dice lo contrario del dato. Lo que debe coincidir es la grabación dentro de un mismo régimen.
- **g2.6 al BACKLOG:** el bus siente a su tripulación (~0,25 m por vuelta entre estar de pie y caminar, de tus propios checksums). Hoy no cambia nada; en M4 significa que dos instancias con tripulantes en sitios distintos divergen aunque la física sea determinista.

**Y AHORA SÍ, EL ENJAMBRE.** Fase 0 en un commit con las firmas que propusiste (las siete de g1.1–g1.7 quedan aprobadas tal cual) más las tres correcciones de arriba. Después, los dos agentes en paralelo con propiedad exclusiva:

- **Agente A — tripulantes (D93).** Una por peer bajo `Crews/Crew_<peer_id>`; la local se simula, las remotas reciben transformada interpolada y no llaman a `move_and_slide`; **exactamente una cámara activa por instancia**, medido; input y manos solo sobre la local, con el reparto de las once búsquedas que ya decidiste. Tests headless donde se pueda y escenario de red donde no.
- **Agente B — carga (D94).** Sueltos con autoridad del anfitrión, clientes cinemáticos interpolados a 20 Hz; los cuatro RPC por nombre con validación en el anfitrión; cesión y devolución de autoridad; `apply_replicated_state` para el camino de estado replicado; **ninguna instancia simula carga que no le pertenece, medido**.

**Integración y primera iteración (coordinador):** `++ mode=gate` con el presupuesto derivado de `seconds`, ataque al campo de baches **en recta**, 300 s, `tools/run_gate.ps1`/`.sh` con `++ human=client` para que el dueño juegue el cliente con ventana. La primera iteración se juzga con el criterio nuevo entero: p99 ≤ 1,5×, atravesamientos con tolerancia, error remoto de **bus**, tripulante y carga, fps por percentil 1, y los diez ciclos de actividad por instancia (por debajo, iteración **inválida**, no gasta una de las tres de D96).

EVIDENCIA (`docs/evidencia/M2-GATE/`): la 02 y la 03 se actualizan; `04_gate_iteration_1` con la tabla completa; `05_windowed` (cliente con la tripulante remota y las cajas, anfitrión en persecución); `06_regression`; `07_git`; `08_no_verificado`; `09_limits`; `10_windowed_clean_log` con **los logs de las dos instancias**; `12_orden_de_escritura` con el test de g2.1 fallando sobre la escritura mala y pasando sobre la buena.

CRITERIOS DE ACEPTACIÓN: g2.1 con su test que falla primero; D95 nuevo aplicado; `bus_remote_error` en el JSON; g2.4, g2.5 y g2.6 cerrados; fase 0 en un commit con las firmas aprobadas; los dos agentes entregados sin conflictos; al menos una iteración del gate con su tabla y su veredicto; `run_demo`, red corta y larga y las seis cifras de sensación intactos; tres arneses en código 0 con el conteo exacto actualizado; `git status` limpio también tras importar en un clon fresco.

INSTRUCCIONES:
0. Commit de los archivos del revisor tal cual.
1. Fase 0 en un commit, con las tres correcciones dentro.
2. Los dos agentes en paralelo. Reporte corto de cada uno.
3. Integración, primera iteración de 300 s, y **juega tú la instancia cliente con ventana antes de dar nada por bueno**.
4. Reporte final: hashes, los tres códigos de salida, la tabla de la iteración con el criterio nuevo, los logs de las dos instancias, las capturas, el veredicto A/B con la iteración en que se decidió, y lo que quede abierto.
