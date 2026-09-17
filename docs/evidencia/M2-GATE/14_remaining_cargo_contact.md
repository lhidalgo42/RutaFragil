# Pérdida restante — después del segundo fallo válido

La [corrida 4](04_gate_iteration_4.md), código `19836c7`, es el segundo fallo
válido de D96. Los ciclos fueron 120 / 25. No se consumió un tercer intento.
No se activa la opción B ni se implementa un interior alternativo.

Muestreo: `GateMetrics`, observador independiente después de los nodos,
prioridades de proceso y física 1000, igual en las dos instancias.

| Tick cliente | Observación |
|---|---|
| 3483 | z local 0,728 m; aún transportada |
| 3485–3486 | Package_2 conserva idéntica pose mundial y velocidad de contacto ≈0; Floor avanza a 22,03 m/s |
| 3486 | Pierde apoyo entre contactos laterales de Package_2 y Stretcher |
| 3488 | Recupera apoyo en z local 2,475 m, ya desplazada hacia atrás |
| 3501 | Contacta Floor, pero la plataforma recibida coincide con Package_3: 13,55 m/s frente a 19,47 del suelo |
| 3502 | Solo contacto lateral con Package_3, 10,71 m/s; pérdida definitiva |
| 3507 | z local 3,921 m, fuera del extremo del casco |

Fuentes: [CSV](04_raw/iteration_4/client_ticks.csv) y
[flancos completos](04_raw/iteration_4/client_support_losses.json).
El bus continúa escribiendo, con margen fuente−reproducción usada de 50–67 ms.
La caja ya no presenta el pico de liberación de 97 m/s que corrige `19836c7`.

El banco adicional demuestra otro defecto: `apply_state` borraba el buffer
de la caja y `advance` no actualizaba su pose hasta recibir una instantánea.
Una réplica FREE congelada podía quedarse fija en mundo mientras el bus se
alejaba. [Antes](13_free_wait_red.log): código 100, desfase físico y nodal
**1,499883 m**. [Después](13_free_wait_green.log): 63 tests de red, código 0.

`1eeb635` conserva la pose local confirmada durante esa espera para las cajas
que están dentro del bus. No predice física ni altera autoridad. Un test
separado conserva la espera en coordenadas mundiales de una caja exterior;
no vuelve a arrastrarla con el bus. La primera instantánea normal sustituye
esta pose inicial.

La contribución de los contactos laterales aún requiere una reducción
independiente: suelo móvil, caja cinemática lateral y tripulante. La selección
de plataforma observada puede divergir del cuerpo Floor que también figura
en los contactos; no se atribuye exclusivamente al hueco de buffer sin
medirlo. La [implementación oficial de CharacterBody3D 4.7](https://raw.githubusercontent.com/godotengine/godot/4.7/scene/3d/physics/character_body_3d.cpp)
actualiza datos de plataforma desde determinadas colisiones de pared.

Los primeros 60 s de los dos ensayos no son una trayectoria idéntica: difieren
14 bits de apoyo y hasta 1,773 m de posición local. Compartir el último flanco
3502 y el total 3494 apoyados no demuestra una secuencia causal idéntica.

También sigue abierto el criterio de duración de penetración: en anfitrión,
Package_3 acumula una racha de 4391 ticks (profundidad máxima de ese cuerpo
0,025533 m), aunque su propia tripulante conserva 99,988889 % de apoyo. Los
umbrales no se han relajado y la carga dinámica del anfitrión sí se juzga.

Resultado del experimento posterior de **120 s**, `1eeb635`:
[datos y logs](13_raw/r4_free_wait_fix_01/summary.json), salida 0, sin consumo D96.
Anfitrión: 7161/7200 ticks de apoyo (**99,458333 %**), 46 ciclos.
Cliente: 6311/7200 (**87,652778 %**), 44 ciclos. Ambos logs 0 ERROR/0 WARNING.
El cliente completa interacciones durante el recorrido, pero no alcanza95 %;
no se presenta el arreglo como solución completa del acarreo. No se ejecuta
un tercer gate sobre este incumplimiento ya medido.

El siguiente banco pendiente debe conservar todas las colisiones: suelo móvil
con velocidad conocida, caja cinemática al costado con distinta velocidad y
tripulante apoyada. Registrar plataforma seleccionada, contacto de suelo y
traslado real antes de cambiar movimiento o capas. No se elimina la colisión
con la carga ni se modifica el umbral para obtener un resultado verde.
