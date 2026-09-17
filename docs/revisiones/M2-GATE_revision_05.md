# Revisión 05 — M2-GATE ronda 4: diagnóstico, tres arreglos y el segundo fallo válido

**Fecha:** 2026-09-16 · **Revisa:** Claude · **Revisado:** rama `m2/gate-two-instances`, HEAD `5ea5b56` (8 commits sobre `fefc4d8`; fuentes finales en `1eeb635`), 236 tests · **`main`** = `origin/main` = `2b16e99`, intacto · **Pliego:** `M2-GATE_plan.md` D91–D97 + `M2-GATE_ronda4_prompt_codex.md`

## Veredicto: el diagnóstico es correcto, los tres arreglos son reales, y la tripulante del cliente sigue sin poder viajar. D96 lleva dos fallos válidos y queda uno.

Lo que se pedía en la ronda 4 era **encontrar la causa sin gastar iteraciones**. Se encontró: **es la carga**, no la red. Sin cajas, las dos instancias van al 100 % durante 60 s; con cajas pero sin interacciones, 100/99,9 %; con ciclos de agarre y suelta, el cliente cae al 12 %. Eso descarta de un golpe la hipótesis que yo tenía más arriba en la lista —la irregularidad de llegada de instantáneas— y la deja escrita como descartada. Bien.

De ahí salieron **tres defectos medidos, cada uno con su prueba roja y verde**, y los tres son de verdad:

| Defecto | Roja | Verde |
|---|---|---|
| Soltar colocaba la caja **dentro de la cápsula** de la tripulante (la consulta omitía la capa 3 y el fallback soltaba en los pies sin comprobar volumen) | la tripulante sube **0,4196 m** | 0 m |
| La transición de estado de una réplica cinemática se interpretaba como un paso físico mano→suelo | velocidad fabricada **97,56 m/s** | 0 |
| Una réplica recién FREE se quedaba **fija en el mundo** hasta su primera pose, con el bus alejándose a 22 m/s | desfase **1,4999 m** | 0 |

El primero explica exactamente lo que yo vi en la revisión 04 y no supe atribuir: la subida de 0,32 m en el tick 89 con la caja como único contacto y 10 cm de solapamiento. El tercero es el que mató la corrida 4: en el tick 3485 `Package_2` tiene velocidad de contacto **0,00** mientras el suelo del bus avanza a **22,03 m/s**. Un obstáculo parado dentro de un bus a 80 km/h.

Y aun así: **el experimento de 120 s sobre `1eeb635` da 87,65 % de apoyo cliente, con expulsión definitiva a los 105,6 s.** El gate sigue sin poder correrse.

## Reproducción

| Qué | Ellos | Yo | |
|---|---|---|---|
| Arnés PowerShell | 0, 236/236, red pass | **0, 236/236, red 1+3 pass, desviación 0,000 m** | ✔ |
| Corrida 4, apoyo cliente / anfitrión | 3.494 / 17.998 de 18.000 | **3.494 / 17.998** | ✔ |
| Experimento 120 s, apoyo cliente / anfitrión | 6.311 / 7.161 de 7.200 | **6.311 / 7.161** | ✔ |
| Sin carga 60 s, cliente | 3.600 / 3.600 | **3.600** | ✔ |
| Con carga sin ciclos, cliente | 3.596 / 3.600 | **3.596** | ✔ |
| Colocación+transición corregidas, 60 s, cliente | 3.494 / 3.600 (97,06 %) | **3.494** | ✔ (ver §"La iteración gastada") |
| Volcado del primer despegue (tick 88→89) | caja a 1,549 → 0,172 m, 10,14 cm de solapamiento, subida 0,319 m | **idéntico** en `client_support_losses.json` | ✔ |
| `main` intacto | sí | **2b16e99 = origin** | ✔ |

Todo lo que citan está en los crudos y coincide con lo que yo calculo por mi cuenta. Tercera entrega seguida en la que eso se cumple.

## La iteración gastada, y por qué duele

La corrida 4 se lanzó a las 20:46:38, **veinticinco segundos después** de que el experimento de 60 s sobre el mismo commit diera 97,06 %. Ese experimento cumplía mi precondición (≥ 95 %). Pero mira su última fila:

| Experimento 60 s sobre `19836c7` | Corrida 4 (300 s) sobre `19836c7` |
|---|---|
| pérdida definitiva en el tick **3502**, 99 ticks antes del final | pérdida definitiva en el tick **3502** |
| ticks apoyados: **3.494** | ticks apoyados: **3.494** |

**El experimento "verde" ya tenía a la tripulante expulsada.** La ventana de 60 s se acabó 1,65 s después de la expulsión, así que el porcentaje salió por encima del 95 % con ella fuera del bus. Es el mismo guion determinista en las dos corridas, la misma caja y el mismo tick. La corrida 4 no aportó ninguna información que el experimento no tuviera ya; solo consumió una de las tres.

Culpas, en orden: **la mía primero**: escribí la precondición como un porcentaje y un porcentaje no ve una expulsión al final de la ventana. **La de ellos después**: tenían el fichero de flancos del experimento, cinco pérdidas, y no miraron si la última se recuperaba. La regla nueva va en §"Correcciones".

Bajo D96 tal como está escrito, la corrida 4 **cuenta**: es una corrida completa del gate con más de diez ciclos por instancia (120/25) que falló. No la voy a invalidar retroactivamente porque yo hubiera escrito mal la precondición; eso sería mover el poste.

## El mecanismo que queda, sacado de sus propios flancos

Miré los 15 flancos de pérdida del experimento de 120 s, con el tick anterior completo que ahora se guarda. **En 13 de los 15, en el tick anterior a perder el suelo, la tripulante tiene dos contactos —el suelo del bus y una caja— y la velocidad de plataforma que adopta es la de la caja, no la del suelo.** Y la caja va más despacio:

| Tick | Suelo del bus | Caja adoptada como plataforma | Déficit |
|---|---|---|---|
| 495 | 18,55 m/s | `Package_3` **12,34** | −6,2 (razón 0,665) |
| 764 | 15,08 | `Package_2` 13,64 | −1,4 |
| 911 | 16,07 | `Package_2` 14,68 | −1,4 |
| 1476 | 24,51 | `Package_2` 22,98 | −1,5 |
| 2847 | 23,94 | `Package_3` **15,93** | −8,0 (razón 0,665) |
| 3602 | 15,22 | `Package_2` 13,37 | −1,9 |
| 5679 | 23,89 | `Package_3` **15,89** | −8,0 (razón 0,665) |
| 6338 → **expulsión definitiva** | 17,29 | `Package_3` 16,05 | −1,2 |

Con la plataforma 1–8 m/s más lenta que el suelo, el motor la mueve ese déficit por tick hacia atrás respecto al bus (2–13 cm), su `z` local crece, y pierde el suelo. Es lo que el ejecutor apuntó en el tick 3501 de la corrida 4 y lo confirmo en los quince flancos.

**Esto es una regla de `CharacterBody3D`, no un bug nuestro:** en `_set_collision_direction()` el contacto de **pared** más profundo llama a `_set_platform_data()` y **sobrescribe la plataforma que había puesto el suelo**. Si estás en el suelo del bus y tocas una caja por el lado, tu plataforma pasa a ser la caja. Solo se exime a los colisionadores que son `CharacterBody3D`. [Seguro] en cuanto a la regla; el ejecutor ya citó el archivo.

Dos preguntas salen de aquí, y las dos se miden, no se adivinan:

**(1) ¿Por qué una réplica cinemática escrita cada tick en el marco del bus reporta 2/3 de la velocidad del bus?** Tres veces `Package_3` da exactamente la razón 0,665. `NetCargoReplica.advance()` escribe `bus.global_transform * interpolación_local` cada tick, así que el desplazamiento mundial debería ser el del bus. No lo es. Hay que registrar, en los tres ticks previos a cada flanco, el desplazamiento mundial por tick de la réplica junto al del bus y la velocidad que reporta el contacto. No tengo la explicación y no la voy a inventar.

**(2) ¿Debe una tripulante adoptar una caja como plataforma alguna vez?** Aunque la réplica reportara la velocidad exacta, en el anfitrión las cajas sueltas son cuerpos rígidos con velocidad propia (deslizan al frenar, botan en los baches), y el anfitrión también perdió el suelo 6 veces en 120 s por lo mismo. El diseño no debería depender de que ninguna caja se mueva jamás respecto al suelo.

**Una trampa que ahorra una iteración:** [Probable] `platform_floor_layers` / `platform_wall_layers` **no sirven** para esto. En `move_and_slide()`, si la plataforma actual (la caja, capa 2) queda excluida por la máscara, `current_platform_velocity` se pone a **cero**, no vuelve al suelo. Estando en el suelo con la caja como plataforma, excluir la capa 2 le quitaría toda la velocidad del bus ese tick: 0,3 m de deslizamiento de golpe. Léase `character_body_3d.cpp` de 4.7 antes de tocar esas dos propiedades.

Candidatos a medir en el banco determinista (mi sonda + una caja cinemática lateral con velocidad distinta al suelo), en este orden de coste:
- **(a)** arreglar el déficit de velocidad de la réplica —es un bug de replicación en cualquier caso— y ver cuánto del 12 % se lleva;
- **(b)** **acarreo explícito**: la tripulante deja de usar la velocidad de plataforma del motor (las dos máscaras a 0 → siempre excluida → cero) y suma ella misma la velocidad del punto del bus antes de `move_and_slide`. El bus es el único que la lleva, por construcción, toque lo que toque. Sigue siendo opción A (CharacterBody3D sobre plataforma cinemática); cambia quién aplica el acarreo. Habría que volver a medir los hechos de T2.2 sobre el apoyo en −0,5 m/s;
- **(c)** que tripulante y carga no colisionen (máscara sin capa 2). Desaparecen las dos familias de fallo (adopción de plataforma y caja dentro de la cápsula) a cambio de atravesar cajas visualmente. **Es una decisión de diseño del dueño**, no del ejecutor ni mía.

## Correcciones a MI criterio (cuarta y quinta de la tarea)

1. **La racha de penetración no puede contar el asentamiento en reposo.** En el anfitrión, `Package_3` acumula **4.391 ticks** seguidos de penetración con profundidad máxima **2,55 cm** en el suelo. Eso no es un atravesamiento: es una caja apoyada. Jolt deja que los cuerpos en reposo se hundan hasta el `penetration_slop` (2 cm por defecto) **por diseño**. Con el criterio como lo escribí ("ninguna penetración de más de 3 ticks") una caja quieta en el suelo falla el gate para siempre. **Corrección:** la racha se cuenta solo con profundidades por encima de un umbral de reposo; el umbral sale de los datos —histograma de profundidad de la carga simulada del anfitrión— y provisionalmente lo fijo en **3 cm**. La profundidad máxima (5 cm) se mantiene como está. Y que la tabla enseñe el histograma para que se pueda discutir.
2. **La precondición para gastar una iteración de D96 no es un porcentaje.** Antes de lanzar el gate: un experimento **de la misma duración (300 s)**, con la misma configuración, en el que **ambas instancias** tengan (i) apoyo ≥ 95 %, (ii) **apoyo en el último tick**, y (iii) **ninguna pérdida de más de 30 ticks**. Lo que pasó con el 97,06 % no se repite.
3. **El flag `experiment=1` es una puerta trasera de D96 y hay que cerrarla.** Yo la abrí en la ronda 4 para reducciones de 60 s y está bien para eso. Pero un experimento de 300 s con la configuración del gate **es** un gate que no cuenta, y con eso "ningún una más" queda en papel. Propuesta, y es decisión del dueño porque toca D96: **la ronda 5 es la última ronda de experimentos**. Si termina sin un experimento de 300 s en verde según el punto 2, se escribe el plan de la opción B aunque D96 marque dos. Si lo hay, se gasta la tercera iteración sobre esa configuración exacta.

## Lo que hay que reconocer

- **Redujeron en tres experimentos lo que yo tenía como dos hipótesis abiertas**, y la primera medida (sin carga: 100/100) tumbó la que yo había puesto arriba. Mi sonda determinista, sin cajas, no podía verlo.
- **Tres defectos, tres pruebas rojas con número, tres verdes.** Ninguna "creemos que". 0,42 m → 0; 97,56 m/s → 0; 1,50 m → 0.
- **La sonda de flancos con el tick anterior completo** es lo que me ha permitido verificar el mecanismo restante en quince minutos, y es lo que les permitió a ellos encontrar los tres defectos. Es el mejor instrumento que ha producido esta tarea.
- **Avisaron antes de editar** que mi "queda un solo motivo" no cuadraba con los datos (había penetraciones de la tripulante local del cliente). Tenían razón y lo dijeron primero.
- **No gastaron la tercera iteración** teniendo un 87,65 % delante. Con dos fallos y un arreglo recién hecho, la tentación era grande.
- Vsync fuera, `max_fps=0`, réplicas excluidas de la penetración, criterio de apoyo en primera fila, D95 reescrito en el plan: **las tres correcciones de la revisión 04 aplicadas tal cual.** Y ahora los fps significan algo: p1 147 / 176.

## Deuda que no bloquea el gate pero va al BACKLOG

- `drop()` y `throw()` **fallan en silencio** cuando la caja no cabe (y el anfitrión rechaza la liberación con `fits` en **su** mundo, donde la réplica de la tripulante del cliente está hasta 1 m desplazada). El actor guionizado reintenta cada 0,5 s y no pasa nada; una persona pulsa y no ocurre nada. Hace falta respuesta al jugador (M3) y probablemente validar la geometría en el marco del bus con la pose que el cliente envía, no con la réplica.
- El error remoto de tripulante p95 ~1 m y de bus 1,87 m es la latencia de interpolación (~85 ms a 22 m/s) expresada en metros; se reporta y no se juzga, pero conviene escribir eso al lado del número para que nadie lo lea como error de posición.
- `seat_test.gd` empuja `ERROR: CameraArbiter: no Camera3D in group 'eye_camera'` en cada corrida del arnés; es ruido de fixture anterior a esta ronda y no cambia el código de salida, pero ensucia el log.

**Dueño:** sigue sin haber nada que jugar. La pregunta que te toca está en §"Correcciones", punto 3.
