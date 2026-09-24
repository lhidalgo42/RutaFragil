# M-ART-VAN — Van completa: exterior, interior, copiloto y ruedas · Plan aprobado

**Fecha:** 2026-09-24 · **Rama:** `art/m-art-style-board` · **Estado:** aprobado, implementación pendiente · **Base:** D100, D102, maestro §10/§10.1 y R12.

## 1. Alcance

Una sola tarea entrega la van visual completa: carrocería, interior, dos asientos y cuatro ruedas; copiloto local ocupable; animación visual de giro/dirección replicada. No incluye gameplay M3, ocupación de asientos por red (M4), puertas animadas/cerrables, cambios de física, tuning o colisión.

## 2. Contratos aprobados

- **Tres assets y tres atlases externos:** exterior, interior y rueda. Cada GLB usa un material, cero imágenes embebidas y un `.tres` que referencia un PNG externo ≤1024² en `assets/textures/`.
- **Geometría final autorada en Blender:** ComfyUI aporta fuentes de textura; TRELLIS no produce la geometría final. Límites: exterior ≤10k tris, interior ≤7k, rueda ≤1,5k; suma instanciada ≤25k tris.
- **Sin marcas reales:** neumático genérico de competición, sin Pirelli, logos, lettering ni trade dress copiado.
- **Arte separado de física:** ningún GLB aporta colisión. Los 16 colliders actuales siguen siendo la única física; masa, capas, tuning, cuatro marcadores de suspensión, seis `Positions` y doce `Restraints` quedan intactos.
- **R12 aprobado para visuales solamente:** en `bus.tscn` se puede ocultar —no borrar— el chasis greybox y añadir el exterior/cámara de copiloto; en `bus_interior.tscn` se puede ocultar —no borrar— `Visuals` y añadir interior/copiloto. Ningún otro nodo físico o marcador se reemplaza.
- **Sin flicker por construcción:** los visuales greybox quedan ocultos completos; no se superponen superficies coplanares ni se usa depth bias como parche.
- **Copiloto local:** `Seat.drives_bus=false`, modo pasajero, `BusInput` siempre apagado, cámara fija dedicada hija del bus y E conserva la salida del asiento. La ocupación por red no entra hasta M4.
- **Selección por retícula:** entre asientos libres al alcance gana el mejor alineado; distancia y `seat_name` desempatan; si ninguno queda delante, gana el más cercano.
- **Ruedas solo visuales:** usan centros derivados de la suspensión sin mover ni reparentar marcadores; todas giran, las delanteras doblan y la reversa invierte el giro. `NetBusSync` replica `steer` al final del snapshot, con default `0.0`, validación, clamp e interpolación; nunca escribe ese valor en la física cliente.
- **D100 manda:** furgón largo continuo cab-over, laterales ciegos con ventanas altas pequeñas, puerta lateral abierta, doble puerta trasera abierta, amarillo/franja roja/techo crema; nunca bus escolar de ventanas corridas.

## 3. Ejecución

1. Añadir contratos rojos para integración visual, ruedas, roles de asiento, cámara, retícula, F1 y snapshot de `steer`; actualizar el conteo exacto del arnés junto con los tests.
2. Generar tres fuentes de textura con FLUX.1 schnell y guardar prompt, seed y licencia. Componer atlases, validar formato/tamaño/costuras y revisar manualmente texto o marca fantasma.
3. Crear de forma reproducible en Blender los tres GLB, UV y material placeholder sin imágenes; pasar `glb_check` y el presupuesto agregado.
4. Integrar wrappers visuales; ocultar los greyboxes autorizados; añadir `CopilotSeat`, cámara fija y lógica local de rol/retícula.
5. Añadir animación visual de ruedas y `steer` replicado, preservando firmas antiguas con parámetros finales opcionales.
6. Correr import doble, suite completa, demo, red 1+3 y capturas. Guardar evidencia durable en `docs/evidencia/M-ART-VAN/`, nunca en `reports/`.

## 4. Verificación y gate

Automático: tres GLB sin colisión/imágenes embebidas; un atlas externo por asset; presupuesto ≤25k; 16 colliders/seis posiciones/doce restraints intactos; huecos lateral, trasero y parabrisas utilizables; copiloto nunca conduce; cámara única correcta; ruedas locales/remotas con centro, giro, dirección delantera, reversa y tuning recargado; suite/demo/red verdes sin cambiar las cifras D65.

Gate humano pendiente, con veredicto PASA/FALLA/NO PROBADO:

1. Se lee como furgón de reparto, no bus escolar; huecos y puertas son utilizables.
2. Piloto conduce; copiloto se sienta/levanta, nunca conduce y tiene vista usable.
3. Piso, racks y asientos se ven bien; cero flicker parado o en movimiento.
4. Las cuatro ruedas son visibles y giran; delanteras doblan; reversa invierte; un cliente lo ve.
5. Neumático genérico sin Pirelli, logo, texto fantasma ni diseño reconocible.
6. El feel de conducción no cambió.

La ocupación de copiloto por red se declara **NO PROBADO / M4**. Solo el dueño puede cerrar este gate. Nada de este plan está implementado todavía.
