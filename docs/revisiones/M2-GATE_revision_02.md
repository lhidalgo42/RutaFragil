# Revisión 02 — M2-GATE (ronda 2: paso 1 rehecho, sonda commiteada y firmas de la fase 0)

**Fecha:** 2026-09-15 · **Revisa:** Claude · **Revisado:** rama `m2/gate-two-instances`, HEAD `d9ad291` (6 commits sobre `d7d956f`) · **Pliego:** `docs/revisiones/M2-GATE_revision_01.md` + `docs/planes/M2-GATE_ronda2_prompt.md`

## Veredicto: la DECISIÓN del paso 1 se aprueba. Reparte el enjambre, con las correcciones de abajo dentro del commit de la fase 0 — **cuatro son bloqueantes y dos de las demás son errores míos**.

Bloqueantes: **g2.1** (el receptor escribe desde `physics_frame`), **g2.7** (las filas caminando comparan dos vueltas distintas), **g2.8** (`Package` no está en ningún grupo) y **g2.9** (las búsquedas de tripulante no reintentan). Míos: **g2.2** (el criterio del pico premiaba alisar) y **g2.13** (la columna "sin suelo" que yo especifiqué no mide lo que el gate necesita). Y uno que leímos mal los dos: **g2.14**, el checksum no significa lo que dijimos.

Esta ronda es la que quería. **Corrí tu sonda commiteada en mi máquina y reproduje tu tabla dígito a dígito**, las nueve filas y la de velocidad. Eso es exactamente lo que faltaba en la ronda 1 y lo que convierte una medición en un hecho.

Y con la sonda en la mano pude cerrar la discrepancia que quedaba, que resultó ser dos cosas distintas: una es un **hecho del motor que tú diagnosticaste a medias y que ahora está medido**, y la otra es que **el criterio que yo mismo escribí premia el artefacto en vez de medir fidelidad**.

Luego, leyendo la sonda línea a línea, aparecieron tres cosas más que hay que arreglar antes de repartir: **la mitad caminando de la tabla compara dos vueltas distintas** (g2.7), y **dos de las firmas que propones no son construibles hoy** (g2.8 y g2.9). Nada de eso pone en duda la decisión: la mitad **de pie** de la tabla es válida y sola ya separa (c) de (b) por un factor de sesenta. Lo que hay que rehacer es la mitad caminando, y eso son diez minutos de sonda.

## Reproducción del revisor (Windows, 2026-09-15 23:40 – 2026-09-16 00:07 UTC)

| Prueba | Resultado |
|---|---|
| `tools/run_tests.ps1`, tres corridas seguidas, con red | código **0, 0, 0**; 180 tests las tres veces con el conteo exacto en vigor; red `pass` las tres |
| **Tu sonda commiteada, corrida por mí** (`run_carry_probe.gd ++ window_s=60`) | **las nueve filas idénticas a tu reporte**, hasta el cuarto decimal, más `SPEED lap_peak=66,7 · bumps_avg=47,6 · bumps_max=62,8 · bumps_min=34,6` |
| **g0.3 verificado en clon fresco:** worktree nuevo + `--import` | `git status` **limpio**, cero `.uid` generados. Cerrado |
| Alcance (`git diff d7d956f HEAD`) | `src/tooling/run_carry_probe.gd` (+397) y su `.uid`, los dos arneses (solo comentarios), los tres `.uid` de tests, docs y evidencia. **Ni `src/` de juego, ni escenas, ni `data/`, ni `project.godot`** |
| Árbol | limpio en `d9ad291` |

## ⚠️ SECCIÓN RETIRADA EL 2026-09-16 — véase `M2-GATE_revision_03.md`

> **Todo lo que sigue hasta el final de esta sección está RETIRADO.** El ejecutor siguiente montó un observador que muestrea después de los nodos y demostró que la diferencia que aquí atribuyo al punto de escritura es un artefacto del punto de MUESTREO: los dos puntos dan resultados en espejo. El revisor lo reprodujo y lo confirmó. La conclusión de arquitectura (interpolar) no depende de esto y sigue en pie. Se deja el texto sin borrar porque la traza de cómo se llegó al error vale más que esconderlo.

## El hecho del motor, medido: tu diagnóstico era correcto en el síntoma y equivocado en la causa y en el remedio

Tú y yo medíamos (b) con un factor de cuatro de diferencia (0,6191 tuyo, 0,1586 mío) y lo atribuiste a que "la velocidad de plataforma de Jolt llega un paso tarde", con el remedio "escribir desde un nodo con `process_priority` anterior a la tripulante". Monté una sonda que varía **solo** el punto de escritura y mide, además del deslizamiento, **la velocidad de plataforma que la tripulante recibe de verdad** frente a la velocidad real del bus:

| Camino | Dónde se escribe la transformada | desliz./tick máx | v. plataforma recibida / v. real | ticks con plataforma a cero |
|---|---|---|---|---|
| paso a 30 Hz | señal `physics_frame` | **0,1586** | **1,00** | 900/1800 (los ticks en que el bus no se mueve) |
| paso a 30 Hz | nodo `_physics_process`, prioridad **−100 (antes)** | **0,6009** | **0,00** | 900/1800 |
| paso a 30 Hz | nodo `_physics_process`, prioridad **+100 (después)** | **0,6009** | **0,00** | 900/1800 |
| paso a 30 Hz | nodo + fijar `linear_velocity` a mano | **2,8039** | 0,00 | 1478/1800 |
| interpolado | los tres órdenes | 0,079 | 1,00 | 0 |

Repetido, idéntico. Lo que dice, en orden:

1. **No es un retardo de un paso: es cero.** Escrita desde un nodo, la tripulante recibe velocidad de plataforma **nula** en los ticks en que el bus sí se mueve, y por eso se queda quieta mientras el suelo salta bajo ella los 0,60 m completos del salto. Escrita desde `physics_frame`, la recibe correcta (razón 1,00) y el deslizamiento baja a 0,1586.
2. **Tu remedio no funciona, y lo comprobé en las dos direcciones.** Prioridad **antes** y prioridad **después** dan exactamente el mismo 0,6009. El `process_priority` no cambia nada: lo que importa es si la escritura ocurre dentro del procesado de nodos o antes de él.
3. **El apaño de fijar `linear_velocity` a mano lo empeora cuatro veces** (2,8039) y sube los ticks sin plataforma de 900 a 1478: el cuerpo pelea entre la transformada escrita y la velocidad impuesta. No lo uséis.
4. **Con interpolación el orden da igual** (0,0791 / 0,0795 / 0,0795). Por eso esto es peligroso: **mientras la interpolación funciona, el defecto es invisible**, y aparece justo cuando un hueco de paquetes deja el camino a saltos, que es el peor momento.

Una honestidad sobre este hallazgo: **es una medición, no una explicación.** No sé qué hace Godot por dentro para que el punto de escritura cambie la entrega de la velocidad de plataforma, y no lo voy a adivinar. Lo que sé es que se repite, que mi caso "desde un nodo" reproduce tu 0,6191 con 0,6009, y que el caso "desde `physics_frame`" da 1,00 de razón donde el otro da 0,00. Va a `DECISIONS.md` como hecho medido, con la versión del motor al lado, y **hay que volver a medirlo si se sube de 4.7.2**.

Tu número de (b) no está mal: describe fielmente **la implementación que elegiste**. Y el veredicto sobre (b) **no cambia**, que es lo importante: medido con el estadístico bueno (el p99, ver la sección siguiente), el salto a 30 Hz da **0,0165 con la escritura correcta** frente a 0,0072 del anfitrión, es decir **2,3×**, y **0,5948 con la escritura mala**, 83×. Falla las dos veces. Lo que cambia es el requisito de diseño que hay que escribir en la fase 0.

Y una comprobación cruzada que conviene ver: con la escritura buena mi (c) da **p99 0,0096** y la tuya **0,0100**. Nuestras dos sondas coinciden en todo el cuerpo de la distribución; solo discrepaban en la muestra única del máximo.

## La otra mitad de la discrepancia: mi criterio premiaba el artefacto

Nuestras dos sondas coinciden en el p95 de (c) al cuarto decimal (0,0060 las dos) y difieren solo en el **máximo** (0,0401 tú, 0,0791 yo). Fui a **tus CSV crudos** a ver la cola, y ahí está la respuesta:

| Pasada (tus datos) | p95 | p99 | p99,9 | máx | 2.º | 3.º |
|---|---|---|---|---|---|---|
| anfitrión, de pie | 0,0040 | 0,0072 | 0,0217 | **0,0782** | 0,0754 | 0,0321 |
| (c) interpolado, de pie | 0,0060 | 0,0100 | 0,0333 | **0,0401** | 0,0393 | 0,0383 |
| (b) sin interpolar, de pie | 0,5919 | 0,6129 | 0,6189 | 0,6191 | 0,6190 | 0,6189 |
| anfitrión, caminando | 0,0675 | 0,0700 | 0,0780 | **0,1432** | 0,0820 | 0,0815 |
| (c) interpolado, caminando | 0,0679 | 0,0711 | 0,0812 | **0,1061** | 0,1048 | 0,0845 |
| (b) sin interpolar, caminando | 0,6323 | 0,6773 | 0,6867 | 0,6873 | 0,6872 | 0,6872 |

Mira la fila del anfitrión: su máximo (0,0782) lo sostienen **dos muestras** (0,0782 y 0,0754) y luego cae a 0,0321. Es un golpe de bache. La fila (c) no tiene ese pico: 0,0401 · 0,0393 · 0,0383, una meseta.

O sea: **la interpolación recorta los picos de impacto del anfitrión y sube el ruido de fondo.** El cliente no es "mejor": es **distinto**. Contra el anfitrión, (c) está en 1,50× el p95, 1,39× el p99, 1,53× el p99,9 y **0,51× el máximo**.

Y ahí está mi error: **el criterio que escribí — "pico del cliente ≤ 1,3× el del anfitrión" — lo pasa (c) con 0,51× precisamente porque suaviza**. Un criterio que recompensa filtrar la realidad no mide fidelidad; mide cuánto se ha alisado la réplica. Y además el máximo es una o dos muestras: dos sondas fieles discrepan en él por un factor de dos mientras coinciden en el p95 al cuarto decimal. **Un criterio no se construye sobre una sola muestra.**

**D95, corregido otra vez y ahora con datos detrás:**

- **Criterio duro: el p99 del deslizamiento por tick del cliente no supera 1,5× el del anfitrión** medido en la misma corrida. Con tus datos: (c) pasa a 1,39× de pie y 1,02× caminando; **(b) falla a 85× y 9,7×**. Margen enorme, estadístico robusto, y discrimina en los dos regímenes.
- **El máximo se reporta, no se juzga.** Igual que la deriva.
- Se reportan también p95 y p99,9 de las dos instancias, para ver la forma de la cola y no solo un número.

## Lo que hay que reconocerte

- **La sonda commiteada es reproducible por otro**, que era el punto entero de g0.2. La corrí sin tocar nada y salió tu tabla. Es la primera medición de este proyecto que cumple ese estándar.
- **Retiraste tu propio 0,099 y dijiste por qué** (la tripulante atascada). Eso es exactamente lo que pedí y no es fácil de escribir.
- **Los crudos por tick son lo que ha permitido cerrar la discusión.** Sin tus CSV yo no habría podido demostrar que el desacuerdo estaba en la cola y no en el método, ni habría descubierto que mi propio criterio estaba mal planteado. Comprometer los datos crudos vale más que la tabla.
- **Diagnosticaste el síntoma correcto** (el orden de escritura importa) partiendo de una diferencia de números con otra sonda. Que el mecanismo exacto fuera otro no le quita mérito al olfato.
- **(a) reproduce mi número de la ronda 1** (90,2 frente a 90,0 m): el `STATIC` no transporta, y eso queda cerrado con dos sondas independientes.
- **Las siete firmas de la fase 0 responden una a una** a g1.1–g1.7, con el reparto de las once búsquedas decidido caso por caso en vez de con una regla global. Eso es lo que hace que un enjambre no choque.

## Hallazgos

**g2.1 — ⚠️ RETIRADO el 2026-09-16 (revisión 03): no había tal requisito.** Lo que sigue quedó desmentido por la contraprueba del ejecutor, verificada por el revisor. Texto original: El docstring de `run_carry_probe.gd:12-16` afirma que la escritura "debe caer dentro del `_physics_process` de un nodo con prioridad anterior a la tripulante" y que desde `physics_frame` la velocidad de plataforma "siempre llega un paso tarde". Medido, es al revés: desde un nodo **la velocidad de plataforma es cero**, con cualquier prioridad, y desde `physics_frame` es correcta. **En la fase 0 el receptor del bus escribe la transformada replicada desde `physics_frame`** (o un punto equivalente anterior al procesado de nodos), y **hay que pinearlo con un test**, porque con la interpolación puesta el defecto es invisible y solo asoma cuando se pierden paquetes. Corrige también el docstring: es código commiteado y el siguiente que lo lea se lo va a creer. Y ojo, porque **tus dos textos se contradicen entre sí**: el comentario de la sonda dice que desde `physics_frame` la velocidad "siempre llega un paso tarde", y la evidencia 03 dice que la vía del revisor "mete la velocidad en el mismo paso". No pueden ser ciertas las dos, y **tu sonda no puede zanjarlo** porque `ReplayDriver` solo sabe escribir desde `_physics_process`: no tiene una opción para la otra vía. La medición que faltaba es la de arriba; si quieres tenerla en casa, añade un argumento `write=physics_frame|physics_process` y la sonda podrá reproducir las dos filas.

**g2.2 — MI ERROR, segunda vez: D95 vuelve a estar mal y ya está corregido arriba.** El pico premia el alisado. Va el p99 a 1,5×, con el máximo reportado.

**g2.3 — falta la métrica que mide la fidelidad de la réplica: el error de posición del BUS.** El esquema JSON lleva error remoto de la tripulante y de cada caja, pero **no del bus**, que es justamente lo que se replica y lo que la interpolación puede alisar. Sin esa columna, una réplica que suavice la realidad pasa el gate y nadie se entera. Añade `bus_remote_error {p95_m, max_m, p95_deg, max_deg}` comparando la transformada que el anfitrión tenía en ese instante con la que el cliente estaba mostrando.

**g2.7 — BLOQUEANTE, y es un defecto de la sonda que invalida media tabla: las filas CAMINANDO comparan dos vueltas distintas.** En `run_carry_probe.gd`, `_run_table()` graba la trayectoria de pie, graba después la de caminando, imprime los dos checksums… y acto seguido hace `_recording = recording_standing`, **descartando la grabación caminando**. Las tres filas de cliente caminando se reproducen sobre la trayectoria **de pie**, mientras la fila del anfitrión caminando corrió sobre la **de caminando**. Y esas dos trayectorias difieren de verdad: lo demuestran tus propios checksums (53475,9 frente a 54368,4), que es justo el hallazgo que reportaste. O sea: el numerador y el denominador de la comparación caminando salen de vueltas distintas, y eso incumple el "en la misma corrida" de D95 que yo mismo escribí. Peor: el comentario del código dice *"the checksum proves the trajectory does not depend on the crew"*, que es exactamente lo contrario de lo que tus datos muestran. **Arreglo:** cada régimen reproduce **su** grabación (guarda las dos y usa la que toca), y el comentario se corrige. Repite la mitad caminando de la tabla después.

**g2.8 — BLOQUEANTE para la fase 0: la identidad "por grupo + nombre" no se puede resolver hoy, porque `Package` no está en ningún grupo.** Los grupos que existen en el proyecto son `bus`, `bus_input`, `cabin_camera`, `chase_camera`, `crew`, `crew_hands`, `crew_input`, `eye_camera`, `seat` y `restraint_anchor`. `Package` no añade ninguno (`src/cargo/package.gd` no tiene un solo `add_to_group`) — de hecho mi propia sonda de T2.3 tuvo que localizar los paquetes recorriendo el árbol y mirando la ruta del script, precisamente por eso. La fase 0 tiene que añadir el grupo `package` en `Package._ready()` antes de que los cuatro RPC puedan resolver nada.

**g2.9 — BLOQUEANTE para la fase 0: las búsquedas de tripulante se resuelven una sola vez y no reintentan.** `crew_input.gd:83` y `door_transit.gd:29` hacen `get_first_node_in_group("crew")` en un `_find*()` diferido desde `_ready`, guardan la referencia y, si no hay nadie, sueltan un `push_error` y se quedan con `null` **para siempre**. Con las tripulantes creadas por el `MultiplayerSpawner`, que llegan después de que la escena esté lista, esos nodos quedan muertos. No basta con cambiar *cuál* tripulante buscan (g1.5): hay que decidir *cuándo* y **reintentar** cuando el spawner entregue, o engancharse a la señal de aparición.

**g2.10 — defecto de la firma: `apply_replicated_state` no puede llevar el estado que dice llevar.** Tal como la propones, `apply_replicated_state(state, at_bus_local, velocity_bus_local, anchor_name)` no dice **quién sostiene** la caja cuando el estado replicado es `HELD`, y sin eso el cliente no puede colgarla de la mano correcta cuando hay dos tripulantes. Añade el peer (o el nombre de la tripulante) al argumento, y enumera en la fase 0 qué hace la función en **cada** transición, incluida la que no has nombrado: `STRAPPED → FREE` replicado, que hoy solo existe pasando por la mano.

**g2.11 — menor: la sonda está commiteada pero no integrada.** `run_carry_probe.gd` no aparece ni en `README.md` ni en `AGENTS.md`, donde sí están `run_demo` y el arnés. Una herramienta que nadie sabe que existe se vuelve a escribir en seis meses. Una línea en cada sitio con el comando.

**g2.12 — nota de método, y refina mi propia explicación.** Dije que la interpolación "recorta los picos". Más exacto: **reparte cada impacto de 30 Hz entre dos ticks de 60 Hz**, así que el pico *por tick* se divide por dos **por construcción**, no porque el pasajero vaya mejor. Es otra razón, y más fuerte, para no juzgar por el máximo: la métrica por tick es sensible a la cadencia de muestreo y se puede "ganar" alisando. El p99 sobre la distribución completa no.

**g2.4 — menor, honestidad de la evidencia.** Tu propia corrida deja un aviso del motor en `03_raw/carry_final.log`: `Jolt Physics job system exceeded the maximum number of jobs`. Sale en el caso patológico (a), con la tripulante arrastrada por la geometría 1.961 ticks, así que es plausible que sea consecuencia de eso y no un problema del código. Pero el estándar del proyecto es declarar los avisos, no que aparezcan solo en el log. Una línea en la 03 diciendo dónde sale y por qué crees que sale.

**g2.5 — menor, una etiqueta que engaña.** La sonda imprime `recording checksums standing=… walking=… (must match)` y los dos números **no coinciden** (53475,9 y 54368,4), porque —como bien descubriste— la tripulante caminando perturba el bus. La etiqueta dice lo contrario de lo que el dato significa y no hay aserción detrás. Cámbiala: lo que debe coincidir es la grabación **dentro de un mismo régimen**, y la diferencia entre regímenes es el hallazgo, no un fallo.

**g2.6 — el hallazgo es tuyo y es bueno; el número no dice lo que los dos creímos.** Que el bus sienta a su tripulación es cierto y lo prueban los checksums distintos. Pero **`_recording_checksum` es una suma CON SIGNO de `x + y + z` sobre 3.600 muestras**, así que la diferencia de 892,46 no son "0,25 m por vuelta": son 0,248 por muestra en una suma de coordenadas, y al ser con signo **las cancelaciones pueden esconder divergencia mayor de la que revela**. Repetí tu lectura en mi primer borrador sin mirar la función; los dos nos equivocamos. Sustituye el checksum por algo que sea una distancia — máximo y p95 de `a[i].origin.distance_to(b[i].origin)` — y entonces el número se podrá citar. Al BACKLOG con el número bueno, no con este.

**g2.13 — MI TERCER ERROR DE ESPECIFICACIÓN: la columna "ticks sin suelo" no mide lo que el gate necesita.** La pedí yo, con esas palabras, en el plan y en el prompt de la ronda 2, y tú la implementaste literalmente: `if not _crew.is_on_floor()`. El problema es que `is_on_floor()` dice **cualquier** suelo, incluido el `Ground` de 200×200 del Playground, que está en la máscara de la tripulante. Se ve en tus propios crudos: en `static_standing.csv`, el tick 1200 tiene **59,6 m de deriva del bus y `on_floor = 1`**, y **3.291 de 3.600 ticks** tienen deriva mayor de 10 m con `on_floor = 1`. O sea: en la fila (a), "sin suelo 14/3600" no significa que la tripulante fuera bien; significa que la expulsó el bus y se quedó de pie **en la carretera**. Para el gate la columna tiene que ser "**no apoyada en el bus**": comprobar el cuerpo del apoyo (`get_platform_rid()` o el colisionador del último `get_slide_collision()`) contra el bus y su interior, o exigir además que la posición local esté dentro del casco. Renómbrala a lo que mida.

## Qué hace falta para cerrar

**Ejecutor: reparte el enjambre**, con la fase 0 llevando dentro las seis correcciones. Bloqueantes: **g2.1** (el receptor escribe desde `physics_frame`, con test que lo pinea), **g2.7** (cada régimen reproduce su propia grabación, y se rehace la mitad caminando de la tabla), **g2.8 y g2.9** (el grupo `package` y las búsquedas de tripulante que reintentan). Y además **g2.2** (D95 con el p99, ya reescrito en el plan), **g2.3** (`bus_remote_error` en el JSON) y **g2.10** (el sostenedor en `apply_replicated_state`). g2.4, g2.5 y g2.11 son una línea cada una y van en el mismo commit; g2.6 al BACKLOG.

No pido otra parada intermedia: todas son concretas y ninguna abre una pregunta de diseño nueva. La siguiente vez que nos veamos es con la primera iteración del gate medida.

Y cuando la corrida del gate exista, la primera iteración se juzga con el criterio nuevo: **p99 del deslizamiento ≤ 1,5× el del anfitrión**, contadores de actividad con el mínimo de diez ciclos, error remoto de bus, tripulante y carga, atravesamientos con la tolerancia declarada, y fps por percentil 1.

**Dueño:** nada que jugar todavía. Lo tuyo es el gate de cinco minutos en la instancia cliente cuando el enjambre entregue.
