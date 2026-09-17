# Comprobación con ventana — ronda 4

Cliente visible, anfitrión conduciendo sin ventana, 120 s, código `19836c7`,
`human=client`, VSync off y sin límite de FPS. Se seleccionó la ventana nativa
con Computer Use y se enviaron W, arrastre de ratón, E y clic derecho.

El cliente permaneció apoyado 7200/7200 ticks (100 %), sin flancos de pérdida.
Se ve el interior, las cajas y la cápsula remota. Ambos logs tienen cero ERROR
 y cero WARNING. La salida 2 corresponde a un preflight de 120 s sin ciclos;
no consume D96. [Datos y logs](05_raw/r4_manual_01/summary.json).

![Cliente observado durante el recorrido](05_raw/r4_manual_01/client_native_walk.png)
![Cliente al final de la inspección](05_raw/r4_manual_01/client_native_late.png)

Límite explícito: los taps de la herramienta no produjeron solicitudes de
agarre en los contadores; no se acredita un ciclo manual ni control sostenido.
Esta inspección acredita visibilidad y permanencia en ese recorrido, no
jugabilidad completa, sensación ni aprobación humana. El arreglo de espera
FREE posterior `1eeb635` se verifica por banco y experimento separado.

---

# Ventanas y comprobación manual — histórico de ronda 3b

No hay aprobación de jugabilidad. La prueba manual reproduce una pérdida
visible del bus; no se oculta tras los tests de lógica.

En la corrida 2, dos ventanas, el cliente ve la tripulante remota y la carga:

![Cliente, corrida 2](04_raw/iteration_2/client_running.png)

El anfitrión usa persecución. Se aprecia también el desfase de la tripulante
remota respecto al bus, incluido en error remoto y diagnóstico de penetración;
la revisión 04 excluye esa réplica del criterio físico:

![Anfitrión, corrida 2](04_raw/iteration_2/host_running.png)

Prueba manual histórica de ronda 3b: `05_raw/manual_02`, 180 s, anfitrión headless
conduciendo y cliente con ventana, `human=client`, VSync off. Código ejecutable
000c52f, motor 4.7.2. Se seleccionó la ventana nativa y se enviaron Escape,
clic de recaptura, arrastre del ratón, W y Space mediante Computer Use.
La cámara pertenece a la tripulante local, pero esta perdió el bus:

![El cliente queda atrás](05_raw/manual_02/client_native_bus_departing.png)

No se completó ningún ciclo manual de carga. Los taps breves de la herramienta
no acreditan mantener una tecla durante la interacción de amarrar; tampoco
se considera verificado el control sostenido de cámara y movimiento a partir
de esos taps. No se afirma que el rol cliente sea jugable.

El ensayo previo `05_raw/manual_01` duró 120 s y también conserva una captura
nativa tras Escape/clic/W/S/movimiento de ratón/E. Ninguno sustituye los cinco
minutos jugados por el dueño ni aprueba sensación, jitter perceptible o D97.
Los dos logs de cada ensayo terminaron con cero ERROR y cero WARNING.
