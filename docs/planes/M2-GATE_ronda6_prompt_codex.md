# Prompt para Codex — M2-GATE ronda 6: el empujón es juego, la inercia se arregla, y la tercera iteración

Copiar desde `CONTEXTO:` hasta el final.

---

CONTEXTO: Proyecto "Ruta Frágil", rama `m2/gate-two-instances`, HEAD `91ffbb7`, 241 tests, árbol limpio salvo tres archivos del revisor sin commitear: `docs/revisiones/M2-GATE_revision_06.md`, `docs/planes/M2-GATE_plan.md` (modificado: D95 v5, D96 resuelto, **D98 nueva**) y `docs/planes/M2-GATE_ronda6_prompt_codex.md`. **Cométealos tal cual antes de empezar.** Lee la revisión 06 entera: contiene la anatomía tick a tick de la expulsión del 4923 cruzando tu CSV de anfitrión, tu traza a 10 Hz y tus volcados de flancos.

## 1. Lo que decidió el dueño, y lo que cambia para ti

**D98: que la carga empuje a la tripulación es una característica del juego.** Por tanto:

- **No construyes inmunidad.** Ni réplicas dinámicas, ni supresión de la colisión tripulante–carga, ni opción B. Las réplicas de carga siguen cinemáticas como en D94. Si un empujón la levanta del suelo, es juego.
- **Lo que sí arreglas es el defecto que convierte cada empujón en una expulsión: la pérdida de inercia en el aire.** Medido en tu propio CSV: al despegar en el tick 4923 hereda `velocity = (−0,96; 1,47; 22,36)`, y en el 4924 ya se mueve a ~1,5 m/s en el mundo, porque `drive_move()` (`crew_member.gd:114-115`) escribe cada tick `velocity.x/z = wish * speed` y borra los 22 m/s del bus. En el suelo el motor le pone la velocidad de plataforma; en el aire nadie. **Por eso las cinco expulsiones de esta tarea son definitivas.** Y no es de red: afecta igual al anfitrión y a un jugador.
- **El criterio del gate cambia a v5** (D95 en el plan): la primera fila ya no es "apoyo ≥ 95 %", es **"0 ticks fuera del casco"**. El apoyo se reporta con cada flanco y su recuperación, pero no se juzga. Los empujones se cuentan y se reportan; ninguno puede durar más de 45 ticks. El p99 del deslizamiento se calcula **solo sobre ticks con apoyo y sin contacto de carga en los tres ticks previos**.

Lee la asimetría (c) de D98 antes de tocar nada: la carga rígida del anfitrión **no puede** mover a su tripulante (un `CharacterBody3D` es inamovible para cuerpos rígidos) y las réplicas del cliente **sí**. Se acepta y se reporta; el empujón simétrico es M3. No lo implementes.

## 2. El trabajo, en orden

**A. Inercia en el aire, con rojo primero.** El diseño es tuyo; el comportamiento se mide. Antes de tocar `CrewMember`, corre los tres casos siguientes sobre `run_write_order_probe.gd` (o una sonda hermana en `src/tooling/`), con el bus reproduciendo la grabación de la recta a 80 km/h:

| Caso | Hoy (rojo esperado) | Después (verde exigido) |
|---|---|---|
| **Salto** a 80 km/h, de pie, en recta | [Probable] sale por la pared trasera; nadie lo ha medido | **residuo ≤ 0,30 m**; 0 ticks fuera del casco |
| Salto caminando por el pasillo | ídem | ídem |
| Salto en el campo de baches | ídem | 0 ticks fuera del casco |
| **Empujón de caja lenta** del banco de la ronda 5 (`slow_encounter`, que dio 35,24 % de apoyo y expulsión) | expulsión | tropieza y aterriza: **0 ticks fuera del casco, recuperación ≤ 45 ticks** |
| **Control:** sin carga, de pie y caminando, baches, presión −0,5 | 0 ticks en el aire | **sigue en 0** (si el arreglo rompe esto, no sirve) |

**Definición del residuo (corregida a petición del ejecutor, 2026-09-17).** El límite de 0,30 m se aplica al **error respecto al desplazamiento de paseo esperado**, no a la distancia literal al punto de despegue:

> `residuo = |aterrizaje_local − (despegue_local + v_paseo_local × t_vuelo)|`

donde `v_paseo_local` es la velocidad horizontal **relativa al bus** en el último tick con apoyo y `t_vuelo` los ticks en el aire. De pie, `v_paseo_local = 0` y el residuo es la distancia literal, así que ese caso no cambia. Caminando a 2 m/s un vuelo de ~0,9 s desplaza ~1,8 m **por voluntad de la jugadora**, y penalizar eso mediría el paseo, no la inercia. **Reporta las dos cifras** —residuo y distancia literal— y **juzga el residuo**.

Enseña los números del rojo antes del arreglo. Después, en el aire la tripulante conserva la velocidad acarreada del último tick con apoyo y suma el paseo encima; al aterrizar el motor retoma el acarreo. Decide y documenta `platform_on_leave`. Ningún cambio en bus, suspensión, tuning ni máscaras de colisión.

**B. Métricas v5.** En `GateMetrics` / `GateMetricsUtil.judge()` / `GateReadiness`:
- **`hull_exit_ticks`**: ticks con la tripulante local fuera de `BusInterior.is_inside_local`; primera fila; falla si > 0 en cualquiera de las dos.
- **Empujones**: pérdida de apoyo con contacto de carga en los tres ticks previos (ya tienes `packages[]` y `contacts` en la sonda de flancos). Por instancia: número, ticks máximos en el aire, desplazamiento máximo en el marco del bus, y si cada uno se recupera. Falla si alguno supera 45 ticks.
- **Deslizamiento filtrado**: p95/p99/p99,9/máximo sobre ticks con apoyo y sin contacto de carga en los tres previos; el 1,5× se juzga sobre ese p99 y solo si ambas tienen ≥ 10 ciclos. Publica también el no filtrado, marcado como descriptivo.
- La precondición D pasa a v5: 0 ticks fuera del casco en ambas, ningún empujón > 45 ticks, ≥ 10 ciclos cada una.
- Rojo/verde para `judge()` y `GateReadiness` con los tres casos: expulsión, empujón largo, y verde. `expected_tests` sube en el mismo commit, en los dos arneses.

**C. Experimento de 300 s con la precondición v5.** Si pasa, **la tercera iteración, sobre ese commit exacto, sin tocar nada entre medias.** Si no pasa, para y repórtalo: el plan B lo escribe el revisor con D98 dentro. No hay más rondas de experimentos después de esta (D96).

**D. Prepara el gate humano (D97).** Si la tercera iteración pasa el criterio automático, el reporte termina con **la orden exacta** que el dueño copia para jugar la instancia cliente cinco minutos con ventana (`tools/run_gate.ps1 ++ human=client`), lo que tiene que ver y sentir, y qué teclas. El gate no está aprobado hasta que el dueño juegue.

**E0. Volumen de evidencia — regla nueva, aplícala desde ya.** El revisor borró 70 archivos de volcado crudo (traces de 10 Hz, snapshots de bus y CSV por tick de corridas inválidas, preflights, manuales y experimentos): `docs/evidencia/M2-GATE` baja de 205 MB a 97 MB. Ninguno estaba citado por nombre en ningún `.md` — comprobado uno por uno. Vienen en el mismo commit que la revisión 06; **no los restaures**. La regla en adelante, y el principio es «la sonda se queda, el volcado se va» (las sondas están en `src/tooling/`, así que el crudo se regenera):

- **Siempre se commitean:** `summary.json`, `host.json`/`client.json`, `*_support_losses.json`, los logs y las capturas. Son pequeños y son la evidencia.
- **`*_ticks.csv`: solo de corridas que consumen una iteración D96** y del experimento de 300 s que justifica la siguiente decisión. De los experimentos de reducción, no.
- **`*_trace.json` y `*_bus_snapshots.json`: solo de iteraciones que consumen D96.** De todo lo demás, se generan, se usan y **no se commitean**.
- Si necesitas commitear un crudo fuera de esa regla, dilo en el reporte con el motivo.

**E. Registro.** Anota **D98** en `DECISIONS.md` como decisión del dueño citando la revisión 06, y actualiza `00_phase0_contract.md` y las tablas históricas con la fila v5 (las corridas 2 y 4 siguen siendo fallos válidos: en ambas la tripulante salió del casco).

## 3. BACKLOG, sin trabajo ahora

- **Empujón simétrico** (M3): impulso a la tripulante por contacto con carga rígida, también en anfitrión y un jugador.
- **Tope de corrección de réplica** relativo al bus, solo si el dueño siente los empujones por artefacto como injustos al jugar.
- Cobertura de la sonda de penetración en transiciones; `drop()`/`throw()` sin respuesta; validación con la réplica del anfitrión; ruido de `seat_test`.

**Reporte:** hashes; los tres arneses con `expected_tests`; la tabla A con rojo y verde por caso; la tabla del experimento de 300 s v5 con cada flanco (recuperado / no) y cada empujón (duración, desplazamiento); si procede, la tabla de la tercera iteración; y la orden para el dueño. Si algo de lo de arriba no cuadra con lo que ves, **dilo antes de tocarlo**: el revisor lleva cinco correcciones a su criterio y una a su propio diseño (D94) en esta tarea, y todas están escritas.
