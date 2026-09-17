# Prompt para Codex — M2-GATE ronda 4: diagnosticar por qué la tripulante del cliente no viaja en el bus

Copiar desde `CONTEXTO:` hasta el final.

---

CONTEXTO: Proyecto "Ruta Frágil", rama `m2/gate-two-instances`, HEAD `fefc4d8`, 224 tests, árbol limpio salvo `docs/revisiones/M2-GATE_revision_04.md` sin trackear. **Cometéalo tal cual antes de empezar.** Lee esa revisión entera: contiene la reproducción independiente de tus datos y la corrección de tres criterios míos.

## 1. Tu iteración 2 cuenta como fallo válido de D96, pero el motivo que registraste no es el verdadero

Reproduje tus CSV por tick. El gate no falló por jitter de deslizamiento. Falló por esto:

| | Anfitrión | Cliente |
|---|---|---|
| Ticks con apoyo en el bus (corrida 2) | 17.921 / 18.000 (99,6 %) | **1.194 / 18.000 (6,6 %)** |
| Ticks con apoyo en el bus (corrida 3) | 17.897 / 18.000 (99,4 %) | **438 / 18.000 (2,4 %)** |

**La tripulante del cliente no va dentro del bus el 93 % de la corrida.** Mientras está sin apoyo, la mediana de su posición en el marco del bus es 73 m en x y 24 m en z, con máximos de 139 y 102. Tu `slip p99 = 1,19 m` no mide temblor: mide el bus alejándose de alguien que se quedó atrás. Y explica sin más hipótesis tus 10 ciclos del cliente frente a 118 del anfitrión, y lo que vio el dueño al jugar la ventana cliente ("perdía el bus").

Se despega cinco veces —ticks 94, 622, 1110, 1239 y 1243— y a la quinta no vuelve. En cada una **sube** (en el tick 94 su `y` local pasa de −0,60 a −0,28). En esos mismos cinco ticks, la tripulante del **anfitrión** está apoyada a `y = −0,60` con deslizamientos de 0,000 a 0,033. Mismo bus, mismo instante.

La réplica del bus está sana: `bus_write_m` mediana 0,368 m/tick, solo 7 ticks de 18.000 con escritura nula, retardo de reproducción entre 33 y 100 ms.

## 2. Tres correcciones a MI criterio; dos de tus motivos de fallo eran míos

1. **La penetración se juzga solo sobre cuerpos que esa instancia simula.** El anfitrión aparecía fallando por `crew/1320164969`, que es la réplica interpolada de la tripulante del cliente. Juzgar penetración de un cuerpo que no se simula es juzgar un dibujo. Excluye réplicas remotas del criterio de penetración.
2. **Los fps con vsync puesto no se pueden medir.** Con `vsync_mode 1` y `max_fps 120`, ese "74,9 % por debajo de 60" mide el tope del monitor, no falta de holgura. **Corre con vsync desactivado y `max_fps = 0`.** Hasta entonces ese motivo no cuenta.
3. **Nuevo criterio, por encima del deslizamiento:** si la tripulante local tiene apoyo en el bus en **menos del 95 % de los ticks**, la corrida falla por *"la tripulante no puede viajar"* y el número de deslizamiento **no se cita como jitter**. Va en la primera fila de la tabla del gate, antes que el p99. Anótalo en D95.

Aplicadas las tres, de tus siete motivos queda uno, y es el correcto.

## 3. Lo que NO hay que hacer: otra iteración del gate

D96 da tres y llevas una. Gastar las otras dos sobre una causa sin diagnosticar es tirarlas. **La siguiente corrida es un experimento de reducción, no un veredicto**, y no consume iteración.

Ya descarté tres candidatos midiendo, para que no los repitas:

- **No es la velocidad.** Extendí mi sonda determinista a la velocidad del gate (recta a fondo por la diagonal de 269 m, reproducida sobre el bus congelado e interpolado): de pie da p99 0,009 y caminando 0,068, con **0 de 600 ticks en el aire** y nadie expulsado. Y tu primer despegue ocurre a 16 km/h.
- **No es el giro.** El cambio de rumbo del bus tiene mediana 0,001°/tick y p95 1,17°. En el tick 94 es **exactamente 0,000°** (recto por el carril) y aun así la expulsa; en el 1243 es 0,18°.
- **No es la carga en el primer despegue.** En el tick 94 no hay ninguna caja a menos de 1,5 m de ella. (En el 1243 sí hay una a 0,53 m, así que para el último despegue la carga sigue siendo sospechosa.)

## 4. El experimento, en tres pasos y corto

**Paso 1 — instrumenta la pérdida de apoyo.** Es barato porque el observador `GateMetrics` ya existe. Cuando `has_bus_support` pase de verdadero a falso, vuelca **el tick anterior completo**: sobre qué cuerpo estaba apoyada (`get_platform_rid()` o el colisionador del último `get_slide_collision()`), su velocidad lineal, `bus_write_m` de ese tick, si llegó instantánea ese tick y con cuánto retardo, y la distancia a la caja más cercana. Cinco campos. El primer despegue te dice la causa.

**Paso 2 — corre 60 s con la carga desactivada** en las dos instancias, con vsync off. Solo hace falta ver si la tripulante del cliente se queda a bordo.
- Si **deja de despegarse**: la causa son las réplicas de carga a 20 Hz. Mira cómo se resuelven las colisiones entre la tripulante simulada y cajas cinemáticas interpoladas.
- Si **se sigue despegando**: la causa está en la llegada de instantáneas del bus. Entonces el paso siguiente es inyectar la irregularidad real que registraste (33–100 ms, no cadencia perfecta) en un banco determinista y reproducir el despegue ahí, donde se puede iterar sin dos ventanas.

**Paso 3 — con la causa en la mano, arréglala, y ENTONCES gasta la iteración 2.**

## 5. Y de paso

Vuelve a emitir la tabla de la corrida 2 con los motivos corregidos según §2. El veredicto no cambia —sigue siendo un fallo válido de D96— pero el registro tiene que decir por qué falló de verdad, porque es lo que va a leer quien decida si se activa la opción B.

**Reporte:** hashes, los tres códigos de salida del arnés con `expected_tests`, el volcado del primer despegue del paso 1, el resultado del paso 2 con su log, tu diagnóstico, y la tabla de la corrida 2 reemitida. Si algo de lo que digo arriba no cuadra con lo que ves en tu árbol, **dilo antes de tocarlo**: van cuatro veces que el revisor se equivoca en esta tarea y las cuatro las ha escrito él mismo.
