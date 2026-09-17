# Prompt para Codex — M2-GATE ronda 5: la adopción de plataforma, y la última ronda de experimentos

Copiar desde `CONTEXTO:` hasta el final.

---

CONTEXTO: Proyecto "Ruta Frágil", rama `m2/gate-two-instances`, HEAD `5ea5b56`, 236 tests, árbol limpio salvo dos archivos del revisor sin trackear: `docs/revisiones/M2-GATE_revision_05.md` y `docs/planes/M2-GATE_ronda5_prompt_codex.md`. **Cométealos tal cual antes de empezar.** Lee la revisión entera: reproduce tus números dígito a dígito y contiene la verificación del mecanismo que queda.

## 1. Dónde estamos

- Tu diagnóstico es correcto y los tres arreglos son reales (0,42 m → 0; 97,56 m/s → 0; 1,50 m → 0). La causa es la carga, no la red; la hipótesis de las instantáneas queda descartada por tu experimento sin carga.
- **D96: dos fallos válidos, queda uno.** La corrida 4 cuenta. Pero se gastó sobre un experimento de 60 s que **ya tenía a la tripulante expulsada en el tick 3502** —el mismo tick y los mismos 3.494 ticks apoyados que la corrida— y el 97,06 % lo tapó porque la ventana acabó 1,65 s después. Mi precondición era un porcentaje y eso fue un error mío; el tuyo fue no mirar si la última de las cinco pérdidas se recuperaba. Las dos cosas quedan corregidas abajo.
- El experimento de 120 s sobre `1eeb635` da **87,65 %** y expulsión definitiva a los 105,6 s. **No hay nada sobre lo que gastar la tercera iteración.**

## 2. El mecanismo que queda, verificado en tus quince flancos

En **13 de las 15** pérdidas del experimento de 120 s, el tick anterior tiene dos contactos —suelo del bus y una caja— y **la velocidad de plataforma que adopta la tripulante es la de la caja**, que va más despacio que el suelo (déficit de 1,2 a 8,0 m/s; en el tick 495, suelo 18,55 y `Package_3` 12,34). Movida por una plataforma más lenta, retrocede 2–13 cm por tick respecto al bus y pierde el suelo. Es lo que apuntaste en el tick 3501 de la corrida 4, y se repite en todos.

Es una regla del motor: en `CharacterBody3D::_set_collision_direction()` el contacto de **pared** más profundo llama a `_set_platform_data()` y sobrescribe la plataforma que había puesto el suelo. Ya citaste el archivo; ahora hay dos preguntas y las dos se **miden**:

**(1) ¿Por qué una réplica escrita cada tick en el marco del bus reporta 2/3 de la velocidad del bus?** `Package_3` da razón **0,665** tres veces (ticks 495, 2847, 5679). `NetCargoReplica.advance()` escribe `bus.global_transform * interpolación_local` cada tick; el desplazamiento mundial debería ser el del bus. No lo es. Instrumenta, para los **tres ticks previos a cada flanco**: desplazamiento mundial por tick de cada réplica junto al del bus (`package_write_m` al lado de `bus_write_m`), la velocidad que reporta el contacto, y `get_platform_rid()` de la tripulante. Si hay un patrón de 2 de cada 3 ticks, lo vas a ver ahí.

**(2) ¿Debe una tripulante adoptar una caja como plataforma alguna vez?** El anfitrión también perdió el suelo 6 veces en 120 s por lo mismo, con cajas rígidas de verdad. El diseño no puede depender de que ninguna caja se mueva jamás respecto al suelo.

**Trampa, léela antes de tocar nada:** [Probable] `platform_floor_layers` / `platform_wall_layers` **no resuelven esto**. En `move_and_slide()`, si la plataforma actual (la caja) queda excluida por la máscara, `current_platform_velocity` se pone a **cero**; no vuelve al suelo. Estando en el suelo con la caja como plataforma, excluir la capa 2 le quitaría toda la velocidad del bus ese tick: 0,3 m de golpe. Confírmalo en `character_body_3d.cpp` de 4.7 y anótalo como hecho medido si es así.

## 3. El trabajo, en orden

**A. Banco determinista, sin red.** Extiende `run_write_order_probe.gd` (o una sonda hermana en `src/tooling/`): bus congelado reproduciendo la grabación, tripulante de pie o caminando por el pasillo, y **una caja cinemática al costado** escrita cada tick con una velocidad **deliberadamente inferior** a la del suelo (razón 0,665, como la medida). Tiene que reproducir la pérdida de apoyo **sin ventanas ni red**. Si no la reproduce, el mecanismo no es el que creemos y hay que decirlo antes de seguir.

**B. Sobre ese banco, mide dos candidatos y reporta los dos**, con la misma tabla (apoyo %, flancos, deslizamiento p99, ticks en el aire):
- **(a)** la réplica con velocidad **exacta** (arreglado lo que salga de la pregunta 1). Es un bug de replicación en cualquier caso y se arregla igual. Mide cuánto del fallo se lleva por sí solo.
- **(b) acarreo explícito**: la tripulante deja de usar la velocidad de plataforma del motor (las dos máscaras a 0 → siempre excluida → cero; `platform_on_leave` a `DO_NOTHING`) y **suma ella misma la velocidad del punto del bus** antes de `move_and_slide`. El bus es el único que la lleva, por construcción, toque lo que toque. Sigue siendo opción A. Hay que volver a medir sobre esto el hecho de T2.2 del apoyo en −0,5 m/s y los baches a 80 km/h de mi sonda (0 ticks en el aire de pie y caminando): si (b) rompe eso, no sirve.
- **(c)** que tripulante y carga no colisionen (máscara sin capa 2) **no lo implementes**: es una decisión de diseño del dueño. Si (a) y (b) no bastan, dilo y para.

**C. Penetración: la racha no cuenta el reposo.** En el anfitrión `Package_3` acumula 4.391 ticks a ≤ 2,55 cm de profundidad en el suelo: es una caja apoyada, no un atravesamiento (Jolt asienta los cuerpos hasta `penetration_slop`, 2 cm, por diseño). Emite el **histograma de profundidad** de la carga simulada del anfitrión y cuenta la racha **solo por encima de un umbral de reposo**, provisionalmente **3 cm**; propón otro si el histograma lo pide. La profundidad máxima (5 cm) se mantiene. Reemite la fila de penetración de las corridas 2 y 4 con el criterio corregido; el veredicto de ambas no cambia.

**D. La precondición para la tercera iteración, y es dura.** Antes de lanzar el gate: **un experimento de 300 s**, misma configuración exacta, en el que **ambas instancias** cumplan (i) apoyo ≥ 95 %, (ii) **apoyo en el último tick**, (iii) **ninguna pérdida de más de 30 ticks**. Si lo cumple, gasta la tercera iteración sobre ese commit sin tocar nada entre medias. Si no lo cumple, **no lances el gate**.

**E. Esta es la última ronda de experimentos.** Si la ronda termina sin un experimento de 300 s en verde según D, **para y repórtalo**: el plan de la opción B lo escribe el revisor, no tú, y no se arranca ninguna "reducción más". Está propuesto al dueño como acotación de D96 y pendiente de su palabra; hasta entonces actúa como si fuera firme.

**F. Plan:** actualiza D95 (umbral de reposo en penetración; precondición D) y D96 (la acotación de E, marcada como pendiente del dueño) en `M2-GATE_plan.md`, citando la revisión 05.

## 4. Deuda al BACKLOG, sin trabajo ahora

- `drop()`/`throw()` fallan en silencio si la caja no cabe, y el anfitrión valida `fits` en **su** mundo con la réplica de la tripulante del cliente hasta 1 m desplazada. Falta respuesta al jugador (M3) y validar en el marco del bus con la pose que envía el cliente.
- El error remoto (tripulante p95 ~1 m, bus 1,87 m) es la latencia de interpolación en metros (~85 ms a 22 m/s); escribe eso junto al número.
- `seat_test.gd` empuja `ERROR: CameraArbiter: no Camera3D in group 'eye_camera'` en cada corrida del arnés; ruido de fixture anterior a esta tarea.

**Reporte:** hashes; los tres arneses con `expected_tests`; la tabla del banco A con la pérdida reproducida; las tablas de (a) y (b) con los hechos de T2.2 y de los baches remedidos; el histograma de C; el resultado del experimento de 300 s de D con sus flancos (recuperada / no recuperada, cada uno); y, solo si D pasó, la tabla de la tercera iteración. Si algo de lo de arriba no cuadra con lo que ves, **dilo antes de tocarlo**: el revisor lleva cinco correcciones a su propio criterio en esta tarea y las cinco están escritas.
