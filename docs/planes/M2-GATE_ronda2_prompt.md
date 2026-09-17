# Prompt para el agente ejecutor — M2-GATE Ronda 2 (rehacer la medición del paso 1 y cerrar la fase 0)

Copiar desde `CONTEXTO:` hasta el final. Ronda secuencial, un solo agente: **no se reparte el enjambre todavía**. Vuelve a parar al final del punto B.

---

CONTEXTO: Proyecto "Ruta Frágil" (Godot 4.7.2, GDScript tipado). Obedece R1–R14: están textuales en `AGENTS.md` §0.3. Repo local: `C:\Users\Leo\Documents\RutaFragil`, rama `m2/gate-two-instances` (HEAD `d7d956f`; `main` en `2b16e99`). Hay archivos del revisor sin commitear (`docs/revisiones/M2-GATE_revision_01.md`, `docs/planes/M2-GATE_ronda2_prompt.md`): cométealos tal cual primero.

**EL PASO 0 PASA.** El conteo exacto muerde: el revisor lo probó con un test distinto del tuyo y el arnés cayó con `FAILURE: 179 tests discovered, expected exactly 180` y código 1. La división de la suite conserva los 8 tests (5 + 3) y ambas quedan con holgura sobre R8.

**EL PASO 1 NO SE APRUEBA**, por tres razones, y **una es del revisor**. Lee entera `docs/revisiones/M2-GATE_revision_01.md`; esto es el resumen operativo.

1. **Tu fila (c) no se reproduce.** El revisor montó una réplica **determinista** del mismo mecanismo (un proceso, `--fixed-fps 60`, grabar la trayectoria real del bus y reproducirla sobre un bus congelado, manteniendo la última foto de 30 Hz o interpolando entre las dos últimas). Sus números, con la misma trayectoria en las tres filas y repetidos idénticos:

   | Configuración (de pie, 30 s) | deriva máx / p95 | desliz./tick máx / p95 | sin suelo | bajo piso | fuera |
   |---|---|---|---|---|---|
   | Anfitrión, bus REAL (línea base) | 0,317 / 0,301 | 0,0785 / 0,0039 | 0 | 0 | 0 |
   | (b) cliente sin interpolar | 0,428 / 0,407 | 0,1586 / 0,0085 | 0 | 2 | 2 |
   | (c) cliente interpolado | 0,445 / 0,385 | 0,0791 / 0,0060 | 0 | 1 | 1 |

   El revisor repitió además con **tu misma ventana de 60 s**: línea base 0,335 / 0,320 · (b) 0,499 / 0,499 · **(c) 0,445 / 0,401**. Tu (c) da 0,099, cuatro veces y media mejor. Dos cosas no cuadran: la línea base del revisor reproduce el 0,30 m que T2.2 ya había medido de forma independiente; y tu montaje (tiempo real, dos procesos, llegada irregular) debería salir **peor** que una cadencia perfecta de 30 Hz, no mejor. (El revisor había escrito que `máx = p95` probaba un error de medición; lo retira: su propia (b) a 60 s dio 0,499 y 0,499. Lo que ese patrón dice es que la tripulante **dejó de moverse**; en tu (c), tras 9,9 cm. Si se atascó contra un estante, el número mide dónde se atascó, no la estabilidad del bus.)

2. **La métrica no mide lo que el gate llama jitter.** "Distancia al punto de asiento" no distingue un desplazamiento neto constante (inofensivo) de una oscilación de la misma amplitud (que es lo que el gate prohíbe). Y además **no está acotada**: el revisor midió la deriva del anfitrión, sin red de por medio, alargando la ventana — 30 s: 0,317 · 90 s: 0,484 · 180 s: 0,784 · **300 s: 2,024**. Crece con el reloj. El **deslizamiento por tick** (cuánto se mueve el piso bajo los pies en cada tick) se quedó plano en 0,0039–0,0041 en las cuatro ventanas. Esa es la magnitud estable.

3. **El umbral de D95 lo escribió mal el revisor** (deriva p95 < 0,30 m), extrapolando un número de T2.2 a una ventana seis veces mayor. A 300 s no lo cumple ni la tripulante del anfitrión sin red. D95 se reescribe; el texto nuevo está en la revisión y lo repito abajo.

También: **la velocidad honesta no es 66,7 km/h.** Ese es el pico de la vuelta. Medido por el revisor, el bus **cruza el campo de baches a 46,8 km/h de media** (pico 62,8, mínimo 34,6), que es donde el criterio del maestro exige los 80. Y "80 km/h no se alcanza en este Playground" no es exacto: el bus llega a 80 a los **144 m** de recta; lo que no cabe es la carrerilla **antes del primer bache** (el carril ofrece ~102 m, donde llega a 66,6).

QUÉ HACER:

**A. La sonda se commitea (g0.2).** Esta medición decide la arquitectura del gate y hoy no la puede repetir nadie: la borraste. Va a `src/tooling/` junto a `run_demo.gd` y `probe_handling.gd`, con nombre propio (por ejemplo `run_carry_probe.gd`), argumentos por línea de órdenes para elegir configuración y ventana, y **los datos crudos por configuración** guardados junto a la evidencia 03. Hazla determinista si puedes (grabar la trayectoria del bus y reproducirla con `--fixed-fps 60`, que es como el revisor consiguió repetir cifras al cuarto decimal); si la haces en tiempo real con dos procesos, entonces **tres corridas por configuración** y la varianza a la vista.

**B. Rehacer la tabla del paso 1, y PARAR ahí.** Cuatro filas, no tres: **la línea base del anfitrión** (bus real simulado, sin red) más (a), (b) y (c). Dos regímenes: **de pie y CAMINANDO** — el criterio del maestro dice caminar y nadie lo había medido. Columnas: deriva máx y p95, **deslizamiento por tick máx y p95**, ticks sin suelo, bajo el piso, fuera del casco. Referencia del revisor caminando (30 s), por si tus números divergen:

   | Caminando | desliz./tick máx | frente al anfitrión |
   |---|---|---|
   | Anfitrión, bus real | 0,0772 | — |
   | (b) sin interpolar | 0,1581 | **2,05×** |
   | (c) interpolado | 0,0774 | **1,00×** |

   **Si tu (c) vuelve a dar 0,099 con la sonda commiteada, el equivocado es el revisor y lo escribirá.** Lo que no vale es que el número no se pueda repetir.

**C. Rehacer la sección de velocidad de la evidencia 03** con los tres números medidos: pico de la vuelta, **velocidad al cruzar los baches**, y velocidad de un ataque en recta por el carril. Y propón qué recorrido usa el modo gate. Nota del revisor: atacar el campo de baches **en recta** en vez de siguiendo el circuito sube el cruce de 46,8 a 66,6 km/h **sin tocar ninguna escena**, y deja el hueco hasta los 80 del maestro en un 17 % en vez de un 41 %. Sea cual sea tu elección, la evidencia declara el número real y la distancia que faltaría para 80 (144 m necesarios frente a ~102 disponibles).

**D. Dos cierres pequeños del paso 0:**
- **g0.3:** borra `tests/cargo/restraint_test.gd.uid` (huérfano: apunta a un archivo que ya no existe) y commitea los `.uid` de las dos suites nuevas. Verificado por el revisor: al importar en un clon limpio, Godot genera los dos que faltan y `git status` deja de estar limpio, que es criterio de aceptación de todas las rondas.
- **g0.6 (higiene):** los dos arneses siguen explicando en seis comentarios internos el guardia viejo de ">= 3" (`run_tests.ps1:12`, `:204-205`, `:209-210` y los tres equivalentes en `run_tests.sh`), aunque la cabecera ya se actualizó. Cámbialos en la misma pasada, sin tocar la lógica.
- **g0.4:** la evidencia 11 dice "el verde final queda probado por las tres corridas de la evidencia 02" y la 02 no existe en `docs/evidencia/M2-GATE/`. O la corres y la adjuntas, o quitas la frase. (El revisor sí corrió el arnés completo sobre el árbol partido: 180, red `pass`.)

**E. La fase 0 tiene que resolver esto EN LAS FIRMAS, no en los comentarios.** Son siete y las siete se verificaron leyendo el código:
- **g1.1 — `NodePath` no vale como identidad de un paquete.** Amarrar reparenta la caja de `Cargo` al `Bus`, así que la ruta que el cliente calculó muere en cuanto el amarre ocurre. Usa una identidad estable (el nombre, resuelto por grupo en el receptor) en los cuatro RPC.
- **g1.2 — `request_release(at)` en marco del BUS, no del mundo.** A 66,7 km/h son 18,5 m/s: una o dos fotos de latencia son 0,6–1,2 m de error. Es la lección de la ronda 4 de T2.2. Igual con la velocidad: viaja la parte relativa y el receptor le suma la del punto del bus.
- **g1.3 — en el rol anfitrión no nace ninguna caja.** `playground.gd:53` genera carga solo `if cargo_spawn and not demo_mode`, y `run_net_scenario.gd:117` pone `demo_mode = true` justo en el anfitrión. El gate necesita carga en el anfitrión, que es quien tiene su autoridad (D94). Separa "la demo conduce" de "hay carga", y fija nombres deterministas: hoy los nodos se llaman `Package`, `@RigidBody3D@2`… y el spawner rechaza los nombres reservados.
- **g1.4 — el rol cliente es injugable por un humano y D97 lo exige.** `playground.gd:44` deja el input deshabilitado para el cliente, `:47` lo saca de modo jugador, `:51` pone la cámara de persecución y `:52` no captura el ratón. Sin esto el dueño no puede jugar su gate.
- **g1.5 — once búsquedas atan el juego a la PRIMERA tripulante del árbol** (`get_first_node_in_group` en `playground.gd` ×2, `crew_hands.gd`, `crew_input.gd`, `door_transit.gd` y las de cámara/ojo). `NetAuthority.local_crew()` sola no basta: recórrelas una a una y decide si cada una quiere "la local" o "la de este nodo".
- **g1.6 — el presupuesto de tiempo mata la corrida del gate a mitad.** `NetScenarioUtil.route_budget_s(waypoints) = max(30, waypoints × 15)`: con la vuelta completa son 240 s, y de ahí salen la espera del anfitrión (`run_net_scenario.gd:203`), la del cliente (`:284`, +15 s) y el plazo del lanzador (`:364`, +45 s = **285 s**). El gate dura 300 s: muere antes de terminar. El modo gate deriva su presupuesto de `seconds`, que ya existe como argumento.
- **g1.7 — `Package` no tiene camino para un estado que llega de fuera.** `strap()` exige `HELD` y `unstrap()` devuelve a `HELD`: un peer que recibe "esta caja quedó amarrada" no puede aplicarlo sin pasar por la mano, y un "quedó suelta" la dejaría en `HELD` sin sostenedor. Hace falta un camino de **aplicación de estado replicado** distinto del de intención del jugador.

**D95 QUEDA ASÍ** (sustituye al del plan; el revisor ya lo corrigió en la revisión):
- **Criterio duro: el PICO de deslizamiento por tick del cliente no supera 1,3× el del anfitrión medido en la misma corrida.** Separa limpio en los dos regímenes: (c) da 1,01× de pie y 1,00× caminando; (b) da 2,02× y 2,05×.
- El p95 del deslizamiento se juzga **solo de pie** (caminando lo domina el propio paso, 0,066 m por tick); caminando se reporta.
- **Atravesamientos con tolerancia declarada**: ninguna penetración de más de **5 cm** ni de más de **3 ticks**, en las dos instancias, con el hueco de la puerta excluido del casco. Medido por el revisor: el cliente interpolado hunde a la tripulante 9 cm en el piso durante 6 ticks una vez en 30 s (el anfitrión, cero). Sin tolerancia el criterio no lo pasa ni la mejor configuración.
- **La deriva se reporta, no se juzga**, y siempre junto a la del anfitrión de la misma corrida.
- **Los fps no se promedian:** el criterio es el **percentil 1** y el **porcentaje de fotogramas por debajo de 60**.
- **Contadores de actividad en el JSON**, por instancia: `hold_requested`, `hold_granted`, `hold_denied`, `release`, `strap_ok`, `strap_denied`, `unstrap`, `authority_transfers`, con el instante del último evento. Y un **mínimo de diez ciclos completos** agarrar → amarrar → desamarrar → soltar en **cada** instancia: sin ellos la corrida puede salir verde con la tripulante sin haber agarrado nada en cinco minutos, y "agarrar y amarrar" son dos tercios del criterio. Por debajo del mínimo la iteración es **inválida**, no fallida, y no gasta una de las tres.
- **La deriva, si se reporta caminando, por eje** (para poder compararla con el `(0,300 · 0,147 · 0,196)` de T2.2, que es un máximo **por eje y de pie**, no una distancia 3D).

CRITERIOS DE ACEPTACIÓN: la sonda commiteada en `src/tooling/` y repetible por otro; la tabla de B con cuatro filas y dos regímenes, con datos crudos; la sección de velocidad con los tres números y el recorrido del gate propuesto; g0.3 y g0.4 cerrados; las siete de E resueltas en las firmas de la fase 0; tres arneses en código 0 con el conteo exacto; `git status` limpio **también tras importar en un clon fresco**; nada fuera de `src/tooling/`, `tests/`, `tools/`, la evidencia y los documentos — **`src/` de juego y las escenas no se tocan todavía**.

INSTRUCCIONES:
0. Commit de los archivos del revisor tal cual.
1. A, D y C primero (son independientes). Luego B.
2. **Para al terminar B** y responde con: la tabla nueva, la sección de velocidad, y la lista de interfaces de la fase 0 con las siete de E ya resueltas. No repartas el enjambre.
3. Reporte: hashes, los tres códigos de salida, las tablas, qué de tu medición anterior se sostiene y qué no, y si mantienes tu (c) con la sonda nueva.
