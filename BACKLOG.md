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

## Pendientes (copiados del plan M0-T0.1, sección 9)

- **M4:** `export_presets.cfg` con exclusión `addons/gdUnit4/*` (respetar mayúsculas). Según la doc de 4.7, `--export-release` **no** implica `--import`: correr `--import` explícito antes. Export templates 4.7.2 = `Godot_v4.7.2-stable_export_templates.tpz`, ~1,41 GB, verificar con `SHA512-SUMS.txt`.
- **M4:** GodotSteam movió su repo a Codeberg (GitHub archivado el 2026-09-04). GDExtension actual v4.22.1-gde, Godot 4.4+, Steamworks 1.65. Confirma la regla "solo el oficial de godotsteam.com".
- **M2 / ADR-003:** bug abierto de Godot #102763: `CharacterBody3D` se desliza sobre `AnimatableBody3D` en rotación, en ambos motores de física, fix pendiente sin milestone 4.7. Afecta la plataforma móvil del bus.
- **T0.4:** no existe `--user-data-dir` en 4.7. Instancias paralelas necesitan `--path` propio, `--log-file` propio y, para operaciones de editor, una copia del ejecutable con archivo `_sc_` al lado (modo autocontenido). Considerar `application/run/flush_stdout_on_print=true` y `debug/file_logging/enable_file_logging=true` cuando el agente necesite leer logs de instancias que crashean.
- **Headless no entrega InputEvents:** cualquier test que simule input necesita sesión con ventana. Diseñar los tests de gameplay (T0.3+) como simulación de lógica, no de input.
- Re-verificar gdUnit4 cuando salga **v6.2.2** (si añade 4.7.2 a la tabla de compatibilidad).
- 4.8-dev4 prohíbe strings como comentarios en GDScript: lint preventivo si algún día se salta a 4.8.
- **Correcciones al maestro para proponer al dueño:** §21 comando de gdUnit4; §15/D13 "Vulkan/MoltenVK" → backend por plataforma (D31); §0.2/T0.1 "`run_tests` pasa" → exigir conteo mínimo; §20 añadir `docs/`; §0.2, §20 y T0.1 dan por hecho un puente MCP y el proyecto decidió ninguno en M0 (D30/ADR-009); T0.1 'en ambas máquinas' → 'en Windows; Mac antes de M4' (D42).

## Pendientes propios de la ejecución de M0-T0.1 (M5 de la revisión 01)

- **Corrección del plan/maestro por formato de versión:** `Engine.get_version_info()["string"]` devuelve `4.7.2-stable (official)` (guion y paréntesis); el formato con puntos (`4.7.2.stable`) es solo el de `godot --version`. Defecto del plan v1.0 nº 1, corregido en el plan v1.1; queda como referencia para cualquier documento que cite el formato.
- **Al subir de parche 4.7.x** (ADR-000) hay que tocar cuatro archivos: `tests/smoke_test.gd`, `tools/run_tests.ps1`, `tools/run_tests.sh`, `README.md` (m8 de la revisión 01; la lista también está en `AGENTS.md` y en `README.md`).
- **Cierre de M0-T0.1 (solo el dueño, revisión 02 "Qué hace falta para cerrar"; actualizado por D42, 2026-09-09):** la corrida de `bash tools/run_tests.sh` en la Mac con el mismo hash del arnés queda **diferida por D42 hasta antes del gate M4** (red real Mac + Windows, D13) — ya no bloquea T0.1, que se acepta con `run_tests` verde solo en Windows. Residuo declarado: el arreglo de BOM POSIX de `run_tests.sh` (m-2.3) solo está probado bajo Git Bash; su prueba real en BSD sed queda para esa corrida. Siguen pendientes del dueño: crear el remoto con Git LFS habilitado + primer push, y comprobar el dock de gdUnit4 en el editor con ventana (revisión 01, ítem M4).

## Cerrados en las rondas 2 y 3 de M0-T0.1

- **Borrado de `addons/gdUnit4/test/`** (M2/M3 de la revisión 01): ejecutado en la ronda 3 tras R12=SÍ (2026-09-08). 559 archivos eliminados con `git rm -r`; la caché global ya no lista `res://addons/gdUnit4/test/` (conteo 0) y no queda ningún `.scn` en el índice. Registrado en D32, `CREDITS.md` y la evidencia 08.
- **17 `.gd` de `addons/gdUnit4/test/` sin `.uid`**: resuelto/irrelevante — esos archivos ya no existen en el árbol tras el borrado autorizado de `test/` (ronda 3).
- **m1 RESUELTO por D40:** gdUnit4 headless corre sin `-d` ni `--remote-debug tcp://127.0.0.1:0`; desaparecen las dos líneas `ERROR` por el puerto 0 y los errores de script siguen saliendo con backtrace GDScript completo y código 105 (experimento del 2026-09-08).
- **`reports/` reimportado por Godot en cada `--import`** (m2): resuelto — el arnés crea `reports/.gdignore` si no existe antes de correr.
- **Caché global vacía tras `--import`** (transitorio observado en la ronda 2, anexo de la evidencia 04; causa no determinada): `.godot/global_script_class_cache.cfg` quedó una vez con 0 líneas tras las dos pasadas del arnés y el runner falló con código 1 ("Could not find type GdUnitTestCIRunner"); un `--import` manual la regeneró (2801 líneas). Resuelto en la ronda 3 (m-2.2): el arnés exige caché existente, no vacía y con `GdUnitTestCIRunner`/`GdUnitTestSuite`, con tercera pasada de `--import` antes de fallar.
