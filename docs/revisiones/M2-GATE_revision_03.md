# Revisión 03 — M2-GATE: RETIRO g2.1

**Fecha:** 2026-09-16 · **Revisa:** Claude · **Motivo:** contraprueba del ejecutor, verificada y ampliada por el revisor · **Afecta a:** `docs/revisiones/M2-GATE_revision_02.md` §"El hecho del motor", `docs/planes/M2-GATE_plan.md` (D92), `docs/planes/M2-GATE_ronda3_prompt.md`, `M2-GATE_ronda3_prompt_codex.md` y `M2-GATE_respuesta_g21.md`

## Veredicto: **g2.1 queda retirado.** El punto de escritura no está demostrado que importe. Tenías razón.

Tu contraprueba es correcta. La reproduje por mi cuenta, y sale **peor para mí** de lo que tú la presentaste.

## Lo que medí al verificarte

Cogí mi propia sonda, le añadí un observador en un nodo con `process_priority = 1000` —es decir, que muestrea **después** de que la tripulante haya corrido su `_physics_process`— y conservé intacta la lectura original desde `physics_frame`. Misma grabación, misma ventana de 1.800 ticks, todo lo demás igual:

| Camino | Dónde se escribe | Deslizamiento máx **muestreado en `physics_frame`** | Deslizamiento máx **muestreado tras los nodos** |
|---|---|---|---|
| paso a 30 Hz | `physics_frame` | **0,1586** (razón plataforma 1,01) | **0,6009** (razón 0,00) |
| paso a 30 Hz | nodo `_physics_process` | **0,6009** (razón 0,00) | **0,0127** (razón 1,01) |
| interpolado | `physics_frame` | 0,0791 (1,01) | 0,0802 (1,01) |
| interpolado | nodo `_physics_process` | 0,0795 (1,01) | 0,0083 (1,01) |

Léelo despacio, porque es una imagen en espejo. **Muestreando en `physics_frame`, gana la escritura desde `physics_frame`. Muestreando después de los nodos, gana la escritura desde el nodo** — y por un margen aún mayor (0,0127 contra 0,6009, 47 veces). La razón de velocidad de plataforma se invierte exactamente igual: 1,01 y 0,00 en un punto, 0,00 y 1,01 en el otro.

O sea: **lo que mi tabla medía no era dónde se escribe, sino si mi muestra caía dentro o fuera de la ventana entre la escritura y el movimiento de la tripulante.** La física es la misma en los dos casos. Si hubiera elegido el otro observador habría escrito la conclusión contraria con la misma convicción, y eso es la definición de una medición que no mide lo que dice.

De paso queda establecido un hecho menor y este sí sólido, porque se deduce de que los dos puntos difieran: **la señal `physics_frame` se emite ANTES del procesado de nodos**, no después.

## Qué cambia, y hazlo antes de seguir

1. **El requisito de escribir desde `physics_frame` desaparece.** No hay medición que lo sostenga. Tu receptor `NetBusSync` se queda como lo diseñaste, y la elección entre una conexión a `physics_frame` y una llamada desde `_physics_process` vuelve a ser tuya, por las razones de ingeniería que quieras (a mí la conexión a `physics_frame` me sigue pareciendo más limpia porque no depende de prioridades de nodo, pero eso es gusto, no medida).
2. **El test que lo pinea se borra**, no se ajusta el umbral. Estaba pineando algo que no existe. Con eso desaparece el fallo que te deja el arnés en 186/187 y código 100; baja `expected_tests` en el mismo commit.
3. **No escribas el "hecho del motor" en `DECISIONS.md`.** Te lo pedí en la ronda 3 y estaba equivocado. Si ya lo escribiste, quítalo.
4. **Corrige los cuatro documentos donde lo dejé:** la revisión 02, D92 en el plan, los dos prompts de la ronda 3 y `M2-GATE_respuesta_g21.md`. Yo dejo esta revisión 03 como la corrección de referencia; tú borra o marca lo viejo al commitear.

## Qué NO cambia

**La decisión de arquitectura se sostiene entera, y ahora con más apoyo que antes.** Mira las dos filas interpoladas de la tabla: dan entre 0,008 y 0,080 **en los dos puntos de muestreo y en las dos escrituras**. Las filas a saltos dan ~0,60 en uno de los dos puntos **siempre**, escribas donde escribas. Es decir: **interpolar es lo que importa, y es robusto a cómo lo mires**; el salto a 30 Hz sacude al pasajero por el tamaño del salto y solo se le puede esconder eligiendo bien el instante de la foto.

Que la conclusión sobreviva a que se caiga el argumento no la valida sola: la valida que ahora está medida en cuatro combinaciones en vez de dos.

## Lo que hay que salvar de esto, y es lo más importante de la revisión

**Una métrica por tick no significa nada sin un punto de muestreo declarado y fijo.** Acabo de demostrarlo contra mí mismo: la misma cantidad, la misma corrida, el mismo código, y dos números que difieren por un factor de 47 según dónde pongas la regla.

Eso **afecta directamente al criterio del gate**, que es exactamente una métrica por tick. D95 dice hoy "el p99 del deslizamiento por tick del cliente no supera 1,5× el del anfitrión de la misma corrida", y le falta la mitad de la frase. Añade a D95:

- **El punto de muestreo se declara y es el mismo para las dos instancias y para todas las filas**: un nodo observador dedicado con `process_priority` fijo y documentado, que sea el último en correr, y que no sea el mismo nodo que escribe nada.
- **La evidencia lo dice explícitamente** en cada tabla. Una tabla de deslizamiento sin punto de muestreo declarado no es comparable con ninguna otra.
- Y el corolario: **anfitrión y cliente tienen que muestrear en el mismo sitio**, o el cociente de 1,5× compara peras con manzanas. Hoy nadie había escrito eso y era justo lo que hacía falta.

## Lo que hay que reconocerte

- **Dijiste que no con un número.** Te di una tabla firmada por el revisor, con un prompt que te pedía construir encima, y en vez de construir encima fuiste a comprobarla y montaste el observador que la desmonta. Es la segunda vez en esta tarea que el ejecutor corrige al revisor con una medición; la primera fue la tabla de 120 Hz que tumbó mi hipótesis de la discretización.
- **Conservaste la lectura original en vez de sustituirla.** Por eso se ve el espejo. Si hubieras cambiado el punto de muestreo sin más, habríamos discutido dos tablas incompatibles sin entender por qué.
- **Paraste tras tres ensayos dirigidos y lo reportaste** en vez de seguir buscando un arreglo a un problema que no existía.
- Y **no tocaste el umbral para que pasara**, que era la salida fácil y la peor.

## Estado que hereda la fase 0

Con g2.1 retirado y su test borrado, de las cuatro bloqueantes de la revisión 02 quedan tres: **g2.7** (que ya cerraste: la tabla caminando repetida con cada régimen sobre su grabación, y la distancia entre trayectorias medida en p95 3,54 m y máximo 3,84 m, que es diez veces lo que los dos habíamos estimado a ojo), **g2.8** y **g2.9**. Más las no bloqueantes: g2.2, g2.3, g2.10, g2.11, g2.13 y g2.14.

Cierra la fase 0 con eso y sigue con A y B. El gate sigue en cero iteraciones y sin veredicto A/B, que es donde tocaba estar.
