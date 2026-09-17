# Revisión 04 — M2-GATE: primera iteración del gate

**Fecha:** 2026-09-16 · **Revisa:** Claude · **Revisado:** rama `m2/gate-two-instances`, HEAD `fefc4d8` (19 commits sobre `bc2323f`), 224 tests · **Pliego:** `docs/planes/M2-GATE_plan.md` (D91–D97) + `M2-GATE_ronda3b_prompt_codex.md`

## Veredicto: el fallo es REAL y cuenta como la primera iteración fallida de D96. Pero el motivo registrado no es el correcto, y dos de los tres motivos son culpa de mi criterio.

El gate no falló por *jitter*. Falló porque **la tripulante del cliente no va dentro del bus**. Ese número está en tu propia tabla y ninguno de los dos lo puso en primera línea:

| | Anfitrión | Cliente |
|---|---|---|
| Ticks **con apoyo en el bus** (corrida 2) | 17.921 / 18.000 (99,6 %) | **1.194 / 18.000 (6,6 %)** |
| Ticks con apoyo (corrida 3) | 17.897 / 18.000 (99,4 %) | **438 / 18.000 (2,4 %)** |

Y no es que "resbale": mientras está sin apoyo, su posición en el marco del bus tiene una **mediana de 73 m en x y 24 m en z**, con máximos de 139 y 102. Está a setenta metros del bus. El `slip p99 = 1,19 m` que hizo saltar el criterio no mide temblor: mide un autobús alejándose de una persona que se quedó atrás.

Eso explica lo demás sin necesidad de más hipótesis: los 10 ciclos del cliente frente a 118 del anfitrión (no puede agarrar nada porque no está a bordo), y lo que viste tú al jugar la ventana cliente, que "perdía el bus". Tu observación a ojo y los datos coinciden exactamente.

## Lo que verifiqué, y la línea de tiempo del fallo

Fui a tus CSV por tick, que son excelentes y sin ellos esto no se habría podido diagnosticar.

**La tripulante del cliente se despega cinco veces y a la quinta no vuelve:**

| Despegue | Tick | t | Velocidad del bus | ¿Vuelve? |
|---|---|---|---|---|
| 1 | 94 | 1,6 s | 16 km/h | sí, 19 ticks después |
| 2 | 622 | 10,4 s | 43 km/h | sí, 26 ticks |
| 3 | 1110 | 18,5 s | 70 km/h | sí, 2 ticks |
| 4 | 1239 | 20,6 s | 74 km/h | sí, 1 tick |
| 5 | **1243** | **20,7 s** | **74 km/h** | **no. Fin.** |

En cada uno **sube**, no cae: en el tick 94 su `y` local pasa de −0,60 a −0,28 (32 cm hacia arriba); en el 1243 de −0,60 a −0,36 en cinco ticks. Una vez en el aire no la acarrea nada, el bus avanza 0,34 m por tick por debajo, y a los pocos ticks está fuera del casco y se acabó.

**El control es demoledor:** en esos cinco ticks exactos, la tripulante del **anfitrión** está apoyada, a `y = −0,60`, con deslizamientos de 0,000 a 0,033 m. Mismo bus, mismo instante, mismo guion. El problema es enteramente del lado cliente.

**La réplica, en cambio, está sana.** Tus propias columnas lo dicen: `bus_write_m` tiene mediana 0,368 m por tick (lo que corresponde a 80 km/h), solo 7 ticks de 18.000 con escritura nula, y el retardo de reproducción se mantiene entre 33 y 100 ms. La interpolación no se atasca. El bus del cliente se mueve bien; lo que falla es que la tripulante no se queda encima.

## Lo que NO es, y lo descarté midiendo

Antes de opinar sobre la causa, extendí mi sonda determinista a la velocidad del gate: grabé la recta a fondo por la diagonal del suelo (la única de 269 m, la que permite pasar de 80 km/h) y la reproduje sobre el bus congelado e interpolado, con la tripulante **de pie y caminando**, en las dos colocaciones de escritura:

| | deslizamiento p99 | máx | ticks en el aire | ¿expulsada? |
|---|---|---|---|---|
| de pie | 0,0081–0,0092 | 0,012 | **0 / 600** | **no** |
| caminando | 0,0680 | 0,073 | **0 / 600** | **no** |

**A 80 km/h, en recta, una réplica cinemática interpolada acarrea perfectamente a la tripulante, ande o esté quieta.** Así que:

- **No es la velocidad.** Mi réplica llega a la velocidad del gate y no la despega. Y el primer despegue tuyo ocurre a **16 km/h**.
- **No es el giro.** Calculé el cambio de rumbo del bus por tick: la mediana de la corrida es 0,001°, el p95 1,17°. En el tick 94 el giro es **exactamente 0,000°** (va recto por el carril x=30) y aun así la expulsa; en el 1243 es 0,18°, por debajo del p95.
- **No es la carga, al menos no en el primer despegue.** Miré tu `client_trace.json`: en el tick 94 no hay ninguna caja a menos de 1,5 m de ella. (En el 1243 sí hay una a 0,53 m, así que para el último despegue la carga sigue siendo sospechosa, pero no puede ser la explicación general.)

Lo que queda por descartar, y no lo puedo hacer con tus datos actuales: **la irregularidad real de llegada de las instantáneas** (tu retardo oscila entre 33 y 100 ms, mientras mi banco tiene cadencia perfecta) y **la interacción con las réplicas de carga a 20 Hz**. Ahí es donde hay que apuntar.

## Tres correcciones a MI criterio, porque dos de los tres motivos de fallo que registraste son míos

1. **La penetración se juzga sobre cuerpos simulados localmente, no sobre las réplicas remotas.** El anfitrión aparece fallando por penetración de `crew/1320164969` (0,41 m durante 164 ticks), que es **la réplica de la tripulante del cliente**: un cuerpo interpolado, no simulado, que por construcción va a atravesar geometría. Juzgar eso es juzgar un dibujo. Mide penetración solo de lo que esa instancia simula: su propia tripulante y, en el anfitrión, la carga con autoridad.
2. **Los fps con vsync activado no se pueden medir.** Registras `vsync_mode 1`, `max_fps 120` y "74,9 % de fotogramas por debajo de 60". Con la sincronía vertical puesta el motor no puede pasar del refresco del monitor, así que ese porcentaje no mide falta de holgura: mide el tope. **Repite con vsync desactivado y `max_fps = 0`**, y entonces el percentil 1 significará algo. Hasta entonces, ese motivo de fallo no cuenta.
3. **El p99 de deslizamiento no es una medida de jitter si la tripulante no va a bordo.** Necesita una precondición de validez, y la escribo ahora: **si la tripulante local tiene apoyo en el bus en menos del 95 % de los ticks, la corrida no "falla el criterio de deslizamiento": falla por "la tripulante no puede viajar", que es más grave, y el número de deslizamiento no se cita como jitter.** El apoyo en el bus pasa a ser criterio de primera clase, por encima del deslizamiento, y va en la primera fila de la tabla.

Con eso, de los siete motivos que registraste queda **uno**, y es el que importa: **la tripulante del cliente no viaja en el bus**.

## Lo que hay que reconocerte

- **Los 80 km/h están conseguidos.** Velocidades de entrada de 80,8 a 82,7 km/h en doce vueltas. En la revisión 01 escribí que hacían falta 144 m de carrerilla y que el carril solo ofrecía 102; resolviste el trazado con un retorno exterior sin teletransportar y el gate corre a la velocidad que pide el maestro. Eso cierra una pregunta que llevaba abierta tres revisiones.
- **El punto de muestreo está declarado e implementado como pedí**, con un observador independiente que no escribe nada, misma prioridad en las dos instancias, y dicho en la evidencia. Es lo que permitió que esta revisión se pudiera hacer.
- **Los CSV por tick son lo que ha permitido diagnosticar esto.** Sin `bus_support`, `bus_write_m`, `source_s` y `playback_s` yo habría tenido que adivinar. Esa instrumentación vale más que la tabla resumen.
- **Reportaste lo que viste con la ventana** ("perdía el bus") aunque no cuadrara con un veredicto limpio, y coincide exactamente con lo que dicen los datos.
- **No forzaste un aprobado.** Con tres corridas y un resultado rojo, lo fácil era tocar un umbral.

## Qué hacer ahora, y lo que NO hay que hacer

**No corras otra iteración del gate.** D96 da tres y llevas una; gastar las otras dos sobre la misma causa sin diagnosticar sería tirarlas. La siguiente corrida tiene que ser **un experimento de reducción**, no un veredicto.

Lo que hace falta instrumentar, y es barato porque ya tienes el observador:

1. **En cada pérdida de apoyo, registra el tick anterior completo:** sobre qué cuerpo estaba apoyada (`get_platform_rid()` o el colisionador del último `get_slide_collision()`), su velocidad, el desplazamiento escrito del bus ese tick, si llegó una instantánea tarde, y la distancia a la caja más cercana. Cinco campos, y el primer despegue te dice la causa.
2. **Corre el gate con la carga desactivada** (`cargo_spawn = false` en las dos instancias) durante 60 s. Si la tripulante del cliente deja de despegarse, la causa son las réplicas de carga a 20 Hz y ya sabes dónde mirar. Si se sigue despegando, es la llegada irregular de instantáneas, y entonces la prueba siguiente es inyectar la irregularidad real en mi banco determinista.
3. Con la causa en la mano, arréglala y **entonces** gasta la segunda iteración.

Y para la tabla del gate: aplica las tres correcciones de arriba y vuelve a emitir el resultado de la corrida 2 con los motivos correctos. El veredicto no cambia —sigue siendo un fallo válido— pero el registro tiene que decir por qué falló de verdad, porque es lo que va a leer quien decida la opción B.

**Dueño:** nada que jugar todavía, y conviene que lo sepas: lo que viste al perder el bus no era cosa tuya ni del mando. Es el defecto, y está localizado.
