# Comprobaciones previas del gate

Ninguna fila consume una iteración de D96: todas duran menos de 300 s.

**Muestreo:** nodo observador independiente, después de todos los nodos de física; `process_physics_priority=1000` y `process_priority=1000`, igual en ambas instancias.

| Corrida | Duración | Ciclos host / cliente | p99 host / cliente (m/tick) | Logs ERROR / WARNING host; cliente | Resultado |
|---|---:|---:|---:|---|---|
| preflight_01 | 20 s | 1 / 8 | 0.033363 / 0.296791 | 0 / 1; 0 / 1 | Inválida por duración |
| preflight_02 | 30 s | 13 / 12 | 0.155965 / 0.635351 | 0 / 0; 0 / 0 | Inválida por duración |
| preflight_03 | 45 s | 19 / 6 | 0.151111 / 1.684126 | 0 / 0; 0 / 0 | Inválida por duración y actividad |
| preflight_04 | 45 s | 19 / 6 | ver JSON / 0.235077 | 0 / 0; 0 / 0 | Inválida por duración y actividad |

La primera corrida detectó callbacks de integración en cuerpos congelados cinemáticos, cajas amarradas del anfitrión que no seguían al bus al cambiar su modo original, y un aviso de la cámara de persecución, que actualiza desde `_process`. Correcciones: separar callbacks del modo dinámico real de PhysicsServer3D; conservar STATIC en el anfitrión; desactivar la interpolación física de esa cámara en el guion del gate, que ya suaviza su movimiento.

En la segunda corrida los cuatro avisos de accesos inseguros se configuraron como errores durante todo el lanzamiento. Terminó con código 2 (inválida por sus 30 s), hijos 0/0, 13/12 ciclos y logs limpios. Mantiene fallos numéricos de D95 en deslizamiento, penetración y FPS. Los preflights 03/04 se explican en `04_timing_resolution.md`.

La prueba manual `05_raw/manual_01` duró 120 s, con anfitrión sin ventana y cliente visible. Se enviaron Escape, clic, W/S, movimiento de ratón y E mediante la ventana nativa. Captura `client_ready.png`: tripulante remota y cajas; `client_native_after_input.png`: vista tras esas acciones. No se completó un ciclo de carga humano (contadores cero); no acredita el gate humano de cinco minutos. Los dos logs terminaron sin ERROR ni WARNING.

Fuente de la instrumentación: [PhysicsServer3D.body_get_mode](https://docs.godotengine.org/en/stable/classes/class_physicsserver3d.html#class-physicsserver3d-method-body-get-mode). Consultada el 2026-09-16; motor ejecutado 4.7.2.
