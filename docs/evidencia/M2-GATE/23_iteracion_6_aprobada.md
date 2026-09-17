# 23 — Iteración 6: el gate pasa el criterio automático. Falta el gate humano.

**Fecha:** 2026-09-17 · **Commit de simulación:** `aa8058f`, árbol limpio verificado por el lanzador — **hash del historial anterior a la compactación del 2026-09-17; ya no existe en la rama.** Todo el trabajo de esos 53 commits vive ahora en uno solo, y la correspondencia completa (hash, fecha y autor de cada uno) está en [24_historial_de_la_rama.md](24_historial_de_la_rama.md). Los `source_commit` de los JSON de esta corrida se conservan sin tocar: registran con verdad qué commit la produjo, aunque ese objeto ya no sea alcanzable · Motor `4.7.2.stable.official.ed1daf0bf`, Jolt. Dos ventanas, VSync off, `max_fps = 0`, `human=none` (guionizada en las dos instancias). 300 s / 18.000 ticks por instancia.

**Veredicto automático: `status: passed`, `valid: true`, `logic_passed: true`, `render_verified: true`, `failures: []`, `invalid_reasons: []`.** Código de salida 0.

**GATE APROBADO (D97) por el dueño el 2026-09-17.** Jugó la instancia cliente y su veredicto fue «se siente bien al estar en el auto manejando»; la única pega que levantó resultó ser la puerta de carga (D99), no el acarreo. Cerró la ventana antes de los 300 s, así que la sesión no fue completa y queda dicho; el dueño dio el gate por bueno con lo que sintió («todo ok sigamos»). Sesión y mediciones en [25_gate_humano.md](25_gate_humano.md).

Muestreo: observador independiente `GateMetrics` posterior a los nodos, `process_priority` y `process_physics_priority` = 1000, idéntico en ambas instancias, solo lectura. Precondición: [`22_raw/r6_pre_aa8058f`](22_raw/r6_pre_aa8058f/summary.json), verde sobre este mismo commit y configuración, verificada por la guardia de `gate_launcher.gd`.

## Criterios D95 v5

| Criterio | Anfitrión | Cliente | Exigencia | |
|---|---:|---:|---|:--:|
| **Ticks fuera del casco** | **0** | **0** | = 0 | ✔ |
| Empujón más largo | 0 ticks | **19 ticks** | ≤ 45 | ✔ |
| Empujones abiertos al terminar | 0 | **0** | 0 | ✔ |
| **Deslizamiento filtrado p99** | 0,03387 | **0,03490** | razón **1,0305** ≤ 1,5 | ✔ |
| Penetración local máxima | 0,02212 m | 0,02952 m | ≤ 0,05 | ✔ |
| Racha de penetración | 0 ticks | 0 ticks | ≤ 3 | ✔ |
| Ciclos completos | 114 | 125 | ≥ 10 | ✔ |
| Cámaras activas | 1 / 1 | 1 / 1 | exactamente 1 | ✔ |
| fps p1 | 475,5 | 481,9 | con ventana, VSync off | ✔ |
| ERROR / WARNING | 0 / 0 | 0 / 0 | 0 | ✔ |
| Carga simulada sin autoridad | 0 | 0 | 0 | ✔ |
| Tripulante remota simulada | 0 | 0 | 0 | ✔ |

Ruta `straight_x30_with_outer_return`, **12 vueltas**, entradas al campo de baches de 66,4 a 82,7 km/h. El maestro pide 80; se cumple en once de las doce (la primera es la carrerilla inicial).

## Lo que se reporta y NO se juzga, porque es lo que el dueño tiene que sentir

- **31 empujones de carga en el cliente**, ninguno en el anfitrión. El más largo la deja 19 ticks (0,32 s) sin apoyo y la desplaza hasta **0,504 m** en el marco del bus. De los 31, **todos se recuperan**: ninguno queda abierto al terminar.
- Apoyo 99,983 % (anfitrión) y 99,211 % (cliente). Ya no es umbral: con D98 el empujón es juego y lo que se exige es que no salga del casco.
- **Deslizamiento crudo del cliente: p99 0,270 m.** Esa es la cifra con los empujones dentro, y es la que se va a ver con los ojos. El p99 filtrado de 0,0349 dice que **fuera de los empujones el cliente va como el anfitrión** (1,03×); el crudo dice que **durante los empujones hay medio metro de tirón**.
- Error remoto del cliente: bus p95 2,037 m, tripulante 1,295 m, carga 2,405 m. Son latencia de interpolación expresada en metros (≈ 90 ms a 22 m/s), no error de simulación.

## La asimetría, otra vez y por escrito

El anfitrión tiene **cero** empujones y el cliente **31**. No es que el cliente juegue peor: la carga rígida del anfitrión no puede mover a su tripulante (un `CharacterBody3D` es inamovible para un cuerpo rígido) mientras que las réplicas cinemáticas del cliente sí mueven a la suya. D98 lo acepta y lo declara; el empujón simétrico es tarea de M3. **Consecuencia práctica: en una partida, quien hace de anfitrión no sufre empujones de carga y los clientes sí.**

## Historia del contador D96

| Iteración | Estado | ¿Consume intento? |
|---|---|---|
| 1 | inválida (ciclos insuficientes) | no |
| 2 | **fallida** | **sí (1)** |
| 3 | inválida | no |
| 4 | **fallida** | **sí (2)** |
| 5 | inválida (instrumentación: caja sin forma activa) | no |
| 6 | **APROBADA** | — |

Dos fallos válidos consumidos, el tercero nunca gastado. La opción B no se activa.

## Lo que queda, y no es opcional

1. **El gate humano (D97).** Cinco minutos jugando la instancia cliente con ventana mientras el anfitrión conduce. Orden exacta:

   ```
   powershell -ExecutionPolicy Bypass -File tools/run_gate.ps1 -Seconds 300 -Human client
   ```

   Qué mirar: caminar por el pasillo con el bus a 80 km/h y sobre los baches; agarrar una caja (clic izquierdo), llevarla a un anclaje y amarrarla (E mantenido); desamarrar (E) y soltarla (clic derecho); y **sobre todo, dejar que una caja suelta te empuje**. La pregunta que solo tú puedes contestar: ese empujón de medio metro, ¿se siente como parte del juego o como un fallo?

2. **Si el empujón se siente injusto**, la salida ya está escrita en D98(d): limitar la corrección de las réplicas a una velocidad relativa al bus, sin suprimir la colisión. Es una medición, no un rediseño.

3. **Nada de M3 antes del punto 1.** El gate existe para no construir encima de un riesgo sin verificar, y una tabla verde no es una verificación humana.
