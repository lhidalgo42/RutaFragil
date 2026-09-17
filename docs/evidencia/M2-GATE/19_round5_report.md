# Ronda 5 — cierre por límite de experimentación

**D no pasa. Se para; no se lanza el tercer gate.** D96 conserva dos fallos
válidos y el tercer intento intacto. El revisor redactará el plan B; aquí no
se redacta ni implementa. La acotación E permanece pendiente del dueño y
se aplica conforme a su instrucción.

Fuentes finales: `25c7a72206666cccfd748ee67c1a3de94068373b`.
Commits previos: `e2f69ac` conserva revisión 05 y prompt 05 sin modificaciones;
`6454cea` añade instrumentación de los tres ticks anteriores. Los commits
posteriores a `25c7a72` contienen solo evidencia y documentación.

| D, 300 s / 18.000 ticks | Anfitrión | Cliente |
|---|---:|---:|
| Apoyo | 99,983333 % | 27,333333 % |
| Último tick apoyado | Sí | No |
| Mayor pérdida | 2 ticks | 13.078 ticks |

Observador independiente después de los nodos, ambas prioridades 1000, igual
en las dos instancias. El cliente pierde definitivamente el apoyo en 4923;
su p99 no se cita como jitter. [Tabla completa y recuperación de cada flanco](18_experiment_300.md),
con logs de ambas instancias: cero ERROR y WARNING, salidas 0/0 y capturas
automáticas. El código 0 del experimento indica terminación, no cumplimiento de D.

[Banco A/B, presión vertical y baches](16_platform_adoption.md): la caja lenta
de pie reproduce expulsión (35,244 % de apoyo), pero no aísla la adopción como
causa; la exacta da 100 % y elimina también el encuentro. Caminando, ambas dan
100 %. El acarreo explícito se rechaza: sin carga y con presión de −0,5 m/s,
introduce 16/5 ticks en el aire. Entrada a 85,515 km/h con desaceleración hasta
53,709; no es un cruce a 80 km/h sostenidos. La corrección de fase de liberación
sí está probada: 0,308333 m → 0, con test rojo/verde y una FIFO que preserva
el orden de los cuatro RPC fiables.

[Histograma y corrección histórica](17_penetration_revision_05.md): 17.086
muestras registradas de carga anfitrión; 2671 ≤1 µm, 3925 entre 1 µm y 1 cm,
7214 entre 1 y 2 cm, 3276 entre 2 y 3 cm y cero por encima. Máximos observados:
2,2100 / 2,7387 cm. La cobertura es incompleta en transiciones: ceros sin forma
activa pueden cortar rachas. No se certifican máximos ni rachas reales.
Corrida 4, Package_3: los 4391 ticks a ≤2,55 cm quedan en racha corregida cero.
Los históricos no reconstruibles se declaran como tales.

[Verificación del arnés](02_r5_verified_runs.json): **0 / 0 / 0, con 241/241
tests cada vez**, `expected_tests=241` en ambos envoltorios.
[Strict](02_r5_unsafe_result.json): 0, con 241/241, imports 0/0 y red 0.
Los errores esperados de fixtures siguen visibles.
[Regresiones](06_regression.md): demo 0, conducción 0 y red larga 0; las seis
cifras permanecen intactas. [Worktree fresco](07_r5_fresh_import.json): imports
0/0, sin errores ni avisos, caché creada, estado Git vacío y ningún `.uid`
sin seguimiento.

Quedan abiertos: viajar en el cliente, aislar la adopción en el banco, cubrir
las transiciones en la sonda de penetración y el gate humano. No se jugó
manualmente esta configuración. No se desactivan colisiones ni se implementa B.
BACKLOG conserva además la respuesta a drop/throw, validación con pose del
cliente, latencia incluida en el error remoto y ruido de seat_test. `main`,
bus, suspensión, tuning y escenas permanecen intactos; [límites](09_limits.txt).
