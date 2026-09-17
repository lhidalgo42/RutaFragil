# M2-GATE — contrato de fase 0; actualización D95 v5 / D98

**Origen: contrato de fase 0, resolución de ronda 3b.** g2.1 fue retirado por
`docs/revisiones/M2-GATE_revision_03.md`; su test se elimina y el conteo vuelve
a 186. Cierre verificado: arnés -SkipNet código 0, 186/186; dos sondas con
muestreo postnodos código 0/0 (evidencia 03). Las
interfaces de abajo fijan A/B y la integración; no aprueban el gate humano.

Base: `98dccc1`, rama `m2/gate-two-instances`. Encargo del dueño de esta
sesión, revisión 02 y D91–D97 del plan. Este documento materializa las firmas:
los documentos anteriores las mencionan, pero no contienen su definición.
No crea un ADR ni da por aprobado el gate humano.

**Actualización vigente, 2026-09-17:** D95 v5/D98 del
[plan](../../planes/M2-GATE_plan.md#4-decisiones-de-esta-tarea), tras
[revisión 06](../../revisiones/M2-GATE_revision_06.md) y decisión del dueño.
Las firmas históricas se conservan; la sección de métricas incorpora el
criterio vigente. Esto no certifica su implementación ni una corrida nueva.

## Discrepancias declaradas al cerrar ronda 3b

- El prompt de relevo Codex está sin seguimiento al empezar; se conserva.
- Las instrucciones viejas del paso 1 (parar, deriva y máximo) están sustituidas
  por la revisión 02 y el encargo actual: continuar, juzgar p99 a 1,5×.
- D91–D97 viven en el plan; el registro DECISIONS termina en D90.
- DoorTransit forma parte del arreglo explícito g2.9 aunque falta en la lista
  abreviada de archivos. No se modifica ninguna escena.
- El predicado solicitado excluye al cliente de crear carga; la frase que
  dice que crearía cuatro cajas no concuerda. Se fija cargo_spawn=false en
  el test de todos modos para que el fixture declare su intención.
- g2.6 de revisión 02 y g2.14 del prompt son el mismo checksum inválido.

## Nodos, identidad y autoridad

`Playground/Crews/Crew_<peer_id>`: escena crew_member.tscn, creada por
MultiplayerSpawner; autoridad del peer. Retirar la tripulante autorada en
roles de red, conservarla en single. Posición y autoridad antes de add_child.

`Playground/NetCrewSync`: nodo estable de réplica y spawner de tripulantes.
Fotos de global_transform a 30 Hz; interpolación de remotas, capa 3,
sin move_and_slide remoto. Una cámara current por instancia.

`Playground/Cargo/<package_name>`: nombres legibles únicos; grupo package.
Una caja amarrada puede cambiar de padre, por eso los RPC no viven en ella.
`Playground/NetCargoSync`: nodo estable, autoridad anfitrión. Fotos a 20 Hz.
Clientes congelados cinemáticos; solo la autoridad simula una caja libre.
En HELD autoridad del sostenedor; al liberar vuelve al anfitrión.

`Playground/NetBusSync`: fotos a 30 Hz, interpolación a frecuencia de física.
La recepción almacena fotos. Al cerrar fase 0, physics_frame era el escritor;
la integración posterior elige nodo físico a −100 y carga a −90, documentado
en 04_timing_resolution.md. No hay requisito de ventaja física (g2.1 retirado).

## RPC de carga (fiables; emisor obtenido de la conexión)

```gdscript
request_hold(package_name: StringName) -> void
request_release(package_name: StringName, at_bus_local: Transform3D,
    velocity_bus_local: Vector3) -> void
request_strap(package_name: StringName, anchor_name: StringName) -> void
request_unstrap(package_name: StringName) -> void
```

Wrappers locales `send_hold`, `send_strap`, `send_unstrap` con los mismos
argumentos. `send_release(package_name, at_world, velocity_world)` recibe
pose/velocidad mundial del gameplay y convierte al marco relativo descrito
abajo antes del RPC. Host llama al validador; cliente usa rpc_id(1).
Los wrappers solo solicitan: la confirmación replicada actualiza CrewHands.held
del sostenedor correcto y limpia las manos anteriores. Enviar no es conceder.
Resolver paquete por grupo package + nombre y anclaje por restraint_anchor
+ nombre. Validar existencia, estado, sostenedor, mano vacía, alcance y
anclaje libre. La posición al soltar es la transformada en el marco del bus.
La velocidad es RELATIVA al punto del bus expresada en sus ejes: el anfitrión
reconstruye R*v_rel + v_bus + omega_bus × offset. Nunca transportar una
velocidad mundial de una foto antigua como si fuera la velocidad relativa.

## Aplicación replicada de estado

```gdscript
apply_replicated_state(state: Restraint, at_bus_local: Transform3D,
    velocity_bus_local: Vector3, anchor_name: StringName,
    holder_peer_id: int) -> void
```

- Cualquier estado → HELD: liberar anclaje anterior, restaurar padre Cargo,
  asignar el sostenedor indicado; congelar y desactivar colisión. Si la
  tripulante aún no apareció, retener el peer y reintentar. No usar la primera.
- Cualquier estado → STRAPPED: liberar ocupación previa si cambia, limpiar
  sostenedor, ocupar anclaje, posicionar antes de reparentar al bus, congelar.
- Cualquier estado → FREE, incluido STRAPPED → FREE: liberar anclaje y mano,
  restaurar Cargo, colocar antes de activar colisión. Solo el anfitrión
  descongela; clientes mantienen réplica cinemática.
- Repetir un estado es idempotente: no duplicar ocupaciones, transferencias
  ni señales. Cambiar sostenedor/anclaje dentro de un estado aplica el cambio.
- Estado y autoridad se difunden juntos, antes de aceptar fotos del nuevo
  dueño. Fotos HELD solo aceptadas desde el sostenedor vigente.

| Transición | Aplicación local confirmada |
|---|---|
| FREE → FREE | Actualizar pose; autoridad anfitrión, física solo en anfitrión. |
| FREE → HELD | Congelar, quitar colisión, asignar holder y autoridad de su peer. |
| FREE → STRAPPED | Congelar, ocupar ancla y reparentar al bus. |
| HELD → FREE | Limpiar mano, restaurar Cargo y velocidad relativa, devolver autoridad. |
| HELD → HELD | Actualizar pose; si cambia holder limpiar mano anterior y reasignar. |
| HELD → STRAPPED | Limpiar mano, ocupar ancla y reparentar; estado replicado congelado. |
| STRAPPED → FREE | Desocupar ancla, restaurar Cargo y aplicar pose/velocidad sin pasar por HELD. |
| STRAPPED → HELD | Desocupar ancla, restaurar Cargo, asignar mano/peer indicado. |
| STRAPPED → STRAPPED | Actualizar ancla si cambió; sin duplicar ocupación ni señales. |

## Las once búsquedas

| Lugar | Dueño de la referencia |
|---|---|
| Playground: seated y camera_mode | Tripulante local (2) |
| CrewHands: crew y eye | Su propio padre y ojo descendiente (2) |
| CrewInput: crew, eye, tap y hands | Local y sus descendientes (4) |
| DoorTransit: crew | Local; reintento tras aparición (1) |
| CameraArbiter: seleccionar | Ojo local o cámara compartida del bus (1) |
| CameraArbiter: apagar | Todas las cámaras restantes de los tres grupos (1) |

NetAuthority.local_crew(tree), crew_for_peer(tree, peer), scoped_eye(member)
centralizan las búsquedas. Referencias nulas/retiradas se reintentan sin emitir
errores durante la llegada del spawner. Input y manos solo controlan la local.

## Métricas y validez de cada iteración

Muestreo D95/revisión 03: nodo dedicado que SOLO LEE, `_physics_process`,
`process_physics_priority=1000` y `process_priority=1000`, después de todos
los escritores y del movimiento. Todas las filas y ambos peers usan ese
mismo punto. JSON: `sampling_phase="after_all_node_physics"`, con ambas
prioridades declaradas. Las tablas lo declaran; no se mezclan fases históricas.

Por instancia: `metrics_version=5`, ticks, duración medida, peer, cámaras
activas mín/máx, ticks de simulación de carga sin autoridad, deriva por eje
(sin umbral), penetración máxima/racha y exclusión de puertas.
La primera fila es `hull_exit_ticks`: contar cada tick en que la posición
de la tripulante local, en el marco del bus, no cumple
`BusInterior.is_inside_local`. Límites inclusivos: `abs(x) <= 1.15`,
`-0.65 <= y <= 1.30`, `-3.8 <= z <= 3.8`. No añadir tolerancia ni sustituir
este volumen por la prueba de penetración.

El apoyo reconoce al bus, no al suelo del Playground. Reportar porcentaje,
`off_bus_support_ticks` y cada pérdida con recuperación o estado abierto;
el apoyo no tiene umbral. Cada pérdida con contacto de carga en cualquiera
de los tres ticks anteriores es un empujón. Reportar
`pushes {count,max_duration_ticks,max_local_displacement_m,open_count}`
y cada evento con duración, desplazamiento local y recuperación.
La duración de un evento abierto es lo observado hasta el cierre, no una
duración final conocida. Los empujones por corrección de réplica también
cuentan; D98 acepta la asimetría entre instancias.

`slip {p95_m,p99_m,p999_m,max_m,samples}` contiene exclusivamente los ticks
con apoyo y sin contacto de carga en los tres ticks anteriores.
`slip_raw` conserva los mismos estadísticos sin filtrar como descriptivos.
Registrar cobertura y contactos por tick para permitir recalcular el filtro;
una muestra desconocida no equivale a ausencia de contacto. Los históricos
sin ese dato no admiten el juicio de p99 v5, aunque conserven otros motivos
de fallo comprobados.

`bus_remote_error {p95_m,max_m,p95_deg,max_deg}`, `crew_remote_error` y
`cargo_remote_error`: comparación temporal explícita con la traza de la
autoridad. Registrar tiempo por muestra, pose y entidad; comparar poses
del mismo instante, interpolando las muestras que lo encierran. Reportar
muestras emparejadas/no emparejadas. Anotar junto a los errores la distancia
correspondiente a la latencia de interpolación a la velocidad observada;
no presentarla como error residual después de compensar el retardo.

`fps {p1,percent_below_60,frames,display_server}`: medido con deltas de frames;
headless no demuestra rendimiento visual. Nunca sustituir percentil por media.

`activity {hold_requested,hold_granted,hold_denied,release,strap_ok,
strap_denied,unstrap,authority_transfers,complete_cycles}` por peer iniciador.
Un ciclo solo cuenta tras agarrar → amarrar → desamarrar → soltar confirmado.
Menos de diez ciclos por instancia invalida la corrida y no consume D96.

Criterio vigente D95 v5: `hull_exit_ticks=0` en ambas instancias y ningún
empujón >45 ticks. Con ≥10 ciclos por instancia, p99 filtrado cliente
≤1,5× anfitrión de la misma corrida; el máximo solo se reporta.
Penetración solo de cuerpos simulados localmente: tripulante propia no
sentada y carga FREE dinámica con autoridad local. Máximo ≤0,05 m y racha
≤3 ticks contando solo profundidad >0,03 m, puerta excluida e histograma.
Las muestras de penetración ausentes durante transiciones siguen siendo
una limitación declarada; no certifican máximos o rachas completos.
FPS evaluables con ventana, VSync=0 y max_fps=0: p1 ≥60 y porcentaje bajo 60;
headless no aprueba render. Errores remotos sin umbral inventado.
Se declara velocidad real sobre baches; 66,5 km/h no cumple los 80 del maestro.

D96 conserva dos fallos válidos, corridas 2 y 4: fuera del casco
anfitrión/cliente **0/16.784** y **0/14.494** ticks. Sus percentiles sin filtrar
no se juzgan con v5. El experimento `r5_final_300` da **0/13.066**,
incumple la precondición y no consume una iteración.
D98 autoriza una sola ronda experimental adicional. Antes del tercer gate:
exactamente 300 s, cero salidas, ningún empujón >45 ticks y ≥10 ciclos en
ambas instancias, sobre el mismo commit limpio y configuración que el gate,
sin cambios intermedios. Si no cumple, parar: el revisor redacta el plan B
con D98. Si el tercer gate falla, se aplica D96; no hay otra ronda.
El resultado automático no aprueba el gate humano.

## D98: inercia aérea y conservación de evidencia

Decisión del dueño: el empujón de carga es juego. Mantener FREE cinemático
en réplicas, autoridad vigente y colisión tripulante–carga; sin inmunidad,
réplicas dinámicas ni implementación de B. Conservar en el aire la velocidad
acarreada del último tick con apoyo y sumar el paseo; al aterrizar el motor
retoma el acarreo. Documentar `platform_on_leave` y comprobar salto de pie,
caminando, sobre baches, caja lenta y controles sin carga a 80 km/h.
Para los saltos en recta, el límite de 0,30 m se aplica al residuo
`|aterrizaje_local - (despegue_local + v_paseo_local * t_vuelo)|`,
con tiempo de vuelo expresado en segundos y velocidad de paseo horizontal
relativa al bus del último tick apoyado; reportar también distancia literal.
Cero salidas, recuperación del empujón ≤45 ticks y controles sin carga con
presión −0,5 conservan cero aire. Empujón simétrico y eventual tope de
corrección de réplica quedan en BACKLOG, sin implementarlos aquí.

Regla E0 del [prompt de ronda 6](../../planes/M2-GATE_ronda6_prompt_codex.md):
commitear resúmenes, JSON por peer, volcados de pérdidas de apoyo, logs y
capturas. CSV por tick solo de iteraciones que consumen D96 y del experimento
de 300 s que fundamenta la siguiente decisión. Trazas y snapshots crudos
solo de iteraciones que consumen D96; el resto se genera y usa sin
commitearlo. Cualquier excepción se justifica en el reporte.
Los crudos retirados por el revisor no se restauran.

## Integración y propiedad exclusiva

- A: net_crew_sync y auxiliares de tripulante; crew_member, crew_input,
  crew_hands, camera_arbiter, Playground (retirar autorada y modo local),
  tests/net/crew_sync_test. No archivos de B.
- B: net_cargo_sync y auxiliares de carga; package.gd;
  tests/net/cargo_sync_test. No CrewHands ni Playground.
- Coordinador: receptor bus, herramientas gate, métricas, wrappers, evidencias,
  constantes EXPECTED_TESTS, regresiones e integración. No escenas/bus/tuning.

El modo gate deriva TODOS los plazos de seconds (300 s + preparación/salida),
con un host y un cliente; el escenario legado mantiene sus marcadores y ruta.
run_gate permite human=client con ventana y host headless. Comprobar el cliente
con ventana; el gate humano y el juicio de sensación siguen siendo del dueño.
