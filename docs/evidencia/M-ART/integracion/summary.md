# M-ART — integración del paquete

Registro UTC: 2026-09-24T01:06:59.731Z.

## Alcance autorizado

El dueño autorizó modificar src/cargo/package.tscn e integrar el modelo limpio, sin cambiar colisión, y borrar el provisional y sus auxiliares.

- Visual: res://assets/models/package_clean_v1.glb, instancia Mesh con posición (0, -0.2, 0).
- Física conservada: BoxShape3D de 0.4 m centrada en el cuerpo, masa 8, collision_layer 2, collision_mask 7 y continuous_cd activado.
- Fuente cruda y modelo válido conservados; 8 archivos provisionales eliminados. Lista exacta en removed.log.
- Test existente reforzado para exigir la instancia del GLB validado; no aumentó el conteo de tests.

## Pruebas y resultados

| Comprobación | Resultado | Evidencia |
|---|---|---|
| gdUnit focalizado, antes de integrar | 2 tests, 1 fallo esperado; salida 100 | red.log; red_results.xml |
| gdUnit focalizado, tras integrar | 2/2; salida 0 | green.log; green_results.xml |
| Suite completa | 257/257; salida 0 | full_suite_summary.log; full_suite_results.xml |
| Red | 1 host + 3 clientes; desviación máxima 0.000 m / 0.00 grados; salida 0 | full_suite_summary.log |
| Arranque headless | Sin errores; salida 0 | startup.log |
| GLB definitivo | 8/8, 800 tris, base Y≈0; salida 0 | glb_check.log |
| Preview Godot | PNG 1280×720; salida 0, stderr vacío | preview_stdout.log; preview_stderr.log; package_godot.png |
| Playground real | 4 paquetes con el GLB validado; salida 0, stderr vacío | playground_stdout.log; playground_stderr.log; playground_package.png |

La suite conserva mensajes preexistentes de CameraArbiter (eye_camera/cabin_camera) y aviso de interpolación de cámara; no se presentan como log limpio ni se modifican fuera de alcance.

Suite: powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1.
Arranque: Godot 4.7.2, --headless --path . --quit-after 10.
Prueba focalizada: Godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests/cargo/package_authored_collision_test.gd -rd <carpeta de evidencia>.

## Capturas

- package_godot.png: src/tooling/asset_preview.gd, scene=res://src/cargo/package.tscn, out=res://reports/m_art_integration/package_godot.png (copiada aquí), resolución 1280×720.
- playground_package.png: playground_capture.gd (guardado como playground_capture.gd.txt) carga scenes/playground.tscn normal, espera 120 ticks, comprueba el GLB de todos los paquetes y encuadra el primero sobre el estante. No cambia iluminación ni geometría.
- Ambos procesos con ventana se lanzaron con Start-Process -WindowStyle Hidden, timeout externo de 120 segundos mediante WaitForExit y Kill solo del proceso creado en caso de excederlo.
- Primera captura obstruida por techo: cámara a altura local aproximada 1.45 frente a techo 1.35. Corregida solo altura de cámara a aproximadamente 1.15; intento original conservado en playground_package_occluded.png.
- reference_vs_godot.png compara docs/referencias/paquete_referencia_v1.png con recorte (490,235,300,300) de package_godot.png. Sin cambios de color; no compara iluminación idéntica ni implica aprobación visual.
- Evidencia anterior de limpieza en ../limpieza/. Su resumen es histórico; el XML de la suite de esta integración es full_suite_results.xml.

## Revisión visual del dueño

El 2026-09-24 UTC, tras probarlo en el juego, el dueño indicó «se ve bastante bien, sigamos con la siguetne fase del juego». Queda registrada la aceptación visual del paquete integrado, no una aprobación automática ni el gate M8. La captura interior conserva la iluminación real. No se ha hecho commit ni merge.

## Nota de conservación

Copiado el 2026-09-24 desde `reports/m_art_integration/`, carpeta ignorada por git que `tools/run_tests.ps1` borra al empezar. Los logs se convirtieron de UTF-16 a UTF-8. Se omiten los informes HTML de gdUnit y el log completo de la suite; quedan sus XML y el extracto de veredicto.
