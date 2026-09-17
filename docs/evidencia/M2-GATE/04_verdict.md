# Veredicto actualizado con revisión 04

**D96 acumula dos fallos válidos: corridas 2 y 4.** Las corridas 1 y 3 son
inválidas por actividad insuficiente. Los experimentos de reducción no
consumen intentos. No se activa ni se implementa la opción B.

Muestreo común: observador independiente `GateMetrics`, después de los nodos,
prioridades de física y proceso 1000. Apoyo local mínimo 95 % antes de juzgar
p99; penetración solo de cuerpos simulados; FPS solo con VSync=0/max_fps=0.

| Corrida | Apoyo anfitrión / cliente | Ciclos | FPS p1 anfitrión / cliente | Veredicto |
|---|---:|---:|---:|---|
| [2 reemitida](04_gate_iteration_2.md) | 99,561111 % / 6,633333 % | 118 / 10 | Sin juicio: VSync=1, límite120 | Primer fallo válido |
| [4](04_gate_iteration_4.md) | 99,988889 % / 19,411111 % | 120 / 25 | 146,714 / 175,778 | Segundo fallo válido |

En ambas, la cliente no puede viajar; el p99 no se cita como jitter. La
corrida2 mantiene además penetraciones locales de 0,074849 m/7 ticks y
0,200542 m/58 ticks. En corrida4: 0,035662 m/4391 ticks y 0,066812 m/216 ticks.
Los logs de ambas instancias de ambas corridas tienen cero ERROR y WARNING.
Las tablas enlazadas conservan todas las métricas, errores y actividad.

[Reducción y arreglos comprobados](13_support_loss_reduction.md): colocación
solapada, velocidad ficticia al liberar y espera inicial de FREE. La corrida4
precede el último arreglo; [diagnóstico restante](14_remaining_cargo_contact.md).
No se consume un tercer intento para repetir un incumplimiento conocido de
penetración ni antes de aislar el transporte durante contactos laterales.

No hay aprobación de jugabilidad ni autorización para avanzar a M3. El
[ledger](04_iteration_ledger.json) conserva todas las corridas numeradas.
