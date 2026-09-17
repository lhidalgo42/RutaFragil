# 21 — El estímulo del banco `slow_encounter`: qué parte es real y qué parte es mía

**Fecha:** 2026-09-17 · **Autor:** revisor (relevo del ejecutor, que agotó su presupuesto) · Motor `4.7.2.stable.official.ed1daf0bf`.

El ejecutor reportó que `slow_encounter` **sigue fallando** después del arreglo de inercia: la tripulante sale del casco en el tick 370, pierde apoyo en el 376 y aterriza en el `Ground` en el 391, con 695 ticks fuera. Y se negó a darlo por verde. Tenía razón en no darlo por verde. Lo que sigue es si ese caso debe bloquear el gate, y la respuesta corrige mi propio pliego.

## Lo que medí

Recorrí **todos** los volcados de flancos conservados (20 ficheros, todas las rondas) y extraje cada muestra en la que la tripulante toca **a la vez** el suelo del bus y una caja. Para cada una, la razón entre la velocidad de contacto de la caja y la del suelo:

| | razón caja/suelo |
|---|---|
| Muestras con contacto simultáneo | **77** |
| Mínimo | 0,000 |
| Mediana | **0,918** |
| Máximo | 14,961 |
| Por debajo de 0,665 (el estímulo del banco) | **8 de 77** |

Las ocho más lentas:

| Razón | Corrida | Tick | Suelo | Caja |
|---:|---|---:|---:|---:|
| 0,000 | `iteration_4` cliente | 570 | 18,32 | 0,00 |
| 0,000 | `iteration_4` cliente | 3485 | 22,13 | 0,00 |
| 0,000 | `r4_transition_fix_01` cliente | 493 | 18,53 | 0,00 |
| 0,000 | `r4_transition_fix_01` cliente | 1414 | 23,57 | 0,00 |
| 0,619 | `r4_free_wait_fix_01` **anfitrión** | 6341 | 15,46 | 9,56 |
| 0,662 | `r5_motion_baseline_01` cliente | 494 | 18,58 | 12,30 |
| 0,663 | `r5_motion_baseline_01` cliente | 496 | 18,63 | 12,35 |

## Esto corrige lo que yo suponía

Iba a escribir que el banco usa un estímulo mucho peor que la realidad. **Es falso en magnitud.** Los cuatro ceros son las cajas congeladas de antes de los arreglos, y las muestras de `r5_motion_baseline_01` —que es **posterior** a los tres arreglos de la ronda 4— siguen dando 0,662 y 0,663. El ejecutor no se sacó el 0,665 de la manga: lo calibró sobre el peor caso medido con el código ya arreglado. Bien hecho.

**Donde el banco sí se separa de la realidad es en la DURACIÓN.** El déficit real es transitorio: la corrección local de 0,3138 m se reparte en tres ticks (494, 495, 496; en el 496 el nodo ya escribe casi la velocidad del bus y solo el contacto va un tick por detrás). El banco impone la razón 0,665 **de forma permanente** desde el índice 350 hasta el final.

Y se ve en el resultado: en `r5_motion_baseline_01`, 120 s con el déficit real, hay **12 empujones y los doce se recuperan en 1, 2 o 3 ticks**, con 99,74 % de apoyo. Ninguno la saca del casco. En el banco permanente, un solo empujón la barre 695 ticks.

## La corrección al pliego, y es mía

Pedir «0 ticks fuera del casco» bajo un déficit **permanente** es pedir que la carga no pueda desplazarla nunca, es decir, **inmunidad** — exactamente lo que D98 dice que no se construye. Con una cinta transportadora bajo los pies durante 700 ticks, cualquier personaje acaba fuera por el hueco de la puerta, y eso no es un defecto del acarreo: es la consecuencia de que el empujón sea juego.

Por tanto:

1. **El caso `slow_encounter` con déficit permanente deja de ser criterio de paso.** Se conserva como **límite declarado**, con su número (695 ticks fuera, aterriza en `Ground` en el 391), porque describe algo verdadero: sostenido el tiempo suficiente, un empujón te saca del bus.
2. **Se sustituye por `slow_transient`:** el mismo déficit de 0,665 aplicado durante **3 ticks**, que es la ventana de corrección medida. Exigencia: 0 ticks fuera del casco y recuperación ≤ 45 ticks. Ese sí es el fenómeno real.
3. **El juez de verdad es la corrida de 300 s**, con los déficits que la red produce sola.

Es la séptima corrección a un criterio mío en esta tarea. La diferencia con las seis anteriores es que esta no la encontró el ejecutor: la encontró su negativa a marcar en verde algo que no lo estaba, y después la medición.

## Pregunta que queda para el dueño, y no la decido yo

Con D98, **una caja puede empujarte fuera del bus si el empujón dura lo suficiente**. En lo medido hasta hoy no ocurre (los doce empujones reales duran 1–3 ticks), pero el banco demuestra que es posible. Si en la corrida de 300 s aparece una salida del casco causada por un empujón, hay dos lecturas legítimas —«es parte del juego, que se agarre» o «te puede empujar, pero nunca fuera»— y la elección es del dueño, no del revisor.
