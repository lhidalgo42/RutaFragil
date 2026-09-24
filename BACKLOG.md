# BACKLOG.md — Ruta Frágil

Todo pendiente del proyecto vive aquí (R10: sin TODOs silenciosos en el código).

## M-ART — pendientes propios del pipeline de arte (2026-09-21)

- **Generación del paquete desbloqueada, 2026-09-24 UTC (23 en Chile).** `--no-upsample` pasó el decode (2.879.997 vértices / 5.772.178 caras), pero `RemeshMesh` agotó VRAM a 768 y 512. Con `--remesh-resolution 256` terminó reutilizando la forma en caché: prompt `ed642bbd-7513-4867-ad9b-eb6d0ce36253`, `docs/referencias/package_raw_v1.glb` y metadatos JSON; 19.996 tris, 2.910.172 bytes. VRAM posterior: 16,26 GB libres y cola vacía; no reprodujo la retención histórica. GLB crudo: 3/8; `--texture 1024` no cambia la resolución fija del normal bake (2048). Fuente cruda conservada sin cambios. Los reportes anteriores de `reports/m_art_remesh/` ya no están: `run_tests` limpia `reports/`; evidencia vigente en `docs/evidencia/M-ART/limpieza/` e `integracion/` (copiada desde `reports/` el 2026-09-24, porque el arnés borra esa carpeta).

- **Limpieza Blender verificada; pivote base confirmado por el dueño.** `assets/models/package_clean_v1.glb`: 800 tris, bbox X/Y/Z 0,400 × 0,319 × 0,362 m, base Y≈0, un material y tres texturas ≤1024²; `python tools/glb_check.py assets/models/package_clean_v1.glb --kind package --pivot base`: 8/8 con el validador de entonces. **Corrección 2026-09-24:** el validador contaba materiales, no texturas; con el punto 4 corregido el paquete da **7/8** (tres texturas donde §10.1 pide una). Decisión abierta del dueño. `tools/blender_cleanup.py --outer-shell` retira cuatro capas interiores invertidas (13.774 caras) antes de decimar la exterior (6.222 caras). Opción explícita para props cerrados tipo caja; exige exterior cerrado/manifold, orientación opuesta y contención estricta en su bbox. No es prueba de contención para geometría cóncava ni sirve para assets huecos: requieren retopología autorada. `tools/blender_cleanup_test.py` reproduce el paquete en temporal y comprueba SHA-256 de la fuente. Comando completo y diagnóstico en `docs/evidencia/M-ART/limpieza/summary.md`.
- **Integración autorizada y verificada, 2026-09-24 UTC:** `src/cargo/package.tscn` instancia `package_clean_v1.glb` como visual en Y=-0,2 m: base alineada con la caja D81, sin tocar colisión, masa ni capas físicas. Prueba de integración roja sobre greybox (salida 100, fallo esperado por no instanciar el GLB); verde 2/2 sobre el modelo, incluida caja autorada e inclusión del mesh. Suite completa 257/257 y red 1 host + 3 clientes, salida 0; arranque headless sin errores y checklist 8/8 con el validador de entonces (7/8 tras corregir el punto 4). La suite conserva los mensajes preexistentes de `CameraArbiter`. Evidencia en `docs/evidencia/M-ART/integracion/`; evidencia anterior de limpieza preservada en `docs/evidencia/M-ART/limpieza/`.
- **Provisional eliminado con autorización explícita del dueño (R12):** retirados `assets/models/package.glb`, su `.import`, `package_tex_0.png`, `package_tex_1.png`, `package_tex_2.png` y sus `.import` (8 archivos). Lista exacta en `docs/evidencia/M-ART/integracion/removed.log`. Fuente cruda, GLB válido y sus texturas extraídas `package_clean_v1_tex_*.png` conservados.

- **La GPU del servidor queda retenida (~15 GB fuera de torch) después de cada corrida de TRELLIS.2, exitosa o fallida.** Medido tres veces el 2026-09-21: tras la malla del furgón (éxito) 865 MB libres; tras dos OOM del paquete, 869 MB. `system_stats` muestra torch con 64 MB; el resto lo tiene otro dueño. `POST /free` e `/interrupt` responden 200 y no liberan nada. **Reiniciar el contenedor NO alcanza:** tras el primer reinicio el proceso era nuevo (historial vacío, torch 0 MB) y la GPU seguía en 967 MB libres; el dueño la liberó por otra vía en el host (por documentar: qué proceso tenía la memoria según `nvidia-smi --query-compute-apps`). Hipótesis a verificar en el host: proceso hijo/zombi del contenedor anterior que sobrevive al restart, o un worker de las extensiones de malla fuera del proceso principal. Regla operativa: correr TRELLIS.2 al final de la sesión; después de cada corrida, revisar `nvidia-smi` en el host antes de generar otra cosa.
- **`VaeDecodeShapeTrellis` (nodo 92) se queda sin memoria con el paquete y no con el furgón**, a 1536 (9,9 GB asignados + 6,1 pedidos) y a 1024 (12,6 + 2,4). La memoria del decode escala con los voxels ocupados, y una caja llena el volumen mientras el furgón es delgado. `comfy_mesh.py --no-upsample` decodifica desde el latente base (nodo 18) saltando la etapa de 1024–2048 voxels: para un prop de ≤800 tris sobra. Verificado el 2026-09-24 UTC con remallado 256; conservar como antecedente de los límites de VRAM, no como bloqueo actual.
- **Paso 4 de M-ART (paquete, DA5): revisión visual aceptada por el dueño, 2026-09-24 UTC.** Tras probarlo en el juego indicó «se ve bastante bien, sigamos con la siguetne fase del juego». Generación, limpieza e integración verificadas; cuatro paquetes del Playground usan el GLB validado. Evidencia: `docs/evidencia/M-ART/integracion/playground_package.png`, `package_godot.png`, `reference_vs_godot.png` y `summary.md`. La captura interior conserva la iluminación real (oscura). Esta aceptación corresponde al paquete integrado; no aprueba el gate M8 ni autoriza commit o merge.
- **`tools/glb_check.py` no valida el punto 3 (colisión autorada) ni el 6 (board) ni el 7 (CREDITS):** por diseño (DA6). `tests/cargo/package_authored_collision_test.gd` verifica el GLB integrado, caja autorada de 0,4 m inmóvil, ausencia de colisión en el subárbol visual y encaje del mesh (2/2). La apariencia del paquete fue aceptada por el dueño; los tests no certifican licencias ni el gate M8.
- **Texturas del paquete embebidas en el GLB, no extraídas** (2026-09-24): `assets/models/package_clean_v1.glb.import` pasa a `gltf/embedded_image_handling=3`. Con el valor por defecto (1) cada importación extrae tres PNG junto al modelo, y versionarlos duplica 1,7 MB en LFS, que en GitHub es permanente. Verificado en un worktree limpio: sin los PNG y con `=3`, `--import` no los recrea y el material toma albedo y normal desde `package_clean_v1.glb::ImageTexture_*`. Los tres `package_clean_v1_tex_*.png` y sus `.import` siguen en el árbol del dueño, sin versionar: borrarlos (R12) está pendiente de su confirmación.
- **Aviso «Built with DINOv3» en los créditos del juego** (licencia de Meta, `CREDITS.md`): pendiente de la pantalla de créditos, que no existe. Anotar en la tarea que la cree.

## M2-GATE — pendientes y antecedentes hasta ronda 6

- **M4, interacción física de tripulantes con el bus:** caminar perturba la
  trayectoria del bus de forma reproducible. Comparación por índice de 3600
  poses en las grabaciones de pie/caminando: distancia p95 **3,533801 m** y
  máxima **3,840599 m** (`03_raw/r3b_physics_frame_summary.json`, observador
  postnodos prioridad física 1000; p95 previo 3,535858 con otra fase). No son
  «0,25 m por vuelta»; esa lectura del checksum con signo se retira. Al diseñar
  M4 considerar que distinta colocación/marcha de tripulantes puede hacer
  divergir dos simulaciones aun con motor determinista. No se implementa aquí
  autoridad de bus al conductor ni reconciliación de M4.

- **g2.1 retirado (revisión 03, 2026-09-16):** la comparación mezclaba puntos
  de muestreo. Test eliminado por instrucción del dueño, sin ajustar umbral;
  186 tests en fase 0. Se conserva evidencia 12 y las fuentes de ambas sondas.
  D95 exige ahora observador independiente después de los nodos, prioridad
  física 1000, idéntico en ambas instancias y declarado en todas las tablas.
- **Fase 0 cerrada:** 186/186 tests, código0; sondas postnodos 0/0.
- **M2-GATE, dos fallos válidos; tercer intento intacto:** corridas 2 y 4
  conservan el fallo bajo D95 v5: `hull_exit_ticks` anfitrión/cliente
  **0/16.784** y **0/14.494**, con los límites exactos de
  `BusInterior.is_inside_local`. El apoyo ya no tiene umbral. El p99
  histórico sin filtrar es descriptivo: falta contacto de carga por tick
  para reconstruir el filtro v5. Persisten máximos locales de penetración
  >5 cm; las rachas >3 cm no se reconstruyen con precisión en esos históricos.
  Los FPS de corrida 2 no se juzgan por VSync/cap; corrida 4 conserva
  FPS p1 146,714/175,778 sin límite. Véanse sus tablas reemitidas.
- **Carga, defectos corregidos con regresión roja/verde:** colocación de
  release dentro de cápsula, velocidad cinemática ficticia mano→suelo y caja
  FREE inmóvil en mundo hasta su primera foto. Evidencia13/14, Godot4.7.2.
  No equivalen a haber aprobado D95 v5: el experimento posterior de 120 s
  dio apoyo cliente 87,652778 % y 44 ciclos, cifras descriptivas; no es la
  precondición de 300 s y el apoyo ya no tiene umbral.
- **Ronda 5 detenida; continuación acotada autorizada por D98:** experimento
  de 300 s sobre `25c7a72`: apoyo anfitrión 99,983333 %/cliente 27,333333 %,
  `hull_exit_ticks` **0/13.066**, cliente fuera desde 4935 y empujón desde
  4923 sin recuperar durante al menos 13.078 ticks. No consumió el tercer
  gate. Evidencia 16–18. La liberación en fase física corrige 0,308333 m
  artificiales; el acarreo explícito ensayado se rechazó por introducir
  aire en baches. D98 autoriza una sola ronda adicional: corregir inercia
  aérea y medir la precondición v5 de 300 s. Si no pasa, parar; el revisor
  redacta el plan B con D98. No implementar B ni inmunidad frente a carga.
- **D98, inercia aérea pendiente de verificación:** medir antes/después
  salto a 80 km/h de pie y caminando (residuo respecto al paseo ≤0,30 m),
  salto sobre baches y empujón de caja lenta: cero salidas; recuperación
  del empujón ≤45 ticks; controles sin carga de pie/caminando sobre baches
  conservan cero aire con presión −0,5. Documentar `platform_on_leave`.
  Afecta también a single; no darlo por resuelto con datos solo de red.
- **M3, empujón simétrico (D98):** impulso a la tripulante por contacto con
  carga rígida también en anfitrión y single. La asimetría actual con las
  réplicas cinemáticas se acepta y se reporta por instancia; no se corrige
  dentro de este gate.
- **Tope de corrección de réplica, condicionado al gate humano (D98):**
  si el dueño considera injustos los empujones por artefactos, medir y fijar
  un límite de velocidad de corrección relativo al bus. No hay valor
  autorizado ni se elimina la colisión. Mientras tanto, estos empujones
  se cuentan junto con los físicos.
- **Cobertura de penetración en transiciones:** al aplicar solicitudes en
  física, Package_2/3 pueden estar FREE con CollisionShape3D aún disabled
  hasta su set_deferred. El observador marca instrumentación ausente, pero
  registra profundidad0 y corta la racha; no guarda tick/shape de esa falta.
  Histograma y rachas de18 son observados con cobertura incompleta, no
  certifican ausencia de penetración. Registrar muestras desconocidas y
  su tick en una tarea futura. La ronda 6 deja esta deuda registrada sin
  trabajarla; no presentar cobertura incompleta como ausencia de penetración.
- **Penetración dinámica pendiente:** en corrida4, Package_3 del anfitrión
  alcanza racha4391 ticks y profundidad máxima0,025533 m. Revisión 05 retira esa racha de asentamiento: con umbral >3 cm
  queda exactamente en cero. Falta reconstrucción fina histórica para
  Package_2; las nuevas corridas conservan profundidades por tick.
- **Jugabilidad humana pendiente:** inspección nativa120 s conserva apoyo y
  muestra cajas/remota, pero los taps no verifican un ciclo manual ni input
  sostenido. No aprobar gate ni avanzar aM3 por resultados headless.
- **Red futura:** fuera de alcance internet/Steam, reconexión y cambio de
  autoridad del bus; error de carga histórico de corrida2 conservado, sin
  atribución causal completa. Conversión de velocidad exterior puede retener
  residuo si el bus acelera entre foto y recepción. No se implementa M4.

- **M3, respuesta y validación de liberaciones:** `drop()`/`throw()` fallan
  silenciosamente cuando no hay volumen libre. Añadir respuesta al jugador.
  El anfitrión comprueba `fits` contra su réplica de tripulante, que puede
  estar desplazada ~1 m; validar geometría en el marco del bus con la pose
  enviada por el cliente. Deuda registrada por revisión 05; no se implementa.
- **Interpretación de error remoto (corrida4):** a 22 m/s, el p95 de bus de 1,87 m
  equivale aproximadamente a 85 ms de retardo de interpolación. Tripulante
  p95 ~1 m incluye su propia interpolación (a esa velocidad serían ~45 ms).
  Es comparación al mismo UTC sin compensar retardo, no error residual tras
  compensarlo; no se ha separado cuantitativamente todo el residuo.
- **Fixture anterior a M2-GATE:** `seat_test.gd` emite
  `ERROR: CameraArbiter: no Camera3D in group 'eye_camera'` en cada arnés.
  Limpiar el fixture en otra tarea; no se oculta aquí ni cambia el código 0.

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
  - **GATE M2: cierre humano registrado el 2026-09-17 (D97 — CUMPLIDA).** El dueño probó la instancia cliente mientras el anfitrión conducía y aprobó el acarreo. Excepción documentada: cerró antes de 300 s y aceptó el gate igualmente. ADR-003 opción A validada por esa decisión humana; el antiguo estado PENDIENTE de este backlog estaba desactualizado. No se vuelve a aprobar el gate desde tests.
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

## Pendientes propios de la ejecución de M2-GATE (paso 0)

- **Descubrimiento de gdUnit en clones frescos:** gdUnit ha omitido tres veces el último test de una suite al correr en un clon fresco (revisiones 04/05 de M2-T2.2 y 02 de M2-T2.3); causa desconocida. Desde el paso 0 (r2.1) el arnés afirma el conteo exacto de tests (`EXPECTED_TESTS` en `tools/run_tests.ps1` y `tools/run_tests.sh`, actualizada en el mismo commit que añada o quite tests), así que una omisión silenciosa rompe la corrida en vez de pasar. Investigar la causa raíz cuando vuelva a aparecer (¿import incompleto en la primera pasada?, ¿caché de clases?).

## Pendientes propios de la ejecución de M2-T2.2 (rondas 2–3)

- **`player_mouse_sensitivity` es una preferencia del jugador, no balance de juego** (nota del dueño, r3): en `TuningTable` está bien hoy, pero un mod podría cambiársela al jugador; cuando exista un menú de ajustes, ese campo se muda fuera del alcance de mods.
- **Resuelto: F1 al salir de demo habilitaba el bus estando a pie** (semántica heredada de T1.1/D71): `set_demo_mode` condiciona el input a `_crew_seated()` y lo cubre `test_leaving_the_demo_follows_the_crew_state` en `tests/biomes/playground/playground_scene_test.gd`.
- **El DisplayServer headless no retiene `Input.mouse_mode`** (medido 2026-09-14): en tests, la verdad de la captura la posee la app (`CrewInput.is_pointer_captured()`), nunca el flag del motor.
- **Re-guardados de escena fuera de banda (editor) pueden corromper silenciosamente** (2026-09-14): una reescritura de `playground.tscn` dejó el bus spawneando a y=14,08 y borró `seat_marker` del Seat; pasó desapercibida porque la demo aterriza y corre igual. Pines añadidos en `playground_scene_test` (spawn del bus < 3 m, `seat_marker` no nulo). El pendiente de waypoints también está resuelto: `test_circuit_waypoints_match_the_authored_positions` comprueba los 17 marcadores.
- **`seat_marker` hand-escrito sin `../` no resolvía en runtime** (mismo incidente): `NodePath("Bus/...")` se resuelve relativo al propio `Seat`, no a la raíz; corregido a `../Bus/BusInterior/Positions/driver` y pineado por el test anterior. En T2.2 r1 ocupar el asiento nunca teletransportó al volante y nadie lo notó (el dueño se sentó estando ya junto a él).

## Pendientes propios de la ejecución de M2-T2.3 (paso 1)

- **120 Hz en ruta: medición no concluyente, número sin explicar** (2026-09-14): a 120 Hz los despegues de las cajas llegaron a 22,36 m/s (peor que a 60 Hz) con el bus idéntico en ambos modos; no es física creíble y no sabemos por qué. Si alguien retome la idea, medir de nuevo con el amortiguador puesto.
- **El daño por impacto de carga (§5.3, umbrales 2–3 m/s) no existe aún**: la frenada (d) del paso 1 verifica que la carga suelta PUEDE deslizar y golpear a esa velocidad; el daño en sí es M3.
- **Los anclajes en la tapa bloquean el contacto directo con la carga amarrada** (medido por el agente C, 2026-09-15): la cara del rack (x=0,6) tapa a la tripulante antes de que alcance la cara de la caja (x=0,675). Si tocar la carga amarrada ha de ser posible (M3), los anclajes deberían salir hacia el pasillo (x ≈ 0,45), no ir a la tapa. Decisión del dueño cuando llegue M3.
- **`Positions/shelf_*` tienen el mismo defecto que los anclajes viejos** (dentro del volumen del rack): al poner arte o spawns sobre estantes en M3, revisar esos marcadores.
- **Acarreo sobre carga amarrada (KINEMATIC)**: medido que funciona (deriva 0,185 m en la sonda aislada), pero reparent+KINEMATIC duplica el movimiento (88,5 m/vuelta) y STATIC no acarrea (22,2 m). Sin consumidor dentro del casco hoy (el techo tapa subirse a una caja: 1,2 + 1,75 > 1,30). Si M3/M4 lo necesita (carga en el techo del bus), la opción medida es el mecanismo del amortiguador de plataforma, no reparent.
- **Prioridad de E en zona rica** (asiento + paquetes juntos): resuelta con la regla de la retícula (lo más alineado con la mirada gana). A revisar en playtest: si apuntar al asiento para conducir se siente natural con paquetes cerca.
- **El gate duro de M2 (dos instancias) es `M2-GATE`** (D88): su propio plan, inmediatamente después de esta tarea.

## Pendientes propios de la ejecución de M2-T2.3 (paso 1)

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
