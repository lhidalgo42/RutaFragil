# Continuidad del receptor y alcance remoto

La corrida 1, commit cd76dc5, duró 300 s con ambos procesos en ventana.
Fue **inválida**, porque el cliente completó 5 ciclos y perdió el bus.
No consume un fallo de D96. Su tabla y crudos se conservan íntegros.
El p99 incluye la separación posterior a la caída, no solo movimiento interior.

El test determinista de entregas 1/3 ticks falló con código 100: para una
trayectoria uniforme de 18,5 m/s el receptor avanzaba 0 y 0,616667 m/tick,
en vez de 0,308333. La cola con tiempos del origen y reloj continuo pasa
ese caso, entregas en ráfaga y rechazo de paquetes viejos. Margen declarado:
dos snapshots, 66,7 ms. Si la pérdida agota la cola se mantiene la última
pose; no se promete continuidad bajo pérdidas arbitrariamente largas.

| Prueba corta | Escritura bus | Duración | Ciclos host/cliente | p99 host/cliente (m/tick) | Ticks cliente sin apoyo |
|---|---|---:|---:|---:|---:|
| preflight_03 | physics_frame | 45 s | 19/6 | 0,151111 / 1,684126 | 1667 |
| preflight_04 | nodo, prioridad física −100 | 45 s | 19/6 | ver summary.json / 0,235077 | 24 |

**Muestreo de ambas filas:** observador dedicado que solo lee, después de
todos los nodos, process_physics_priority=1000 y process_priority=1000.
Cada proceso conserva CSV por tick. Ninguna prueba corta consume D96.
No son trayectorias idénticas ni establecen una ley causal del motor:
g2.1 continúa retirado. Se elige escritura a −100 para la siguiente corrida;
carga pasa a −90 para utilizar esa misma pose del bus antes de Crew.

En preflight_04 el cliente permaneció dentro, pero el anfitrión rechazaba
interacciones por comparar su bus actual con una mano remota retrasada en
coordenadas de mundo. El snapshot de Crew conserva también el marco del bus
de origen: el validador reconstruye la mano en ese marco, manteniendo el
alcance original. La representación remota conserva su transformada de mundo.
El test de alcance dio 100 antes y 0 después. La mano fuera del bus sigue en
coordenadas de mundo.

Prueba adicional de carga amarrada cliente: observador postnodos guarda el
objetivo; el siguiente physics_frame lee el cuerpo físico contra ese objetivo
del paso anterior. Error nodo y cuerpo <0,002 m, ángulo <0,001 rad; cero
integración dinámica. No se encontró un collider abandonado en el mundo.

Logs: `04_bus_timing_red.log`, `04_bus_timing_green_2.log`,
`02_cargo_reach_red.log`, `02_cargo_reach_green.log`,
`02_cargo_physical_transform.log`. `04_bus_timing_green.log` conserva un fallo
intermedio del CSV (array sin tipo en una rama), corregido y vuelto a probar.

Las corridas 1 y 2 conservan VSync del proyecto y max_fps=120. La corrida 3
y manual_02 usan VSync desactivado, declarado en sus JSON; max_fps sigue en
120. Los FPS no se corrigen ni se redondean para pasar 60. La región histórica de
velocidades de baches es x=[24,36], z=[2,46]; no cubre los últimos metros de
la última rampa, aunque la ruta sí la cruza entera. Los errores remotos se
comparan al mismo UTC, sin desplazar el reloj para descontar latencia.
