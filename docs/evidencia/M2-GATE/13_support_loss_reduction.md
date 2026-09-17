# Reducción de pérdida de apoyo — revisión 04

Motor `4.7.2.stable.official.ed1daf0bf`, Jolt. La revisión se preservó sin cambios
en `632fafa`; instrumentación en `c23e751`. Los ensayos siguientes son
experimentos, no veredictos, y no escriben el ledger D96.

Muestreo común: `GateMetrics`, observador independiente después de los nodos,
`process_priority=1000`, `process_physics_priority=1000`. Cada flanco de apoyo
verdadero→falso conserva copia completa del tick anterior y del actual.

| Experimento de 60 s / 3600 ticks | Apoyo anfitrión | Apoyo cliente | Ciclos anfitrión / cliente | Salida |
|---|---:|---:|---:|---:|
| [Sin carga, caminar](13_raw/r4_no_cargo_01/summary.json) | 100 % | 100 % | 0 / 0 | 0 |
| [Con carga, mismo caminar](13_raw/r4_cargo_walk_01/summary.json) | 100 % | 99,888889 % | 0 / 0 | 0 |
| [Con carga e interacciones, antes del arreglo](13_raw/r4_cargo_cycles_01/summary.json) | 99,416667 % | 12,166667 % | 26 / 4 | 0 |
| [Solo colocación libre corregida](13_raw/r4_release_fix_01/summary.json) | 100 % | 16,638889 % | 24 / 5 | 0 |
| [Colocación y transición cinemática corregidas](13_raw/r4_transition_fix_01/summary.json) | 100 % | 97,055556 % | 24 / 25 | 0 |

Todos: dos ventanas, VSync=0, max_fps=0, mismo observador; cero ERROR/WARNING
en ambos logs. Los nombres de cada fila enlazan sus métricas, trazas por tick,
instantáneas recibidas, flancos de pérdida de apoyo, logs y capturas. El modo
sin carga usa caminar explícito: el actor original retornaba si no encontraba
su paquete, lo que habría confundido ausencia de cajas con quedarse quieta.

Comando reproducible (el nombre de salida debe ser nuevo):

```powershell
powershell -ExecutionPolicy Bypass -File docs/evidencia/M2-GATE/run_reduction.ps1 -Name nuevo_sin_carga -Cargo off -WalkOnly
powershell -ExecutionPolicy Bypass -File docs/evidencia/M2-GATE/run_reduction.ps1 -Name nuevo_con_ciclos -Cargo on
```

Primer despegue de la reproducción con carga, tick **89**, anterior **88**:

| Campo | Tick anterior 88 | Tick 89 sin apoyo en bus |
|---|---|---|
| Cuerpo / forma de contacto | Bus/Floor y Bus/CollisionShape3D | Package_3/Shape; normal UP; profundidad 0,101411 m |
| Velocidad de plataforma (m/s) | ≈[0; 0; 4,188538] | [40,652805; −70,507034; −10,052404] |
| Escritura del bus | 0,071426 m | 0,071426 m |
| Instantáneas nuevas / margen fuente−reproducción | 0 / 50 ms | 1 / 66,667 ms |
| Caja más cercana, distancia entre orígenes | Package_3, FREE, 1,548994 m | Package_3, FREE, 0,172075 m |
| Posición local Y de tripulante | −0,599241 m | −0,280292 m |

Volcado íntegro: [client_support_losses.json](13_raw/r4_cargo_cycles_01/client_support_losses.json),
primer elemento; también `SUPPORT_LOST` en el [log cliente](13_raw/r4_cargo_cycles_01/client.log).
Incluye velocidad propia y real, contactos, RID, forma, pose de bus/caja,
reloj de llegada UTC, transporte, reproducción usada y siguiente, autoridad
y congelación. La distancia anterior de 1,55 m no descarta la caja: en el
siguiente paso físico se mueve al destino de la liberación.

El diagnóstico tiene dos componentes comprobados. Primero, la consulta de
colocación omitía la capa 3 de tripulantes y el fallback soltaba en el centro
de sus pies sin comprobar volumen. Segundo, la transición de una réplica
cinemática interpretaba mano→suelo como movimiento de un paso físico. La
recuperación de penetración y esa velocidad de plataforma podían expulsarla.
La velocidad del contacto apunta hacia abajo: no se confunde con el salto
ascendente de la tripulante ni se atribuye todo a un impulso vertical directo.

Pruebas antes/después, con bus quieto y sin transporte de red:

- [Colocación anterior](13_release_red.log): código 100, subida de **0,419616 m**;
  [corregida](13_release_green.log): código 0, subida **0 m**. Sin espacio,
  conservar HELD y autoridad; lanzar desde una mano bloqueada también se rechaza.
- [RPC sin validación geométrica](13_release_host_red.log): código 100;
  [validación en anfitrión](13_release_host_green.log): código 0.
- [Transición cinemática](13_transition_red.log): código 100, **97,563263 m/s**
  aunque la liberación solicite velocidad cero. Cambiar solo el modo sin
  enviar la transformada al motor tampoco basta ([ensayo](13_transition_green.log),
  código 100 pese al nombre histórico del archivo).
- Colocar temporalmente como STATIC, `force_update_transform()` y volver a
  KINEMATIC: [código 0, velocidad 0](13_transition_flush.log). El test también
  comprueba que las siguientes transformadas conservan movimiento cinemático.
- [Destino al otro lado de pared fina](13_drop_wall_red.log): código 100;
  la colocación ahora comprueba obstrucción además de volumen.
- [61 tests de red](13_transition_net_green.log): código 0.

Arreglo geométrico: `f362783`. Arreglo de transición: `19836c7`. No se cambia
el bus, su suspensión, la interpolación del bus ni su entrega de instantáneas.
La notificación diferida de transformada está documentada en
[Node3D de Godot 4.7](https://docs.godotengine.org/en/4.7/classes/class_node3d.html#class-node3d-method-force-update-transform).
Se comprueba la consecuencia física con el motor pineado, no una explicación
universal para otras versiones.

No fue necesario inyectar irregularidad del bus: la rama sin carga conservó
apoyo completo, y el defecto se reprodujo sin red. Las trazas quedan para una
investigación posterior si aparecen pérdidas con otro origen. Los cinco
flancos restantes del ensayo corregido y su 2,944444 % sin apoyo no se ocultan.
Estos 60 s no aprueban el gate de 300 s ni la jugabilidad humana.

La corrida posterior de 300 s se conserva como [segundo fallo válido](04_gate_iteration_4.md):
el buen total de 60 s no garantizó permanencia. La investigación y el arreglo
adicional de espera inicial FREE están en [evidencia14](14_remaining_cargo_contact.md).
El nuevo experimento 120 s queda bajo el95 %; el acarreo sigue abierto.
