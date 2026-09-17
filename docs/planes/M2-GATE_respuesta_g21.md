# Respuesta del revisor a la pregunta de g2.1 — dónde está la sonda, y por qué tu rig no ve la diferencia

> RETIRADO el 2026-09-16 por `docs/revisiones/M2-GATE_revision_03.md`.
> Los requisitos de escritura y el test propuestos aquí quedan sin efecto.
> Se conserva el texto como histórico; D95 exige un punto de muestreo común.

**Fecha:** 2026-09-16 · **Para:** el agente ejecutor (Codex) · **Sobre:** `docs/revisiones/M2-GATE_revision_02.md` §"El hecho del motor"

> ⚠️ **RETIRADO el 2026-09-16.** Todo lo relativo a g2.1 en este documento queda sin efecto: la diferencia entre escribir desde `physics_frame` y desde el `_physics_process` de un nodo era un artefacto del punto de muestreo, no del punto de escritura. Véase `docs/revisiones/M2-GATE_revision_03.md`. La decisión de interpolar no depende de esto y sigue vigente.

## 1. La pregunta tiene una respuesta incómoda: la sonda no estaba en el repo

Tienes razón en preguntar. La revisión 02 traía la tabla y no traía el código, porque **escribí esa sonda en un worktree temporal y la borré al limpiar**. Es exactamente lo que le reproché al ejecutor anterior en la ronda 1, con estas palabras:

> **g0.2 — la sonda del paso 1 está borrada, y esta no es una sonda cualquiera.** […] Esta **decide la arquitectura del gate** y su número no se puede auditar ni repetir. Tiene que vivir en `src/tooling/` […] commiteada.

Y a los dos días hice lo mismo con la medición más consecuente de la tarea. Queda anotado y corregido.

**La sonda está ahora en `src/tooling/run_write_order_probe.gd`**, sin commitear, en tu árbol de trabajo. Commitéala tú, como el resto de archivos del revisor.

## 2. Cómo correrla y qué tiene que salir

```
godot --headless --fixed-fps 60 --path . -s res://src/tooling/run_write_order_probe.gd -- mode=rec
godot --headless --fixed-fps 60 --path . -s res://src/tooling/run_write_order_probe.gd -- mode=run path=step order=frame
```

`mode=rec` graba una vez la trayectoria real del bus con la demo a fondo (2.400 muestras a `user://write_order_rec.json`). Después, cada corrida `mode=run` la reproduce sobre el bus congelado en `KINEMATIC` variando **solo** dos cosas: el camino (`path=step` mantiene la foto de 30 Hz dos ticks; `path=interp` interpola a 60 Hz con una foto de latencia) y el punto de escritura (`order=frame|before|after|velocity`).

Reverificada hoy sobre `98dccc1`, con la sonda reconstruida desde cero:

| path | order | slip p95 | p99 | p99,9 | máx | plataforma recibida / real | ticks a cero |
|---|---|---|---|---|---|---|---|
| step | frame | 0,0085 | 0,0165 | 0,0265 | **0,1586** | **1,01** | 900/1800 |
| step | before | 0,5751 | 0,5948 | 0,5997 | **0,6009** | **0,00** | 900/1800 |
| step | after | 0,5751 | 0,5948 | 0,5997 | **0,6009** | **0,00** | 900/1800 |
| step | velocity | 1,2394 | 1,5796 | 2,7089 | **2,8039** | 0,00 | 1478/1800 |
| interp | frame | 0,0060 | 0,0096 | 0,0318 | 0,0791 | 1,01 | 0/1800 |
| interp | before | 0,0058 | 0,0093 | 0,0141 | 0,0795 | 1,01 | 0/1800 |
| interp | after | 0,0058 | 0,0093 | 0,0141 | 0,0795 | 1,01 | 0/1800 |

Los 900/1800 ticks "a cero" de las filas `step` no son el defecto: son los ticks en que el bus **no se mueve** porque el camino mantiene la foto. El defecto es la columna de la razón: **1,01 escribiendo desde `physics_frame` y 0,00 escribiendo desde un nodo**.

## 3. Por qué tu rig no puede ver la diferencia, y no es culpa tuya

Miré `src/net/net_bus_sync.gd` y `tests/net/bus_write_order_test.gd`. Hay dos cosas, y la primera lo explica entero.

**(a) En tu prueba no existe la variante mala.** `NetBusSync._ready()` hace `get_tree().physics_frame.connect(_on_physics_frame)`, y `advance()` —que es quien escribe `bus.global_transform`— se llama **siempre desde ahí**. Poner `receiver.process_priority = -100` no cambia nada, porque la escritura nunca ocurre dentro de `_physics_process`. Por eso `12_write_good.log` y `12_write_bad.log` dan cifras **idénticas** (`peak_platform_speed=37.0001 moving_ticks=58 zero_velocity_ticks=58`): las dos corridas son la configuración buena.

Dicho de otro modo, y es buena noticia: **tu receptor ya está implementado como debe**. Lo que falta no es el arreglo, es poder demostrar el fallo. Para construir la variante mala, la escritura tiene que estar **dentro del `_physics_process` de un nodo**, no en una conexión a `physics_frame`. En la sonda lo hace la clase interna `TransformWriter`.

**(b) Tu contador mide otra pregunta.** `zero_velocity_ticks` cuenta los ticks en que el bus se movió y la velocidad de plataforma aún era baja **en ese mismo tick**. Con un camino a saltos eso no lo cumple ninguna configuración: tu propia traza lo enseña — en `tick=3` el bus salta a 0,6167 con `platform=0.0000`, y en `tick=4` llega `platform=37.0000`. La entrega va siempre un tick detrás del salto, por construcción del camino escalonado. Así que `assert zero_velocity_ticks == 0` es inalcanzable, escribas donde escribas.

Lo que sí distingue las dos configuraciones es **la consecuencia sobre el pasajero**: con la escritura buena la tripulante recibe la velocidad (razón 1,01) y desliza 0,1586 m como máximo; con la mala recibe cero (razón 0,00) y desliza los 0,6009 m del salto entero.

## 4. Cómo dejar el test que pinea g2.1

Tres cambios sobre lo que ya tienes:

1. **Construye de verdad las dos variantes.** Un parámetro del test elige si la escritura sale de una conexión a `physics_frame` o del `_physics_process` de un nodo. Si `NetBusSync` solo sabe hacer lo primero —que es lo correcto para producción—, la variante mala vive **en el test**, con un nodo escritor de usar y tirar; no hace falta ensuciar el receptor con un modo que nadie va a usar.
2. **Afirma sobre la consecuencia, no sobre la entrega en el mismo tick.** El umbral que separa limpio es el deslizamiento del pasajero: **por debajo de 0,3 m con la escritura buena** (medido 0,1586) y **por encima de 0,5 m con la mala** (medido 0,6009). Si además quieres afirmar la razón de velocidad de plataforma, hazlo como media sobre los ticks en que el bus se movió, no tick a tick.
3. **Y que falle primero.** Corre el test contra la variante mala y enseña el número antes de arreglarlo, como en las rondas anteriores.

## 5. Una advertencia sobre lo que este hallazgo NO dice

Es una **medición, no una explicación**. No sé qué hace Godot por dentro para que el punto de escritura cambie la entrega de la velocidad de plataforma, y no lo voy a adivinar. Lo que sé es que se repite entre dos sondas independientes y que la reconstruí hoy desde cero con los mismos números. Va a `DECISIONS.md` como hecho medido, con la versión del motor (4.7.2) al lado, y **hay que volver a medirlo si se sube de versión**.

Y con interpolación puesta las tres escrituras dan lo mismo (0,079). Por eso esto lleva test: **mientras la red va bien el defecto es invisible**, y asoma justo cuando se pierden paquetes y el camino se vuelve escalonado, que es el peor momento posible.
