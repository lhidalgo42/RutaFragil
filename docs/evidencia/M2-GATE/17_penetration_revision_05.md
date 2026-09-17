# Penetración — revisión 05

Observador independiente postnodos, ambas prioridades 1000. Se conserva el
máximo de profundidad y su límite de **5 cm**. La racha cuenta estrictamente
**profundidad >3 cm**, con límite de 3 ticks. Igualdad, exclusión de simulación
y separación cortan la racha. El histograma usa solo muestras elegibles:
carga FREE dinámica simulada por la instancia, sin introducir réplicas o
cuerpos excluidos como ceros. Se conservan profundidades por cuerpo/tick para
poder reevaluar el umbral. No se confunden estas muestras con callbacks físicos.

Los históricos no guardaron esas profundidades ni estado por tick. Se
preservan intactos y se reemite solo lo que permiten deducir:

| Corrida 4, anfitrión | Muestras elegibles | Máximo | Racha corregida >3 cm |
|---|---:|---:|---|
| Package_2 | 3121 | 0,035662197 m | No reconstruible: 1–23 ticks |
| Package_3 | 15128 | 0,025533322 m | **0**, antes 4391 |

Histograma parcial: 2349 muestras ≤1 µm, 15900 positivas; entre 1 y 1403
superaron 3 cm, ninguna superó 5 cm. Los intervalos más finos no son
reconstruibles. La tripulante local cliente alcanzó 0,066812 m: continúa
fallando el máximo; su racha >3 cm queda acotada en 1–216, no reconstruida.

En corrida 2, el agregado histórico de carga mezclaba FREE y STRAPPED.
Package_3 nunca superó 0,020001 m, por lo que su racha >3 cm es cero.
El máximo dinámico y la racha dinámica de Package_2 no son reconstruibles.
Las tripulantes locales conservan máximos 0,074849 / 0,200542 m; sus rachas
>3 cm solo pueden acotarse en 1–7 / 1–58 ticks. Ambos máximos superan 5 cm.
No se reutiliza el 0,105043 m del antiguo agregado de Package_2 como máximo
físico local. Los veredictos de corridas 2 y 4 continúan fallidos por falta
de apoyo cliente y profundidad local >5 cm; se retiran motivos de duración
que ya no pueden probarse con el umbral vigente.

Control histórico adicional, experimento 120 s `r4_free_wait_fix_01`:

| Profundidad de carga simulada anfitrión | Muestras |
|---|---:|
| ≤1 µm | 1436 |
| >1 µm y ≤3 cm | 1030 |
| >3 cm | 0 |
| Total elegible | 2466 |

Los máximos de Package_2/3 fueron 0,028799107 / 0,025052695 m. Ambas rachas
corregidas son exactamente cero. Estos datos respaldan conservar provisionalmente
3 cm; el histograma observado de esta ronda se presenta abajo, con cobertura
incompleta declarada.

Prueba de regresión: [roja](17_rest_red.log), código 100; [verde](17_rest_green.log),
código 0. Verifica asentamiento a 2,55 cm, frontera exacta de 3 cm, cuatro
muestras por encima y exclusión que corta la racha sin contaminar el histograma.
La primera validación general descubrió 241 tests y gdUnit0, pero el envoltorio
había cargado expected_tests236 y devolvió1; se conserva `02_r5_initial.log`.
Los dos arneses se actualizan a241 en el mismo commit que los cinco tests nuevos.

## Histograma observado del experimento final300s

Fuente: [host.json](18_raw/r5_final_300/host.json), commit25c7a72,
observador postnodos/prioridades1000. Solo muestras clasificadas como FREE,
dinámicas y propias del anfitrión. Las cajas0/1 amarradas tienen cero muestras
elegibles. **Limitación:** instrumentation_missing registra instantes sin forma
activa para Package_2/3; no conserva el tick exacto de esa alerta. Los ceros
pueden incluir esas lecturas, por lo que este histograma no certifica completitud
geométrica ni un gate verde. Esos ceros también cortan rachas: no permiten
certificar la racha ni el máximo total real. Los positivos y máximos publicados
son mediciones observadas, con cobertura incompleta en transiciones.

| Profundidad | Package_2 | Package_3 | Total |
|---|---:|---:|---:|
| ≤1µm | 1901 | 770 | 2671 |
| >1µm a1cm | 1148 | 2777 | 3925 |
| >1 a2cm | 48 | 7166 | 7214 |
| >2 a3cm | 36 | 3240 | 3276 |
| >3 a4cm | 0 | 0 | 0 |
| >4 a5cm | 0 | 0 | 0 |
| >5cm | 0 | 0 | 0 |
| Total elegible registrado | 3133 | 13953 | 17086 |

Máximos observados: 0.022100386 / 0.027386888m;
rachas >3cm:0/0. El histograma positivo respalda mantener provisionalmente3cm;
no hace falta proponer otro umbral a partir de estos datos. La tripulante local
cliente alcanza0,128689870m y9ticks >3cm; no se mezcla con el histograma de carga.
