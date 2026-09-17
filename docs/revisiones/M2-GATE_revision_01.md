# Revisión 01 — M2-GATE (paso 0 cerrado y tabla del paso 1)

**Fecha:** 2026-09-15 · **Revisa:** Claude · **Revisado:** rama `m2/gate-two-instances`, HEAD `d7d956f` (5 commits sobre `main` `2b16e99`: plan y prompt, conteo exacto, división de la suite, nota de BACKLOG, evidencia 03 y 11) · **Pliego:** `docs/planes/M2-GATE_plan.md` (D91–D97) + `M2-GATE_ronda1_prompt.md`

## Veredicto: el paso 0 PASA. El paso 1 NO SE APRUEBA todavía, y una de las tres razones es mía.

Hiciste lo correcto al parar. Pero antes de repartir el enjambre hay que rehacer la medición, porque **no reproduzco tu fila (c)**, porque **la métrica que usas no mide lo que el gate llama jitter**, y porque **el umbral con el que ibas a juzgarla lo escribí yo mal**: con mis números, la tripulante del anfitrión, sin red de por medio, lo incumple por seis veces a los cinco minutos. Además, la velocidad honesta del gate no es 66,7 km/h: sobre los baches, que es donde el criterio la exige, el bus pasa a **46,8 km/h de media**.

Lo bueno: la decisión de fondo (bus del cliente `KINEMATIC` con interpolación) **es la correcta**, y lo confirmo con mis propias medidas. Lo que falla es la justificación, no la elección.

## Reproducción del revisor (Windows, 2026-09-15 18:40–19:20 UTC)

| Prueba | Resultado |
|---|---|
| `tools/run_tests.ps1`, tres corridas seguidas, con el escenario de red | código **0, 0, 0**; **180** tests descubiertos y verdes las tres veces, con el conteo exacto ya en vigor; red `pass` las tres |
| `tools/run_tests.sh`, con el escenario de red | código **0**; 180 tests; red `pass` |
| **Mordida del conteo exacto (r2.1), `.ps1`:** renombré un test en un worktree y corrí el arnés | **exit 1**, `FAILURE: 179 tests discovered, expected exactly 180`. El guardia muerde de verdad, con un mensaje que dice qué hacer. Restaurado |
| **Mordida del conteo exacto, `.sh`** | **exit 1** con el mismo mensaje. Los dos arneses muerden, no solo el de PowerShell |
| Alcance (`git diff main HEAD`) | 10 archivos: los dos arneses, la suite partida, `AGENTS.md` (la línea del comando), `BACKLOG.md`, el plan y el prompt míos, y dos evidencias. Ni `src/` ni `data/` ni escenas tocados |
| Estáticos | 180 `func test_` · `restraint_anchor_test.gd` 196 líneas · `restraint_lap_test.gd` 255 líneas (R8 con holgura) |
| Árbol | limpio en `d7d956f`, **pero no en un clon fresco**: véase g0.3 |

### Mi reproducción determinista del paso 1

Tu sonda fue borrada, así que monté la mía y la hice **determinista**, que es lo que permite comparar: un solo proceso con `--fixed-fps 60`, grabando primero la trayectoria real del bus con la demo a fondo (2.400 muestras) y **reproduciéndola después** sobre un bus congelado, exactamente con los dos mecanismos que mides — mantener la última foto de 30 Hz (tu (b)) o interpolar entre las dos últimas con una foto de retardo (tu (c)). Las tres configuraciones comparten la misma trayectoria grabada y la misma velocidad media reproducida, así que la comparación es limpia. Repetí cada corrida: cifras idénticas al cuarto decimal.

Y añadí la medida que a tu tabla le falta: el **deslizamiento por tick**, es decir cuánto se mueve el piso bajo los pies de la tripulante en cada tick de física. Eso es el jitter. La deriva es otra cosa.

| Configuración (ventana de 30 s) | deriva máx | deriva p95 | **desliz./tick máx** | **desliz./tick p95** | sin suelo | bajo el piso | fuera |
|---|---|---|---|---|---|---|---|
| **Anfitrión: bus REAL simulado** (línea base, sin red) | 0,317 | 0,301 | **0,0785** | **0,0039** | 0 | 0 | 0 |
| (b) Cliente `KINEMATIC`, sin interpolar | 0,428 | 0,407 | **0,1586** | **0,0085** | 0 | 2 | 2 |
| (c) Cliente `KINEMATIC` + interpolación | 0,445 | 0,385 | **0,0791** | **0,0060** | 0 | 1 | 1 |

Léelo así, porque cambia la conclusión: **la interpolación no mejora la deriva** (0,428 → 0,445 de máximo; 0,407 → 0,385 de p95: ruido). Lo que hace, y lo hace bien, es **partir por la mitad el deslizamiento por tick** (0,159 → 0,079) y dejarlo en el mismo nivel que el bus real (0,079 frente a 0,078). Es decir: **la interpolación no quita deriva, quita jitter**. Tu decisión es correcta; tu tabla no la demuestra porque no mide jitter.

### Y medí lo que el gate exige y nadie midió: caminando

De pie es el caso fácil. El criterio del maestro dice **caminar**, agarrar y amarrar. Repetí las tres configuraciones con la tripulante paseando el pasillo con la API de movimiento real (`drive_move`), acotada para no salir por el hueco trasero:

| Configuración (caminando, 30 s) | deriva máx | **desliz./tick máx** | desliz./tick p95 | sin suelo | bajo el piso | fuera |
|---|---|---|---|---|---|---|
| **Anfitrión: bus REAL** | 1,708 | **0,0772** | 0,0673 | 0 | 0 | 0 |
| (b) Cliente sin interpolar | 1,824 | **0,1581** | 0,0689 | 0 | 6 | 6 |
| (c) Cliente interpolado | 1,729 | **0,0774** | 0,0679 | 0 | 6 | 6 |

Caminando, el p95 del deslizamiento lo domina su propio paso (0,066 m por tick a 4 m/s) y deja de distinguir. El **máximo** sigue distinguiendo, y con una limpieza notable:

| | de pie | caminando |
|---|---|---|
| Anfitrión (bus real) | 0,0785 | 0,0772 |
| (b) sin interpolar | 0,1586 = **2,02×** el anfitrión | 0,1581 = **2,05×** |
| (c) interpolado | 0,0791 = **1,01×** | 0,0774 = **1,00×** |

Un detalle que sí importa y que salió de mirar **dónde** ocurren las violaciones: los 6 ticks "fuera" del cliente no son la puerta, como supuse al principio. Son un **hundimiento en el piso**: la tripulante baja a `y` local −0,69 (el piso está a −0,60) durante seis ticks seguidos y va recuperando (−0,69 → −0,65). Nueve centímetros durante una décima de segundo, una vez en 30 s, **solo en el cliente** (el anfitrión da cero con el mismo umbral). No es catastrófico, pero obliga a afinar el criterio: "cero atravesamientos" a secas lo incumple hasta la mejor configuración, y un criterio que no pasa nadie es tan inútil como uno que pasa todo. Propongo: **ninguna penetración de más de 5 cm, y ninguna que dure más de 3 ticks**, medido en las dos instancias, con el hueco de la puerta excluido del casco.

Ese es el criterio que el gate necesita: **el pico de deslizamiento por tick del cliente frente al del anfitrión en la misma corrida**. Duplica sin interpolar, y con interpolación el cliente es indistinguible del anfitrión al 1 %, esté de pie o caminando. Buena noticia para ti: **caminando, tu (c) aguanta** y nadie se cae (cero ticks sin suelo en las tres).

### La fila (c) no la reproduzco, y repetí con TU ventana

Tu evidencia mide 60 s. Mi primera tanda medía 30 s, así que repetí con la tuya para que no quede esa objeción:

| | Tu evidencia 03 (60 s) | Yo a 60 s | Yo a 30 s |
|---|---|---|---|
| Línea base del anfitrión (bus real) | no medida | 0,335 / 0,320 | 0,317 / 0,301 |
| (b) sin interpolar | 0,998 / 0,823 | 0,499 / 0,499 | 0,428 / 0,407 |
| **(c) interpolado** | **0,099 / 0,099** | **0,445 / 0,401** | 0,445 / 0,385 |

Sigue habiendo un factor de cuatro y medio en la fila que decide la arquitectura. Dos razones por las que desconfío de tu número antes que del mío, y una tercera que **retiro**:

1. **Mi línea base es consistente con un dato independiente y anterior, y aquí hay que hilar fino porque yo mismo lo comparé mal al principio.** T2.2 no midió "0,30 m" a secas: midió un vector de máximos **por eje** con la tripulante quieta, `(0,300 lateral · 0,147 vertical · 0,196 longitudinal)` (`crew_ride_test.gd`, evidencia 04 de T2.2). Yo reporto una **distancia 3D escalar**, que no es la misma magnitud: la cota superior del escalar a partir de aquel vector sería 0,387, y yo mido 0,335 a 60 s. Encaja. Lo que no encaja es tu 0,099: está **por debajo incluso del eje más pequeño de T2.2** (0,147, el vertical) y es un tercio del lateral, para una tripulante de pie sobre un bus que recorre el mismo circuito.
2. **La dirección del error va al revés de lo esperable.** Tu montaje es en tiempo real, con dos procesos y llegada irregular de paquetes: eso es *más* sucio que mi cadencia perfecta de 30 Hz, así que tu (c) debería salir **peor** que la mía, no cuatro veces mejor. Tu (b), que sí sale peor que mi (b), encaja con esa lógica; tu (c) no.
3. **Retiro el argumento de que `máx = p95` prueba un error de medición.** Lo escribí, y luego mi propia (b) a 60 s me dio 0,499 y 0,499, idénticos. Lo que ese patrón dice no es "la sonda está rota", sino **"la tripulante dejó de moverse y el valor se congeló"**. Aplicado a tu (c) significa que se quedó quieta tras 9,9 cm. Eso puede pasar si se encaja contra un estante o una pared, y entonces el número mide **dónde se atascó**, no cuán estable es el bus. Sigue sin servir como justificación, pero por otra razón que la que di.

No digo que tu número sea falso. Digo que **no se puede repetir**, que no cuadra con dos referencias independientes, y que sobre él ibas a construir la arquitectura del gate.

## Velocidad: el número honesto no es 66,7 km/h

Aquí tu conclusión práctica es correcta y tu enunciado es impreciso, y la imprecisión importa porque es el criterio del maestro.

| Medición mía | Resultado |
|---|---|
| Pico de velocidad en la vuelta de la demo | 66,7 km/h (coincide con el tuyo) |
| **Velocidad al CRUZAR el campo de baches en la vuelta** (380 ticks dentro del campo) | **media 46,8 km/h · pico 62,8 · mínimo 34,6** |
| Recta a fondo por el carril de los baches (102 m disponibles desde el borde sur) | llega al primer bache a **66,6 km/h** |
| ¿Se alcanzan 80 km/h con el bus actual? | **Sí: a los 144,2 m y 11,0 s**, y sigue subiendo (82,7 km/h a los 160 m) |

Conclusiones, en orden:

- **"80 km/h no se alcanza en este Playground" no es exacto.** El bus llega a 80 km/h sobre el suelo de 200×200 sin tocar nada; lo que no cabe es la carrerilla **antes del primer bache**: hacen falta 144 m y el carril ofrece unos 102–107 m.
- **El número que ibas a declarar, 66,7, tampoco es el del criterio.** El criterio dice "a 80 km/h **sobre baches**", y sobre baches la vuelta va a **46,8 de media**. Declarar 66,7 sobrevende el ensayo en un 42 %.
- **Hay una mejora gratis:** si el modo gate ataca el campo de baches **en recta** en vez de siguiendo el circuito, cruza a 66,6 en lugar de 46,8, sin tocar una sola escena. Eso deja el hueco hasta 80 en un 17 % en vez de un 41 %, y se declara.

## Lo que hay que reconocerte

- **Paraste donde había que parar**, con la tabla delante y sin repartir el enjambre. Es la tercera vez seguida y es lo que hace que este método funcione.
- **El conteo exacto muerde.** Lo probé yo con otro test distinto del tuyo y falla igual, con un mensaje que además dice qué hacer si el cambio era intencionado. r2.1 queda cerrado de verdad.
- **La división de la suite es limpia, y lo comprobé nombre a nombre**: los 8 tests del original están los 8, en el mismo orden, repartidos 5 (mecánica del anclaje) + 3 (integración en la vuelta), y la cuenta de aserciones es **63 en el original y 63 en la suma de las dos**. Nada se perdió por el camino, que es el fallo típico de partir un archivo. Las dos quedan con holgura sobre R8 (196 y 255 líneas).
- **La fila (a) es un hallazgo real y bien medido**: un `STATIC` no transporta nada y la tripulante del cliente sale despedida del casco. Confirmo el mecanismo; es exactamente lo que el plan anticipaba y ahora está medido.
- **La conclusión de fondo es correcta**, aunque la justificación no lo sea: la interpolación es lo que hay que adoptar.

## Hallazgos

### Míos, y el primero es contra mí

**g0.1 — MI ERROR: el umbral de deriva de D95 es imposible, y no por culpa de la red.** Escribí "deriva p95 < 0,30 m y máx < 0,60 m" extrapolando el 0,30 m que T2.2 midió en una ventana corta. Medí la deriva de la tripulante del **anfitrión**, sobre el bus real, sin red de por medio, alargando la ventana:

| Ventana | deriva máx | deriva p95 | **desliz./tick p95** |
|---|---|---|---|
| 30 s | 0,317 | 0,301 | 0,0039 |
| 90 s | 0,484 | 0,391 | 0,0040 |
| 180 s | 0,784 | 0,663 | 0,0040 |
| **300 s (la duración del gate)** | **2,024** | **1,889** | **0,0041** |

La deriva **no es una magnitud acotada**: una tripulante quieta se desliza despacio por el pasillo hasta que la para la geometría, así que el número mide cuánto duró la ventana, no cuán estable es el bus. El deslizamiento por tick, en cambio, **es plano en las cuatro ventanas**. Corrección de D95, y va al plan:

- **Criterio duro, sobre el PICO de deslizamiento por tick**, y **relativo a la línea base del anfitrión medida en la misma corrida**: el cliente no debe superar **1,3× el máximo** del anfitrión. Lo comprobé en los dos regímenes y separa igual de limpio en ambos: (c) da 1,01× de pie y 1,00× caminando; (b) da 2,02× y 2,05×. Un criterio que distingue en los dos casos es un criterio que sirve. El p95 vale de pie (0,0039 frente a 0,0060 y 0,0085) pero **no caminando**, porque ahí lo domina el propio paso: repórtalo, no lo juzgues.
- **Atravesamientos, con tolerancia declarada**: ninguna penetración de más de **5 cm** ni de más de **3 ticks**, en las dos instancias, con el hueco de la puerta excluido del casco. Sin tolerancia el criterio no lo pasa ni la mejor configuración: medido, el cliente interpolado se hunde 9 cm durante 6 ticks una vez en 30 s.
- **La deriva se reporta, no se juzga**, y siempre junto a la del anfitrión en la misma corrida. Caminando no mide nada: el paseo guionizado de ida y vuelta desplaza a la tripulante metros **por diseño**, y eso es justo lo que el número recoge (lo medí: 1,7 m de "deriva" caminando en las tres configuraciones). Si en algún momento quieres juzgarla, hay que definirla como **residuo involuntario** — posición medida menos la integrada desde la velocidad comandada — o evaluarla solo en las ventanas con el mando de caminar en cero. Y reportarla **por eje**, para que se pueda comparar con el `(0,300 · 0,147 · 0,196)` de T2.2.
- **Los fps no se promedian**: el criterio es el **percentil 1 y el porcentaje de fotogramas por debajo de 60**. Un tirón de medio segundo no mueve una media.

**g0.5 — el JSON de métricas no puede probar dos tercios del criterio.** El esquema que propones registra posiciones, errores y fps, pero **ni un solo contador de agarres, sueltas, amarres o traspasos de autoridad**. El criterio del maestro es "caminar, **agarrar y amarrar**": una iteración podría salir verde en todos los umbrales con la tripulante sin haber agarrado nada en cinco minutos, porque el RPC se cayó a los veinte segundos o el anclaje estaba ocupado, y nadie se enteraría. Añade por instancia `{hold_requested, hold_granted, hold_denied, release, strap_ok, strap_denied, unstrap, authority_transfers}` con el instante del último evento, y **exige un mínimo de ciclos completos** agarrar → amarrar → desamarrar → soltar en **cada** instancia (diez en 300 s es razonable). Sin ese mínimo la iteración no es fallida: es **inválida**, y no consume una de las tres de D96.

**g0.6 — menor, higiene.** Los dos arneses siguen explicando en seis comentarios internos el guardia viejo de ">= 3" (`run_tests.ps1:12`, `:204-205`, `:209-210` y los tres equivalentes en `run_tests.sh`), aunque la cabecera y el paso 6 ya se actualizaron. El siguiente que abra el archivo para subir la constante leerá dos contratos contradictorios en el mismo archivo. Y la razón por la que el paso 2 borra `reports/` **ahora es más importante, no menos**: con conteo exacto, un `results.xml` viejo de una corrida acotada haría fallar la corrida en vez de aprobarla en falso.

**g0.2 — la sonda del paso 1 está borrada, y esta no es una sonda cualquiera.** Las de T2.2 y T2.3 eran demostraciones de un solo uso y borrarlas estaba bien. Esta **decide la arquitectura del gate** y su número no se puede auditar ni repetir. Tiene que vivir en `src/tooling/` como `run_demo.gd` y `probe_handling.gd`, commiteada, con los datos crudos por configuración guardados junto a la evidencia.

Y lo digo con la autoridad de haberme equivocado tres veces hoy en la mía: mi primera versión reproducía la grabación a media velocidad, la segunda mandó el bus fuera del mapa y midió caída libre a 351 km/h, y la tercera hacía caminar a la tripulante en su propio marco, de modo que al girar el bus salía por la puerta y yo medía 90 m de "deriva". Los tres números eran plausibles y los tres eran basura. Una sonda que decide una arquitectura tiene que poder correrla otro y encontrar el fallo.

**g0.3 — un clon fresco nace sucio.** Al partir la suite quedó `tests/cargo/restraint_test.gd.uid` huérfano (apunta a un archivo que ya no existe) y las dos suites nuevas **sin** `.uid`. Lo verifiqué importando en un worktree limpio: Godot genera los dos `.uid` que faltan y `git status` deja de estar limpio, que es un criterio de aceptación de todas las rondas. Borrar el huérfano y commitear los dos nuevos.

**g0.4 — la evidencia 11 cita una corrida que no existe.** Dice "el verde final queda probado por las tres corridas de la evidencia 02", y en `docs/evidencia/M2-GATE/` solo están la 03 y la 11. Lo verde que sí está probado es `tests/cargo` (23/23), no el árbol completo. O se corre y se adjunta la 02, o la frase se quita.

### Los que condicionan la fase 0 y hay que resolver ANTES de repartir

**g1.1 — `NodePath` no vale como identidad de un paquete.** Amarrar **reparenta** la caja de `Cargo` al `Bus` (medido en T2.3: el padre pasa de `Cargo` a `Bus`). La ruta que el cliente calculó para pedir el amarre deja de existir en cuanto el amarre ocurre, y `request_unstrap(package_path)` llegaría con una ruta muerta. Usa una **identidad estable** (el nombre del paquete, resuelto por grupo en el receptor) en los cuatro RPC.

**g1.2 — `request_release(at)` tiene que viajar en el marco del BUS.** Si el cliente manda un punto en coordenadas de mundo y el anfitrión lo aplica una o dos fotos después, el bus ya no está ahí: a 66,7 km/h son 18,5 m/s, es decir **0,6–1,2 m de error** según la latencia. Es exactamente la lección de la ronda 4 de T2.2 (guardar el punto en el marco del bus y restaurarlo con la transformada **actual**). Lo mismo para la velocidad: que viaje la parte relativa al bus y el receptor le sume la del punto del bus.

**g1.3 — en el rol anfitrión no nace ninguna caja.** `playground.gd` solo genera la carga `if cargo_spawn and not demo_mode`, y el guion de red pone `demo_mode = true` justo en el rol anfitrión (`run_net_scenario.gd:117`). El gate necesita carga **en el anfitrión**, que es quien tiene su autoridad según D94. Hay que separar "la demo conduce" de "hay carga", y de paso fijar nombres deterministas: hoy los nodos se llaman `Package`, `@RigidBody3D@2`… (lo medí en T2.3), y el spawner rechaza los nombres reservados.

**g1.4 — el rol cliente es injugable por un humano, y D97 lo exige.** `playground.gd:44` deja `crew_input.enabled = false` para el cliente, `:47` lo saca de modo jugador, `:51` pone la cámara de persecución y `:52` no captura el ratón. Tal cual está, el dueño no puede jugar la instancia cliente. Es un cambio pequeño y hay que meterlo en la fase 0, no descubrirlo el día del gate.

**g1.5 — once búsquedas atan el juego a la PRIMERA tripulante del árbol.** `get_first_node_in_group("crew")` y sus hermanas aparecen en `playground.gd` (×2), `crew_hands.gd`, `crew_input.gd` y `door_transit.gd`. Con dos tripulantes en escena, la puerta, las manos, el ojo y la cámara pueden engancharse a la equivocada. `NetAuthority.local_crew()` sola no basta: hay que recorrer esas once y decidir una por una si quieren "la local" o "la de este nodo".

**g1.6 — el presupuesto de tiempo mata la corrida del gate a mitad.** `NetScenarioUtil.route_budget_s(waypoints) = max(30, waypoints × 15)`: con la vuelta completa son **240 s**, y de ahí salen las tres esperas del guion — el anfitrión (`run_net_scenario.gd:203`), el cliente (`:284`, +15 s) y **el plazo del lanzador** (`:364`, +45 s, es decir **285 s**). El gate dura **300 s**: muere antes de terminar y se reporta como fallo de los hijos, no como lo que es. El presupuesto del modo gate tiene que salir de `seconds`, que ya existe como argumento y hoy solo se usa para otra espera.

**g1.7 — `Package` no tiene por dónde aplicar un estado que llega de fuera.** `strap()` exige `HELD` como precondición y `unstrap()` devuelve la caja a `HELD`. Un peer remoto que recibe "esta caja quedó amarrada" no puede aplicarlo sin pasar por la mano, y un "quedó suelta" lo dejaría en `HELD` sin sostenedor. Hace falta un camino de aplicación de estado replicado, distinto del camino de intención del jugador, y eso es diseño de la fase 0.

## Qué hace falta para cerrar

**Ejecutor, antes de repartir el enjambre:**

1. Rehacer el paso 1 con la **sonda commiteada** en `src/tooling/`, determinista (`--fixed-fps 60`, grabar y reproducir, como la mía) o en tiempo real pero con **tres corridas por configuración** y la varianza a la vista. Mide **deslizamiento por tick** además de deriva, y **mide también la línea base del anfitrión** en la misma corrida. Si tu (c) vuelve a dar 0,099 con eso, el que está equivocado soy yo y lo escribo.
2. Traer a la tabla el **caso que el gate exige y nadie ha medido: la tripulante CAMINANDO**, no de pie.
3. Cerrar g0.3 y g0.4.
4. Rehacer la sección de velocidad de la 03 con los tres números: pico de la vuelta, **velocidad sobre los baches**, y la de un ataque en recta. Y proponer cuál de los dos recorridos usa el gate.
5. Traer la fase 0 con g1.1 a g1.7 ya resueltos en las firmas, no en los comentarios.

**Revisor (yo):** D91–D97 se corrigen con lo anterior; D95 se reescribe entero sobre el deslizamiento por tick y relativo al anfitrión, que es mi error y ya está redactado arriba.

**Dueño:** nada que jugar todavía. Lo tuyo llega cuando el gate corra: cinco minutos en la instancia cliente mientras el anfitrión conduce.
