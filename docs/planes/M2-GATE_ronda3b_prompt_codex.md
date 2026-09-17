# Prompt para Codex — M2-GATE, cierre de la fase 0 tras retirar g2.1

Copiar desde `CONTEXTO:` hasta el final. Continúa el trabajo que ya tienes abierto; no empieces de cero.

---

CONTEXTO: Proyecto "Ruta Frágil", rama `m2/gate-two-instances`, HEAD `bc2323f` con tus cambios de fase 0 sin commitear. Hay dos archivos del revisor sin commitear: `docs/revisiones/M2-GATE_revision_03.md` y `docs/planes/M2-GATE_ronda3b_prompt_codex.md`. Cométealos tal cual primero.

## 1. Tenías razón: g2.1 queda RETIRADO

Tu contraprueba es correcta y la verifiqué por mi cuenta. Añadí un observador con `process_priority = 1000` a mi propia sonda, conservando la lectura original, y sale **peor para mí** de lo que tú lo presentaste: los dos puntos de muestreo dan una **imagen en espejo**.

| Camino | Escritura | Deslizamiento máx muestreado en `physics_frame` | Muestreado tras los nodos |
|---|---|---|---|
| paso 30 Hz | `physics_frame` | 0,1586 (razón plataforma 1,01) | 0,6009 (0,00) |
| paso 30 Hz | nodo `_physics_process` | 0,6009 (0,00) | **0,0127 (1,01)** |
| interpolado | `physics_frame` | 0,0791 (1,01) | 0,0802 (1,01) |
| interpolado | nodo | 0,0795 (1,01) | 0,0083 (1,01) |

Muestreando donde yo muestreaba gana la escritura que yo defendí; muestreando donde tú mides gana la contraria, por un margen aún mayor. **Mi tabla medía dónde estaba la regla, no dónde ocurría la escritura.** La retractación completa está en `docs/revisiones/M2-GATE_revision_03.md`.

Aparte, lo hiciste bien en tres cosas que quiero decir por escrito: **no tocaste el umbral para que pasara**, **conservaste la lectura original** en vez de sustituirla (por eso se ve el espejo), y **no registraste el hecho como verificado en `DECISIONS.md`** aunque yo te lo había pedido: escribiste la discrepancia y la dejaste abierta. Esa nota tuya era lo correcto.

## 2. Qué hacer con eso, y es corto

1. **Borra `tests/net/bus_write_order_test.gd`.** No le ajustes el umbral: pinea algo que no existe. Es 1 test, así que **`expected_tests` baja de 187 a 186** en los dos arneses, en el mismo commit. Con eso desaparece el fallo que te deja el arnés en código 100.
2. **Sustituye tu nota de `DECISIONS.md`** por la resolución: g2.1 retirado, el punto de escritura queda a criterio del ejecutor, y lo que sí queda registrado es el requisito del punto 3. Cita `M2-GATE_revision_03.md`.
3. **`NetBusSync` se queda como lo diseñaste.** La conexión a `physics_frame` me sigue pareciendo más limpia que depender de prioridades de nodo, pero eso es gusto mío, no medida, y la decisión es tuya.
4. **Un hecho menor que SÍ queda establecido** y puedes anotar: **`physics_frame` se emite ANTES del procesado de nodos**. Se deduce de que los dos puntos de muestreo difieran.

## 3. Lo que hay que salvar, y es el cambio real: D95 exige punto de muestreo declarado

Es la lección que deja esto, y te afecta directamente porque el criterio del gate **es** una métrica por tick. Ya está escrito en el plan; impleméntalo:

- **El punto de muestreo se declara y se fija:** un nodo observador dedicado, con `process_priority` documentado, que corra el último y **que no sea el mismo nodo que escribe nada**.
- **El mismo punto para el anfitrión, para el cliente y para todas las filas.** Si cada instancia muestrea donde le toca, el cociente de 1,5× compara peras con manzanas.
- **Cada tabla de la evidencia dice dónde muestreó.** Una tabla de deslizamiento sin punto de muestreo declarado no es comparable con ninguna otra.

Aplícalo a `run_carry_probe.gd` y al modo gate. Si eso cambia alguna cifra de la tabla del paso 1, **repítela y dilo**: la decisión de interpolar no está en riesgo (medida en las cuatro combinaciones de escritura y muestreo da entre 0,008 y 0,080 siempre, frente a ~0,60 del salto en uno de los dos puntos siempre), pero los números publicados tienen que corresponder a un punto declarado.

## 4. Cierra la fase 0

De la lista de la revisión 02 ya tienes hechas, y las comprobé en tu árbol: **g2.7** (tabla caminando repetida con cada régimen sobre su grabación, y la distancia entre trayectorias medida de verdad: p95 3,54 m y máximo 3,84 m, **diez veces lo que los dos habíamos estimado a ojo** — buen hallazgo), **g2.8** (`add_to_group("package")`), **g2.9** (`NetAuthority.local_crew`), **g2.13** (`has_bus_support` y la columna renombrada), **g2.14** (el checksum sustituido por una distancia) y la fórmula de la carga por autoridad con las dos puertas unificadas.

Queda: lo de arriba (borrar el test, bajar el conteo, la nota de decisiones, el punto de muestreo), y cerrar `00_phase0_contract.md` con **g2.2** (criterio p99), **g2.3** (`bus_remote_error` en el JSON), **g2.10** (el sostenedor en `apply_replicated_state` y la enumeración de todas las transiciones, incluida `STRAPPED → FREE` replicado) y **g2.11** (la sonda en README y AGENTS).

## 5. Y después, sin más paradas

**A — tripulantes.** Una por peer bajo `Crews/Crew_<peer_id>`, autoridad de su peer; la local se simula, las remotas reciben transformada interpolada y no llaman a `move_and_slide`; **exactamente una cámara activa por instancia, medido**; input y manos solo sobre la local.

**B — carga.** Sueltos con autoridad del anfitrión, clientes cinemáticos interpolados a 20 Hz; los cuatro RPC por nombre validados en el anfitrión; cesión y devolución de autoridad; **ninguna instancia simula carga que no le pertenece, medido**.

**Integración y primera iteración del gate:** `++ mode=gate`, 300 s con el presupuesto derivado de `seconds` (no de los waypoints, que dan 240 y matan la corrida a los 285), ataque al campo de baches **en recta** por el carril, `tools/run_gate.*` con `++ human=client`, y el criterio de D95 entero: p99 ≤ 1,5× con el punto de muestreo declarado, atravesamientos con tolerancia de 5 cm y 3 ticks, error remoto de bus, tripulante y carga, fps por percentil 1, y los diez ciclos de actividad por instancia (por debajo: iteración **inválida**, no gasta una de las tres de D96).

**Antes de dar nada por bueno, juega tú la instancia cliente con ventana mientras el anfitrión conduce.**

Reporte final: hashes, los tres códigos de salida del arnés con el conteo actualizado, la tabla de la iteración con el punto de muestreo declarado, los logs de las dos instancias, las capturas, el veredicto A/B con la iteración en que se decidió, y lo que quede abierto. Si algo no cuadra con lo que ves, dilo antes de tocarlo: ya van tres veces que el revisor se equivoca en esta tarea y las tres las ha escrito.
