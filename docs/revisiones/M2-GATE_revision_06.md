# Revisión 06 — M2-GATE ronda 5: D no pasa, la anatomía de la expulsión, y la decisión que toca tomar

**Fecha:** 2026-09-17 · **Revisa:** Claude · **Revisado:** rama `m2/gate-two-instances`, HEAD `91ffbb7` (fuentes finales `25c7a72`), 241 tests · **`main`** = `origin/main` = `2b16e99`, intacto · **Pliego:** `M2-GATE_plan.md` D91–D97 + `M2-GATE_ronda5_prompt_codex.md`

## Veredicto: parar fue correcto. D96 conserva dos fallos válidos. Y esta ronda no podía arreglarlo, porque la causa es estructural y está en MI diseño, no en un defecto más.

El experimento de 300 s da **27,33 % de apoyo cliente** con pérdida definitiva en el tick 4923 (82 s). No cumple D en los tres requisitos. El ejecutor paró, no gastó la tercera iteración y no implementó nada de B. Bien, y era lo pactado.

Pero lo importante de esta ronda no es el número: es que **sus volcados permiten ver, tick a tick, la mecánica exacta de la expulsión**, y esa mecánica no es "otro bug de réplica". Son tres asimetrías entre anfitrión y cliente que salen de dos decisiones de diseño: **D94** (carga del cliente como réplicas cinemáticas, decisión mía en el plan del gate) y el **modelo de velocidad de la tripulante** (T2.2, nunca probado en el aire a velocidad). Ninguna se arregla en una ronda de parches, y la opción B tal como está escrita en ADR-003 **solo quita dos de las tres**.

## Reproducción

| Qué | Ellos | Yo | |
|---|---|---|---|
| Arnés PowerShell | 0, 241/241, red pass | **0, 241/241, red 1+3 pass, desviación 0,000 m** | ✔ |
| 300 s, apoyo cliente / anfitrión | 4.920 / 17.997 de 18.000 | **4.920 / 17.997** | ✔ |
| Flancos cliente | 1040 (recupera en 2), 4923 (no recupera, 13.078) | **idéntico** | ✔ |
| Flancos anfitrión | 1592 (2), 2237 (1) | **idéntico** | ✔ |
| Baseline 120 s instrumentado, cliente | 99,74 %, 12 flancos, todos recuperados | **7.181 / 7.200, 12 flancos, todos ≤ 3 ticks** | ✔ |
| Fase de liberación | 0,308333 m → 0 | coincide con **un tick de bus a 66,6 km/h** (0,3083 m): el servidor va un tick por delante del nodo | ✔ |
| `main` intacto | sí | **2b16e99 = origin** | ✔ |

## La anatomía del tick 4923, con las tres fuentes cruzadas

Alineé por UTC el CSV del anfitrión, el CSV del cliente, la traza del anfitrión a 10 Hz y el volcado de flancos del cliente con sus tres ticks previos. Esto es lo que pasa, en orden:

| Instante | Anfitrión (física real) | Cliente (réplicas) |
|---|---|---|
| −0,3 s | Su actor **suelta `Package_3` en el suelo del pasillo**, local (0,02; −0,38; 0,18). | La réplica aparece en el suelo, 0,8 m delante de la tripulante. |
| **−0,1 s (tick 4917)** | **El bus pierde 15 km/h en un tick: 78,4 → 63,0.** Es un impacto (baches o aterrizaje: `bus_y` viene bajando desde 2,63). La tripulante del anfitrión **no lo siente**: deslizamiento 0,0306 antes, durante y después, igual que caminando. | La réplica del bus reproduce la frenada 70 ms después, suavizada en tres ticks: 0,3695 → 0,3292 → 0,2895 m/tick. |
| −0,1 → +0,4 s | **La caja, libre y rígida, conserva su inercia y desliza hacia delante 35 cm**, luego vuelve 80 cm atrás. Física. | La réplica de la caja **avanza 2 cm/tick y sube 1,3 cm/tick** (y local −0,399 → −0,361), cinemática, siguiendo al anfitrión a 20 Hz. |
| ticks 4919–4922 | — | **La tripulante se adelanta 2–5 cm por tick respecto al suelo** (deslizamiento 0,023 / 0,022 / **0,054** / 0,019): la velocidad de plataforma que el motor le aplica es la del tick anterior (21,81 m/s) mientras el suelo ya escribe 19,75. Se mete contra la caja que tiene delante. |
| tick 4922 | — | Contacto con `Package_3` con normal (−0,22; **+0,22**; −0,95): el borde trasero-superior de la caja, que sube, está debajo de la cápsula. Adopta la caja como plataforma (21,36 m/s). |
| **tick 4923** | — | **Sube 8 cm** (y −0,612 → −0,531), **cero contactos**, `on_floor = false`. Al dejar la plataforma el motor le suma su velocidad: `velocity = (−0,96; 1,47; **22,36**)`. |
| tick 4924 → fin | — | Su `z` local crece **0,265 m por tick**: se queda a **~1,4–2 m/s en el mundo** (la velocidad de paseo del actor, 0,5 × 4 m/s) mientras el bus se va a 62 km/h. A los 14 ticks está fuera del casco. |

## Las tres asimetrías, y de dónde sale cada una

**1. La velocidad de plataforma de una réplica cinemática va un tick por detrás.** [Seguro] En el anfitrión el bus es un `RigidBody3D` y `move_and_slide` lee su velocidad *actual*: la tripulante del anfitrión ni se entera del impacto (0,0306). En el cliente el bus es cinemático y la velocidad que Jolt reporta es la del desplazamiento del tick anterior: en una frenada de 8,7 km/h por tick, ella se adelanta 4–5 cm por tick respecto al suelo. Es el mismo hecho que D84 midió como "un tick de retardo, 0,3 m". Sola no la expulsa; la empuja contra lo que tenga delante.

**2. Las réplicas de carga son cinemáticas, así que tienen masa infinita frente a la tripulante.** [Seguro] En el anfitrión una caja suelta es rígida: si se mete bajo sus pies, **la caja cede**; un `CharacterBody3D` es inamovible para un cuerpo rígido. En el cliente la misma caja es cinemática: **cede ella**, y `move_and_slide` la saca de la penetración hacia arriba. Los +8 cm del tick 4923 son eso. Y es la misma familia que las cuatro expulsiones anteriores: caja dentro de la cápsula (ronda 4), caja parada en el mundo (corrida 4), corrección de 0,31 m interpolada (esta ronda, el 2/3), caja que sube tras el impacto (ahora). **Cualquier movimiento de una réplica respecto al suelo, físico o artefacto, empuja solo a la tripulante del cliente.** Esto es D94 ("clientes cinemáticos interpolados a 20 Hz"), y D94 lo escribí yo.

**3. En el aire, la tripulante no tiene inercia del bus.** [Seguro en el código] `drive_move()` escribe cada tick `velocity.x = wish.x * speed` y `velocity.z = wish.z * speed` (`crew_member.gd:114-115`). Sobre el suelo el motor le añade la velocidad de plataforma; en el aire nadie. Los 22,36 m/s que hereda al despegar duran **un tick**: al siguiente, `drive_move` los sustituye por la velocidad de paseo, y medido en el CSV se queda a ~1,4–2 m/s en el mundo con el bus a 17 m/s. **Por eso cada despegue a velocidad es definitivo**, en las cinco corridas. Esto no es de red: es de T2.2, y afecta al anfitrión y al modo de un jugador igual. [Probable] Un salto dentro del bus a 80 km/h en un jugador acaba en la pared trasera; nadie lo ha medido porque el gate de T2.2 fue caminando.

La adopción de la caja como plataforma (revisión 05) sigue existiendo —el flanco 1040 es exactamente eso, recuperado en dos ticks— pero no es lo que la mata. Lo que la mata es 2 + 3.

## Lo que esto dice de ADR-003, de D96, y lo que recomiendo

**El acarreo de la opción A funciona.** Sin carga: 100 / 100 %. Anfitrión con carga y ciclos durante 300 s: 99,98 %, y un impacto de 15 km/h en un tick no le mueve el deslizamiento. Lo que ha fallado cinco veces es **lo que rodea al acarreo en el cliente**: la doctrina de réplicas (D94) y el modelo de velocidad en el aire (T2.2).

**La opción B como está escrita no llega.** "Interior en espacio local del bus con pseudo-fuerzas" elimina la 1 (no hay velocidad de plataforma: el suelo es estático) y la 3 (no hay inercia de bus que perder). **No elimina la 2**: una réplica cinemática de carga empuja igual en espacio local que en mundo. Con B tal cual, la caja que sube seguiría levantándola. Y B es una reescritura —composición de la vista exterior, tránsito por la puerta entre espacios, interacciones exteriores (combustible, winche, empujar)— con su propia regla de tres iteraciones por delante.

**Recomendación: A′ = el acarreo se queda; cambian D94 y el modelo de velocidad, con presupuesto cerrado.**

- **D94 nuevo:** una réplica **nunca puede desplazar a la tripulante local**. Dos formas, a medir en el banco antes de elegir: **(i)** réplicas de carga FREE **dinámicas** (`RigidBody3D` sin congelar) corregidas suavemente hacia la pose del anfitrión —la corrección mueve la caja, no a la gente, y la semántica pasa a ser la del anfitrión: ella empuja cajas, las cajas no la empujan—; **(ii)** sin colisión entre la tripulante local y las réplicas FREE (las amarradas siguen chocando). (ii) es más barata y asimétrica en sensación (atraviesas cajas sueltas solo en el cliente); es decisión de diseño del dueño si (i) no sale.
- **Tripulante en el aire:** `drive_move` conserva la velocidad acarreada al despegar y suma el paseo encima, en lugar de sustituirla. Se mide en mi sonda con un salto a 80 km/h, de pie y caminando, y con los baches: tiene que dar 0 expulsiones sin romper el control de cero aire.
- **La 1 se acepta y se mide**, no se arregla: con 2 y 3 resueltas, adelantarse 5 cm en una frenada es un resbalón sobre el suelo, no un despegue.
- **Presupuesto:** una ronda; precondición D íntegra (300 s, ambas ≥ 95 %, apoyo en el último tick, ninguna pérdida > 30 ticks); si D pasa, la tercera iteración sobre ese commit exacto. **Si D no pasa, opción B**, y B tendrá que incluir de todos modos la decisión sobre réplicas.

Sobre D96: los dos fallos son válidos y se quedan. Lo que pido no es una cuarta iteración: es que la tercera se gaste sobre un diseño en el que la causa medida esté resuelta, en lugar de sobre otro parche. Y digo con claridad lo que cuesta pedirlo: el 16 de septiembre propuse que la ronda 5 fuera la última de experimentos; hoy pido una más porque la ronda 5 encontró **qué** es, y eso lo cambia. Es el dueño quien decide si acepta la razón.

## Lo que hay que reconocer

- **Los volcados de tres ticks previos con cajas, contactos, plataforma y escrituras son lo que ha hecho posible este diagnóstico.** Sin `packages[]`, `package_write_m` y `bus_write_vector` por tick, la anatomía de arriba habría sido una conjetura.
- **Explicaron el 2/3**: una corrección local de 0,3138 m interpolada en tres ticks resta un tercio del avance del bus. No era "escrituras que faltan"; lo dijeron y lo probaron. Y encontraron la causa de la corrección —el RPC aplicado en idle con el nodo del bus un tick por detrás del servidor— y la arreglaron con FIFO y rojo/verde (0,308 → 0).
- **Rechazaron (b) con número** (16/5 ticks en el aire) en vez de defenderlo, y dijeron que el banco **no aisló la adopción como causa** en lugar de fingir que sí. La segunda honestidad es la que vale.
- **Leyeron el motor** (`character_body_3d.cpp`, `jolt_body_3d.cpp`, `main.cpp`) y confirmaron la trampa de las máscaras en código fuente, no de oídas.
- **Pararon.** Con un 27 % delante y un flag que les permitía correr, no corrieron.

## Deuda al BACKLOG

- Salto a velocidad en un jugador: medir antes de M3 (se deduce de la asimetría 3; no medido).
- La sonda de penetración no cubre transiciones (`instrumentation_missing`); no certifica rachas ni máximos reales.
- Los de la revisión 05: `drop()`/`throw()` sin respuesta, validación con la réplica del anfitrión, latencia en el error remoto, ruido de `seat_test`.

**Dueño:** la decisión está en §"Lo que esto dice…": A′ con una ronda cerrada (mi recomendación), o B ahora. Lo que elijas es lo que escribo a continuación.
