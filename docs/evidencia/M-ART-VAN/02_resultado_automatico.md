# 02 — Resultado automático M-ART-VAN

Fecha: 2026-09-24. **No es el gate humano.**

## Resultado

| Comprobación | Resultado |
|---|---|
| Suite gdUnit4 | 271/271, 0 fallos, 0 errores |
| Conteo exacto | 271 esperado / 271 descubierto |
| Red | 1 host + 3 clientes, pass |
| Demo | vuelta completa, 17 waypoints, 27,3 s, 64,6 km/h, upright mínimo 0,97 |
| Exterior GLB | 3.856 tris, 8/8, 1 material, 0 imágenes embebidas |
| Interior GLB | 4.752 tris, 8/8, 1 material, 0 imágenes embebidas |
| Rueda GLB | 996 tris, 8/8, 1 material, 0 imágenes embebidas |
| Presupuesto visible | 12.592 / 25.000 tris |
| Atlases | 3 PNG externos, 1024², validación formato/tamaño verde; mipmaps activados y pin rojo/verde |
| Piso fuente | seam RMS 1,182 vs interior RMS 9,455; mosaico 3×3 adjunto |
| Colliders | 16 directos, sin colisión dentro de GLBs |
| Límites R8 | bus 11 nodos, interior 55, exterior visual 18; scripts <400 líneas |
| Copiloto | test E/F1/cámara/no-drive verde; ocupación de asientos en red NO PROBADA (M4) |
| Ruedas | delante ±18,24°, atrás 0°; avance spin negativo, reversa positivo |

Evidencia:

- `integracion/full_suite_summary.log`, `full_suite_results.xml`
- `integracion/run_demo.log`
- `integracion/van_exterior.png`, `van_cab.png`, `van_interior.png`
- `integracion/wheels_*.png`, `wheel_capture.log`
- `texturas/floor_seamless_3x3.png`, `floor_texture_check.json`
- generadores y tests bajo `tools/`

## Pendiente humano

Marcar PASA/FALLA/NO PROBADO:

1. Silueta de furgón D100, no bus escolar.
2. Puerta lateral y hueco trasero se leen/utilizan bien.
3. Texturas de exterior/interior/asientos/racks/piso.
4. Parabrisas procedural visible y transparente (D89); sin vidrio embebido en GLB.
5. Sin flicker perceptible parado/en movimiento/ángulo bajo.
6. Copiloto: sentarse/levantarse, vista usable, nunca conduce.
7. Ruedas: cuatro visibles, giro/reversa/dirección delanteras; cuatro guardabarros interiores visuales tapan la parte que sube sobre el piso.
8. Neumático genérico sin Pirelli, logos o lettering fantasma.
9. Feel de conducción sin cambio.

Limitaciones declaradas:

- La rueda delantera derecha comparte columna con la puerta lateral por la geometría heredada D90. El guardabarros interior queda a x=0,90 y fuera del hueco medido; aun así, el dueño decide si se lee bien al abordar.
- El seamless del piso tiene una cruz de reparación tenue; el atlas usa la región central, y el dueño decide si se ve durante juego.
- La ocupación de asientos en red no se implementó; M4.
- En clientes, las ruedas giran con la velocidad replicada y las delanteras doblan con `steer` replicado. La compresión de suspensión no se replica: el cliente congelado no corre raycasts, así que muestra la rueda a extensión nominal. Replicar compresión sería otro canal de red y no cambia giro ni dirección.
