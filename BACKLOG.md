# BACKLOG.md — Ruta Frágil

Todo pendiente del proyecto vive aquí (R10: sin TODOs silenciosos en el código).

## Milestones (Parte 3 del maestro)

- **M0 — Fundaciones**
  - **T0.1** Proyecto Godot 4.7.2, Forward+, Jolt, estructura §20, Git+LFS, `AGENTS.md`, gdUnit4 corriendo headless con un test trivial, puente MCP elegido y documentado. ✅ *Acepta:* `run_tests` pasa en ambas máquinas; commit inicial.
  - **T0.2** `GameConfig` + `TuningTable` (Resources + JSON) con loader que fusiona `user://mods/`. ✅ *Acepta:* cambiar un JSON sin reabrir el editor altera el juego; un JSON en mods sobreescribe base; test cubre la fusión.
  - **T0.3** Escena `Playground` (plano, rampas, baches, agua) + modo demo automático (§21). ✅ *Acepta:* existe, carga, el bus placeholder recorre el circuito solo.
  - **T0.4** Arnés de pruebas de red multi-instancia (§0.8): script que lanza 1 host + N clientes headless sobre ENet en la misma máquina, ejecuta un guion (spawn, agarrar, amarrar, conducir el circuito automático) y afirma convergencia de estado; integrado en `run_tests`. ✅ *Acepta:* 1 host + 3 clientes headless completan el guion y los asserts pasan en ambas máquinas; el arnés queda como herramienta permanente y es prerrequisito del gate M4.
- **M1 — Bus y conducción (single, local)**
  - **T1.1** ADR-007: bus con suspensión por raycast, cámara conductor + exterior (§9.1). ✅ *Gate humano de feel (3 min).*
  - **T1.2** Recursos Combustible/Integridad/Desgaste; motor muere en 0; empuje. Bidón como prop físico con `fuel_liters`; toma exterior con vertido de 8 s y derrame en marcha. ✅ *Acepta:* tablero placeholder muestra valores; tests de drenaje, vertido y derrame; el bidón se cae si no está amarrado.
  - **T1.3** Estación (repostar pagado, bidones vacíos, reparar, mantención) con precios desde `TuningTable`. ✅ *Acepta:* ciclo dinero→servicio; comprar un bidón lo hace aparecer como prop.
- **M2 — Interior caminable ⚠️ RIESGO #1**
  - **T2.1** Interior grey-box según §4.3 (6 posiciones, pasillo de doble ancho).
  - **T2.2** Personaje primera persona (`CharacterBody3D`) sobre plataforma móvil; entrar/salir por puertas con el bus andando.
  - **T2.3** Agarrar/soltar/lanzar + amarrar (`restraint`) + los tres estados físicos de ADR-003.
  - ✅ **GATE M2 (duro, §0.7):** criterio de ADR-003 con 2 instancias locales. Si falla 3 veces → Opción B. Nada de M3+ sin este gate.
- **M3 — Paquetes y acciones cooperativas**
  - **T3.1** `PackageDefinition` + estados + 4 tipos MVP con FX placeholder + tests de decaimiento.
  - **T3.2** Herramientas de cuidado (rociador, cojines) y `CoopInteractable` con los tres modos (§3.4), con tests de ventana de sincronía.
  - **T3.3** Entrega (zona + timbre + destino correcto/incorrecto) + scoring + pantalla de resultados. ✅ *Acepta:* recorrido de 3 min con 6 paquetes mixtos produce pagos correctos; el flotante se escapa si nadie lo ata; paquete a la dirección equivocada = rechazo.
- **M4 — Red y voz ⚠️ RIESGO #2**
  - **T4.1** `NetworkBackend` con ENet (LAN): lobby, spawn de N jugadores (R1), personajes con autoridad propia.
  - **T4.2** ADR-006 completo: autoridad del bus al conductor, paquetes sueltos/en mano/amarrados, `CoopInteractable` replicado, snapshots + interpolación.
  - **T4.3** Backend Steam (GodotSteam MultiplayerPeer): lobby, invitar, relay. Mismo gameplay, cero cambios fuera de `NetworkBackend`.
  - **T4.4** Voz Steam por proximidad + radio + indicador de quién habla.
  - ✅ **GATE M4 (duro):** Mac + Windows en máquinas separadas, 20 min: paquetes coinciden en ambas pantallas; cambio de conductor sin tirones; voz posicional; reconexión entre contratos; medir ancho de banda con 30 paquetes.
- **M5 — Loop económico + B0 Ciudad**
  - **T5.1** Contratos data-driven + tablón + cuota + guardado ADR-008 (empresa del host, progreso personal).
  - **T5.2** B0 Ciudad grey-box con el guion de tutorial de §6.2, NPCs con reacciones, y 1–2 zonas de combustible en ramas (surtidor + barriles) con bidones vacíos en puntos fijos; la ruta mide 6–10 km para que el tanque no alcance.
  - **T5.3** Carga tipo Tetris. ✅ *Acepta:* run completa de 15 min, 4 jugadores en LAN, dinero entra y sale, nadie ocioso >2 min.
- **M6 — B1 Cerro + muerte/revivir**
  - **T6.1** Winche/cuerda (concurrente), pendientes que lo exigen, derrumbes.
  - **T6.2** Derribado/muerto/camilla/botiquín/fantasma; fuentes de daño §7.1.
  - **T6.3** Radiador + sobrecalentamiento; volcadura + enderezado sincronizado. ✅ *Acepta:* run de 25 min con un rescate por winche y una reanimación, sin softlocks.
- **M7 — B2 Pantano + hundimiento/rescate**
  - **T7.1** Lodo (fricción/velocidad/atascamiento), lianas y machete.
  - **T7.2** Flotadores instalables (4 puntos, concurrente) + flotación del bus; agua profunda; aire de jugador (§4.6) y rescate con cuerda.
  - **T7.3** Inundación interior + bomba de achique (relevo) + daño por agua; protocolo §7.4 completo. ✅ *Acepta:* hundir el bus a propósito y recuperarlo por las 3 vías; el acuático sobrevive feliz, el frágil no; un jugador se ahoga y es rescatado.
- **M8 — Producto**
  - **T8.1** Pase de arte según D16 (bus, paquetes, B0–B2, personajes) + audio.
  - **T8.2** UX final, tutorial pulido, pings, accesibilidad, ES/EN.
  - **T8.3** Steam: logros, cloud, rich presence, export CLI, demo. ✅ **GATE M8:** 3 grupos externos de 4; ≥2 piden seguir jugando.

Post-M8: Playtest → Next Fest → Early Access con B0–B2. Roadmap público: Submarino, luego Volcán, con tipos de paquete nuevos intercalados.

## Pendientes propios de la ejecución de M2-T2.2 (rondas 2–3)

- **`player_mouse_sensitivity` es una preferencia del jugador, no balance de juego** (nota del dueño, r3): en `TuningTable` está bien hoy, pero un mod podría cambiársela al jugador; cuando exista un menú de ajustes, ese campo se muda fuera del alcance de mods.
- **F1 al salir de demo deja `bus_input.enabled = true` aunque la tripulante esté a pie** (semántica heredada de T1.1/D71, cuando F5 era el asiento): tras F1×2, andar con W también acelera el bus aparcado. Candidato a paso 0 de T2.3: `bus_input.enabled` debe seguir a `crew.seated`.
- **El DisplayServer headless no retiene `Input.mouse_mode`** (medido 2026-09-14): en tests, la verdad de la captura la posee la app (`CrewInput.is_pointer_captured()`), nunca el flag del motor.

## Pendientes (copiados del plan M0-T0.1, sección 9)

- **M4:** `export_presets.cfg` con exclusión `addons/gdUnit4/*` (respetar mayúsculas). Según la doc de 4.7, `--export-release` **no** implica `--import`: correr `--import` explícito antes. Export templates 4.7.2 = `Godot_v4.7.2-stable_export_templates.tpz`, ~1,41 GB, verificar con `SHA512-SUMS.txt`.
- **M4:** GodotSteam movió su repo a Codeberg (GitHub archivado el 2026-09-04). GDExtension actual v4.22.1-gde, Godot 4.4+, Steamworks 1.65. Confirma la regla "solo el oficial de godotsteam.com".
- **M2 / ADR-003:** bug abierto de Godot #102763: `CharacterBody3D` se desliza sobre `AnimatableBody3D` en rotación, en ambos motores de física, fix pendiente sin milestone 4.7. Afecta la plataforma móvil del bus.
- **T0.4:** no existe `--user-data-dir` en 4.7. Instancias paralelas necesitan `--path` propio, `--log-file` propio y, para operaciones de editor, una copia del ejecutable con archivo `_sc_` al lado (modo autocontenido). Considerar `application/run/flush_stdout_on_print=true` y `debug/file_logging/enable_file_logging=true` cuando el agente necesite leer logs de instancias que crashean.
- **Headless no entrega InputEvents de teclado, pero el ESTADO de las acciones sí se conduce por código (corregido en M2-T2.2 r2; antes esta nota decía que todo input simulado exigía ventana, y era falso):** `Input.action_press`/`action_release` funcionan en headless y `is_action_pressed`/`get_action_strength` responden por tick — así se escriben los tests e2e de input (`tests/crew/crew_input_test.gd`). OJO: `is_action_just_pressed` se limpia en el flush del siguiente frame de PROCESO, y headless corre los frames de proceso mucho más rápido que los ticks de física a 60 Hz, así que un nodo no lo ve nunca desde `_physics_process` (medido 2026-09-13: 40 pulsaciones, cero vistas). Donde un test deba observar un flanco, el código lo detecta a mano con `is_action_pressed` + estado del tick anterior (así lo hace `crew_input.gd` con `interact`).
- Re-verificar gdUnit4 cuando salga **v6.2.2** (si añade 4.7.2 a la tabla de compatibilidad).
- 4.8-dev4 prohíbe strings como comentarios en GDScript: lint preventivo si algún día se salta a 4.8.
- **Correcciones al maestro para proponer al dueño:** §21 comando de gdUnit4; §15/D13 "Vulkan/MoltenVK" → backend por plataforma (D31); §0.2/T0.1 "`run_tests` pasa" → exigir conteo mínimo; §20 añadir `docs/`; §0.2, §20 y T0.1 dan por hecho un puente MCP y el proyecto decidió ninguno en M0 (D30/ADR-009); T0.1 'en ambas máquinas' → 'en Windows; Mac antes de M4' (D42); §19 nombra `GameConfig` al Resource y §20 al autoload; Godot no permite ambos → Resource `GameConfigData` + autoload `GameConfig` (D43).

## Pendientes propios de la ejecución de M0-T0.1 (M5 de la revisión 01)

- **Corrección del plan/maestro por formato de versión:** `Engine.get_version_info()["string"]` devuelve `4.7.2-stable (official)` (guion y paréntesis); el formato con puntos (`4.7.2.stable`) es solo el de `godot --version`. Defecto del plan v1.0 nº 1, corregido en el plan v1.1; queda como referencia para cualquier documento que cite el formato.
- **Al subir de parche 4.7.x** (ADR-000) hay que tocar cuatro archivos: `tests/smoke_test.gd`, `tools/run_tests.ps1`, `tools/run_tests.sh`, `README.md` (m8 de la revisión 01; la lista también está en `AGENTS.md` y en `README.md`).
- **Cierre de M0-T0.1 (solo el dueño, revisión 02 "Qué hace falta para cerrar"; actualizado por D42, 2026-09-09):** la corrida de `bash tools/run_tests.sh` en la Mac con el mismo hash del arnés queda **diferida por D42 hasta antes del gate M4** (red real Mac + Windows, D13) — ya no bloquea T0.1, que se acepta con `run_tests` verde solo en Windows. Residuo declarado: el arreglo de BOM POSIX de `run_tests.sh` (m-2.3) solo está probado bajo Git Bash; su prueba real en BSD sed queda para esa corrida. Siguen pendientes del dueño: crear el remoto con Git LFS habilitado + primer push, y comprobar el dock de gdUnit4 en el editor con ventana (revisión 01, ítem M4).

## Pendientes propios de la ejecución de M0-T0.2

- **M4:** mods empaquetados `.pck` con `ProjectSettings.load_resource_pack` (monta un `.pck` sobre `res://`, puede reemplazar `res://data/*.tres`); requiere export templates (§13, plan M0-T0.2 §3).
- **Vigilante automático de `mtime`** para recargar al cambiar un JSON sin llamar a `reload()`: diferido por D46 (un `Timer` + resolución de 1 s de `FileAccess.get_modified_time()` en Windows no aportan al criterio de T0.2).
- **Carpetas de mod con manifiesto:** cuando exista un segundo tipo de contenido (D45); en v1 los mods son archivos planos `user://mods/*.json`.
- **"Derrame ∝ velocidad" sin número en §8.1** (fila Bidón): no se inventó un campo en v1 (D47); definir el parámetro y su nombre en T1.2 (vertido y derrame del bidón).
- **Codec sin `Array` ni otros `Dictionary[K, V]`** (v1 solo soporta `Dictionary[String, int]`): ampliar `ResourceJsonCodec` antes de T3.1 (D45 promete extensibilidad a colecciones, p. ej. `{"packages": [...]}`).
- **Validación semántica pendiente:** `max_players ≥ 1`, `≤ max_players_hard_limit`, `min ≤ max` en los pares de rango, fracciones en [0,1]. Hoy un mod `{"game_config": {"max_players": 0}}` pasa la validación de tipos. Destino: lobby T4.1.
- **`*.json` en el filtro de export (decidir en M4):** por defecto Godot no empaqueta `*.json`; la capa base JSON se omitiría y el juego correría sobre el `.tres` (idéntico por el test de deriva). Decidir si el export incluye los JSON base.
- **Reglas cualitativas de §8.1 sin parámetro:** "Flotador ×4" (el conteo por bus no es un campo; `shop_prices.float` es precio por unidad) y "surtidor ilimitado / gratis en zonas". Definir si necesitan parámetro cuando entren sus mecánicas (T1.2/T5.2).
- **`schema_version` sin comprobar en v1:** se carga pero nadie lo valida ni hay migración; informativo hasta que exista una v2 del esquema.
- **Contradicción §13/§19 (reportada, decidir en T3.1):** §13 exige IDs con namespace para el contenido y §19 sitúa `base_pay` dentro de `PackageDefinition`, mientras v1 lo lleva plano en `TuningTable`. Decidir el dueño único de `base_pay` y su mapeo a IDs.
- **`reload()` reemplaza los objetos `data`/`tuning`:** los consumidores que guarden referencias a los Resources deben reengancharse en la señal `reloaded(report)` (T0.3+).
- **Observación:** editor con ventana: un segmentation fault al cerrar observado una vez bajo `timeout` (2026-09-10), no reproducido en dos intentos sin `timeout`; bug de apagado de 4.7 con plugins, fix en 4.8; sin acción.

## Pendientes propios de la ejecución de M0-T0.3

- **T1.1 reemplaza el bus placeholder** y hereda la interfaz `set_drive(throttle, steer, brake)`; los `@export` greybox del placeholder se eliminan ahí (D48).
- **Proponer al dueño:** incorporar los dos números de §4.5 (90 km/h, 0–60 en 5 s) a la tabla §8.1 del maestro (hoy viven en el esquema v1 como origen §4.5).
- **`WaterZone` se promueve** a `src/core/` o `src/biomes/` común en M7 (flotación/hundimiento, T7.2).
- **`src/tooling/run_demo.gd` es la base del guion de red de T0.4.**
- **El `uid` de las escenas `.tscn`** aparecerá al primer guardado desde el editor (diff de una línea por escena, esperado; §3 del plan M0-T0.3).
- **`physics_ticks_per_second` 120 Hz opcional** (§15) queda para M2.
- **Un `.tscn` escrito a mano necesita `node_paths=[...]`** en la cabecera `[node]` para que los `@export` tipados-Node se resuelvan: sin ese atributo cargan `null` en silencio (ni error ni warning). Cualquier escena manual con referencias `@export var x: Node` debe declarar `node_paths` (lección de la escritura a mano de `scenes/playground.tscn`).
- **En scripts `-s` no se pueden referenciar estáticamente clases que tocan un autoload:** compilan antes de que el autoload esté registrado y la cadena de tipos llega hasta él. `src/tooling/run_demo.gd` lo resuelve con duck-typing tipado (inspección por nombre de nodo/señal y lecturas `Variant` seguras); misma regla para futuras herramientas headless.
- **`apply_central_impulse` se descarta si ese mismo tick se asigna `linear_velocity` después** (orden de operaciones dentro de `_physics_process`): la asignación pisa el impulso. Quien combine impulsos con correcciones directas de velocidad debe fijar el orden con cuidado (lección del ajuste del bus placeholder).

## Pendientes propios de la ejecución de M0-T0.4

- **Contradicción del ✅ de T0.4 (reportada al dueño, sin resolver):** el ✅ del maestro pide un guion con "spawn, agarrar, amarrar, conducir", y §0.8 añade "posiciones de paquetes, dinero, ocupación de puestos, cambio de autoridad del bus". Agarrar/amarrar son M3, la economía M5, los asientos M2: hoy solo existe spawn replicado + conducir el circuito + convergencia (D55). Propuesta para el dueño: reescribir el ✅ de T0.4 como "spawn + conducir el circuito + convergencia" y mover lo demás a un ✅ ampliado en M3/M5, donde esas mecánicas existen y el arnés ya tiene los ganchos (`NetMarker`, handshakes, asserts).
- **`EventBus` pendiente (§20):** el maestro lo lista como tercer autoload; ninguna tarea lo necesita todavía. Crearlo cuando un consumidor real lo pida.
- **Interpolación propia de cliente** (buffer ~100 ms): se evalúa en M2 con jugadores reales; en T0.4 la comparación es tras frenar y asentar, donde no aporta.
- **Reconexión a mitad de ruta (§17):** M4.
- **GodotSteam** (transporte detrás de `NetworkBackend._impl`, lobby, voz): M4.
- **macOS:** la corrida del arnés de red en la Mac queda para la sesión obligatoria antes del gate M4 (D42); el guion es GDScript puro y no debería requerir cambios.
- **Límite ENet de conexión acotado en `join_game` (3000–5000 ms):** si M4 necesita tolerar redes más lentas que una LAN, revisar el `set_timeout` del backend.

## Pendientes propios de la ejecución de M1-T1.1

- **Proponer al dueño:** llevar los doce parámetros de sensación del bus (D61) a §8.1 del maestro (hoy su origen figura como "§4.5 / ADR-007" en el esquema).
- **Volcadura recuperable con acción sincronizada** (§4.5): necesita el sistema de acciones cooperativas — M3.
- **Mando (gamepad)** vía Steam Input: M4 (D62 es teclado).
- **Herramienta de medición permanente:** la sonda de medidas del paso 6 era temporal y se borró; si el dueño va a tunear seguido, convertirla en `src/tooling/` permanente (nueva tarea o ADR).
- **`run_demo` con `camera=cabin|chase`:** arg nuevo documentado en README; útil para capturas.

## Cerrados en la ronda 2 de M0-T0.3

- **El impulso de escalón (climb hop) del bus placeholder, eliminado** (revisión 01, r1.1). Lo medido desmiente la descripción de la ronda 1 ("ayuda a subir los baches"): la sonda del revisor midió **cero impulsos dentro del campo de baches** y **uno por vuelta en la esquina de aproximación** (t=24,6 s, (36,1 · 1,13 · −14,2)). La causa real era de trazado: el bus salía del tramo WP9→WP10 hasta 6 m fuera de la línea x = 30, entraba oblicuo a la fila y se clavaba contra la esquina del primer bache; el impulso lo rescataba y reiniciaba el contador de `stuck`, anulando el detector que la propia tarea entregaba. Arreglo: WP8 movido a la línea x = 30, waypoint de aproximación antes del campo, salida norte re-encaminada y campo de baches rehecho (ver entrada siguiente) de modo que no exista cara vertical de ataque. Borrados `_update_climb_hop` y sus tres `@export` (`climb_hop_up_speed`, `climb_hop_fwd_speed`, `climb_wedge_seconds`) junto con `_wedge_time_s` y `_has_moved`; la vuelta se completa sin ningún rescate y un atasco provocado sigue produciendo `stuck` (bus congelado en la demo; pared infranqueable en `test_stuck_emitted_against_unclimbable_wall`). **Nota para el cierre:** D50 en `DECISIONS.md` describe aún el campo viejo (6 baches × 0,15 m cada 3 m) y la ficción del hop; actualizarla al fusionar la ronda 2.
- **Campo de baches rehecho (revisión 01, r1.2): el chasis ya cae entre baches.** Antes: altura constante y = 1,25 m e inclinación máxima 3,3° durante toda la travesía. Ahora: dos mesetas de 1,5 m de alto × 16 m de ancho con entrada rampada a 8° (la pendiente de la rampa grande, que el bus ya sube) y borde de caída vertical, hueco de 9,6 m entre mesetas (> 8 m del bus). El bus entra al campo por la línea x = 30 (x ≈ 30,7 en la entrada, antes hasta 36,2), sube y cae de cada meseta (y oscila entre 1,10 y 3,16 m) y la vuelta termina con `min_upright` 0,9496 (18,4°, lanzamiento oblicuo al iniciar el giro de salida sobre la meseta 2) en vez del 0,96 de la ronda 1 — el mínimo ahora lo produce el campo de baches, no la rampa — sin acercarse al umbral de volcadura (0,5).

## Pendientes propios de la ejecución de M2-T2.1

- **PRIMER PASO OBLIGATORIO de T2.2 (aviso del revisor, sin diagnosticar):** al poner un `CharacterBody3D` de pie sobre el bus, el bus salió despedido (el montaje de la sonda se verificó correcto sobre suelo plano). Es el riesgo #1 de ADR-003: medir y entender la interacción ANTES de escribir el personaje. No asumir que se arregla solo.
- **T2.2 (no empezar en T2.1):** personaje, caminar, entrar/salir, sentarse, conducir desde el asiento. El interior ya tiene posiciones (`Positions`) y la puerta lateral con escalones.
- **T2.3:** agarrar/soltar/amarrar paquetes; los anclajes (`Restraints`, 12) esperan el `restraint`.
- **Paneles operables y sistemas del bus (§4.2):** M3+.
- **Los escalones de la puerta** no alcanzan el suelo (dos risers de 0,25 desde el piso; el suelo queda más bajo con la suspensión cargada): cuando T2.2 haga el abordaje, decidir si hace falta un tercer escalón o escalón plegable.
- **Arte/ventanas reales del bus** (el parabrisas es un hueco greybox): M8.

## Pendientes propios de la ejecución de M2-T2.2

- **DECISIÓN DEL DUEÑO (planteada por r1.1 de T1.1, sin resolver):** §4.5 del maestro dice que el bus hace 0–60 km/h en unos 5 s; el juego hace 6,93 s y el campo de tuning ya no miente (es fuerza, `bus_traction_force_n`). Decidir: (a) aceptar 6,93 s y corregir §4.5 del maestro, o (b) dejar pendiente calibrar la tracción para acercarse a 5 s (cambia la sensación que el gate ya aprobó). No bloquea M2.

## Pendientes propios de la ejecución de M2-T2.2

- **T2.3 (no tocado en T2.2):** agarrar, soltar, lanzar y amarrar paquetes. El gate duro de M2 (dos instancias, red real) es suyo. Los 12 anclajes (`Restraints`) y las 6 posiciones esperan.
- **Red y autoridad del conductor (M4):** el asiento deja el gancho (`Seat.occupied`/`vacated`); la autoridad del bus pasa al peer sentado (ADR-006). La tripulante no está replicada (es de un jugador en T2.2); el reparentado para la red queda como mecanismo disponible (D75 registró que en local no se usa por la doble herencia medida).
- **Interacción personaje↔bus al ENTRAR EN CONTACTO con el chasis exterior:** la medida del revisor (el bus despedido al spawnar un cuerpo encima) quedó explicada por la regla "posicionar antes de entrar al árbol"; si T2.2+ muestra otra interacción, medir antes de mitigar (ADR-003).
- **La deriva de la tripulante a bordo (~0,30 m por minuto sobre los saltos):** comportamiento físico honesto (te tambaleas); si el dueño lo quiere más pegado, es un ajuste de fricción/snap, no de red. Registrado, no bloquea.
- **Cámara de cabina vs. cuerpo:** al sentarse la cápsula se oculta (D76); cuando haya arte (M8) la primera persona querrá manos/cuerpo (§9.1).

## Cerrados en M2-T2.1 (paso 0)

- **r1.1 de T1.1 (el campo de aceleración mentía):** `bus_accel_0_60_kmh_s` renombrado a `bus_traction_force_n` (10 000 N) — el nombre dice ahora lo que el código aplica; el 0–60 real medido (6,93 s) queda anotado en el esquema. Se eligió renombrar y no calibrar porque el gate del dueño aprobó la sensación con la aceleración actual; cumplir el nombre acelerando más habría cambiado lo aprobado.

## Cerrados en las rondas 2 y 3 de M0-T0.1

- **Borrado de `addons/gdUnit4/test/`** (M2/M3 de la revisión 01): ejecutado en la ronda 3 tras R12=SÍ (2026-09-08). 559 archivos eliminados con `git rm -r`; la caché global ya no lista `res://addons/gdUnit4/test/` (conteo 0) y no queda ningún `.scn` en el índice. Registrado en D32, `CREDITS.md` y la evidencia 08.
- **17 `.gd` de `addons/gdUnit4/test/` sin `.uid`**: resuelto/irrelevante — esos archivos ya no existen en el árbol tras el borrado autorizado de `test/` (ronda 3).
- **m1 RESUELTO por D40:** gdUnit4 headless corre sin `-d` ni `--remote-debug tcp://127.0.0.1:0`; desaparecen las dos líneas `ERROR` por el puerto 0 y los errores de script siguen saliendo con backtrace GDScript completo y código 105 (experimento del 2026-09-08).
- **`reports/` reimportado por Godot en cada `--import`** (m2): resuelto — el arnés crea `reports/.gdignore` si no existe antes de correr.
- **Caché global vacía tras `--import`** (transitorio observado en la ronda 2, anexo de la evidencia 04; causa no determinada): `.godot/global_script_class_cache.cfg` quedó una vez con 0 líneas tras las dos pasadas del arnés y el runner falló con código 1 ("Could not find type GdUnitTestCIRunner"); un `--import` manual la regeneró (2801 líneas). Resuelto en la ronda 3 (m-2.2): el arnés exige caché existente, no vacía y con `GdUnitTestCIRunner`/`GdUnitTestSuite`, con tercera pasada de `--import` antes de fallar.
