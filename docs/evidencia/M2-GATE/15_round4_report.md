# Ronda 4 — diagnóstico, correcciones y límite de la entrega

**El gate sigue pendiente.** Hay dos fallos válidos D96: corridas 2 y 4.
El tercer intento se conserva; la opción B no se activa ni se implementa.
La corrida 4 corresponde al segundo intento válido, aunque su número de archivo
incluye dos corridas inválidas anteriores.

## Primer despegue instrumentado

En el experimento `r4_cargo_cycles_01`, tick previo 88 → pérdida 89:

| Campo del tick previo | Valor |
|---|---|
| Apoyo | `Bus/Floor` y `Bus/CollisionShape3D` |
| Velocidad lineal de plataforma | aproximadamente (0, 0, 4,188538) m/s |
| Escritura del bus | 0,0714264 m |
| Instantánea recibida | Ninguna nueva; fuente 4,0 s, reproducción usada 3,95 s, margen 50 ms |
| Caja más próxima | `Package_3`, FREE, autoridad 1, congelada cinemática; distancia 1,548994 m |

Al tick 89 la caja queda a 0,172075 m y aparece como único contacto, con
profundidad 0,101411 m y velocidad de plataforma vertical −70,507 m/s.
La tripulante sube 0,31895 m. No se interpreta esa velocidad vertical negativa
como explicación directa del ascenso: hay solapamiento y desplazamiento
cinemático discreto, defectos reproducidos por separado en bancos.
La escritura del bus sigue en 0,0714264 m; llega una instantánea, con margen
66,667 ms. [Volcado completo](13_raw/r4_cargo_cycles_01/client_support_losses.json).

## Reducción y arreglos

Los experimentos de 60 s con caminar explícito, VSync off y sin límite de FPS
conservan apoyo 100/100 % sin carga, y 100/99,888889 % con carga sin ciclos.
Con ciclos, el cliente cae a 12,166667 %. Los logs y condiciones están en
[la evidencia de reducción](13_support_loss_reduction.md), incluido el
[log cliente sin carga](13_raw/r4_no_cargo_01/client.log).

Se corrigieron tres defectos medidos:

1. Soltar podía colocar una caja dentro de la cápsula. Se comprueba el volumen
   completo, la accesibilidad de la posición alternativa y la validación host.
2. La transición confirmada de una réplica podía fabricar velocidad cinemática
   entre la mano y el suelo. Se teletransporta y sincroniza esa transición;
   el movimiento continuo posterior conserva su comportamiento cinemático.
3. Una réplica recién FREE quedaba fija en mundo hasta su primera pose.
   Se inicia su búfer con la pose confirmada en el marco del bus.

Cada arreglo conserva prueba roja y verde. El último experimento, 120 s sobre
`1eeb635`, alcanza **87,652778 % de apoyo cliente y 44 ciclos**, todavía bajo
95 %. Persisten contactos laterales con cajas cuya velocidad de plataforma
difiere del suelo, y penetraciones locales. [Diagnóstico pendiente](14_remaining_cargo_contact.md).
No se consume otro intento D96 sobre esas causas sin aislar.

## Registro corregido del gate

Muestreo común: observador independiente `GateMetrics`, después de los nodos,
`process_priority=1000` y `process_physics_priority=1000`, sin escribir estado.

| Medida | Corrida 2: host / cliente | Corrida 4: host / cliente |
|---|---:|---:|
| Apoyo local en bus | 99,561111 / 6,633333 % | 99,988889 / 19,411111 % |
| p99 local por tick, descriptivo | 0,140457 / 1,191739 m | 0,033875 / 1,214998 m |
| Penetración local máxima | 0,074849 / 0,200542 m | 0,035662 / 0,066812 m |
| Racha de penetración máxima | 7 / 58 ticks | 4391 / 216 ticks |
| Ciclos completos | 118 / 10 | 120 / 25 |
| FPS p1 | No juzgable: VSync y límite | 146,713615 / 175,777817 |
| Fotogramas bajo 60 FPS | No juzgable | 0,001774 / 0,001548 % |
| Veredicto automático | Fallo válido 1 | Fallo válido 2 |

En ambas, el apoyo impide citar el p99 como jitter. Corrida 2 conserva además
penetraciones de tripulantes locales: la afirmación del revisor de que solo
quedaba un motivo no coincide con los datos, y se avisó antes de editar.
La racha de 4391 ticks de corrida 4 corresponde a carga dinámica anfitrión;
los 216 ticks cliente corresponden a su tripulante local. Réplicas excluidas.
Tablas completas: [corrida 2 reemitida](04_gate_iteration_2.md) y
[corrida 4](04_gate_iteration_4.md), con actividad y errores remotos.

## Verificación

- Tres arneses completos: **0 / 0 / 0**, **236/236** cada uno, exactamente
  `EXPECTED_TESTS` de ambos envoltorios. Imports 0/0 y red corta aprobada en
  cada corrida. [Resultados y hashes de logs](02_r4_verified_runs.json).
- Sonda de las cuatro opciones unsafe_* elevadas a error: código 0, 236/236,
  red e imports en 0. `project.godot` restaurado sin diff.
- Demo, medición de conducción y red larga: 0 / 0 / 0. Las seis cifras
  permanecen 0,977 m; 6,93 s; 90,0 km/h; 12,4 m; 6,7 m; 0,98 s.
  [Regresiones](06_regression.md).
- Worktree nuevo en `266f459`, sin `.godot` previo: dos imports código 0,
  caché de clases presente, status vacío y ningún `.uid` sin trackear.
  [Registro](07_r4_fresh_import.json). Fuentes idénticas a `1eeb635`.
- Ocho ejecuciones, dieciséis logs de instancias: cero ERROR y cero WARNING.
  [Logs de ambas instancias](10_windowed_clean_log.md).
- Inspección nativa del cliente con anfitrión headless: apoyo 100 % en 120 s,
  capturas del interior/remota/cajas. Los taps no produjeron agarres; no acredita
  un ciclo manual, control sostenido ni jugabilidad. Además es anterior al
  último arreglo del búfer. [Capturas y límites](05_windowed.md).

## Commits de la ronda

- `632fafa`: revisión 04 intacta, primero.
- `c23e751`: instrumentación de pérdidas y experimentos de reducción.
- `f362783`: geometría de liberación y criterios D95 corregidos.
- `19836c7`: transición discreta de réplica y accesibilidad de colocación.
- `1eeb635`: búfer inicial de la réplica FREE; fuentes finales, 236 tests.
- `266f459`: reducción, gate, capturas y diagnóstico pendiente.

Los commits posteriores a `1eeb635` solo registran evidencia y documentación.
No se tocó `main`, bus/suspensión, tuning, escenas ni ajustes persistentes del
proyecto. [Límites R8](09_limits.txt); [lo no verificado](08_no_verificado.txt).
