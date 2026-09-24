# M-ART — limpieza del paquete

Fecha: 2026-09-24 UTC (23 en Chile). Alcance: limpieza; no integración ni gate humano.

## Resultado

- Fuente preservada: docs/referencias/package_raw_v1.glb; procedencia en JSON adyacente y CREDITS.md.
- Asset: assets/models/package_clean_v1.glb; 800 tris; bbox X/Y/Z 0,400 × 0,319 × 0,362 m; base Y≈0; un material; tres texturas ≤1024².
- Validador del archivo final: 8/8, salida 0 (glb_check.log).
- Provisional assets/models/package.glb: 7/8, salida 1 esperada (provisional_check.log). Borrado no autorizado; conservado.
- --outer-shell retira 4 capas internas invertidas (13.774 caras); exterior 6.222 caras antes de decimar. Diagnóstico en shells.log.
- Contención por bbox: limitada a props cerrados tipo caja; no prueba contención de mallas cóncavas ni aplica a assets huecos.
- Prueba real de limpieza: salida 0; fuente SHA-256 sin cambios (blender_cleanup_test.log).
- Previews Blender: docs/referencias/package_clean_v1_front34.png, package_clean_v1_rear34.png, package_clean_v1_side.png.

## Comando de limpieza ejecutado

Desde raíz del repo, Blender 5.1.2:

~~~powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --factory-startup --python-exit-code 1 --python tools/blender_cleanup.py -- (Join-Path $PWD 'docs/referencias/package_raw_v1.glb') (Join-Path $PWD 'assets/models/package_clean_v1.glb') --size 0.4 --tris 800 --texture 1024 --pivot base --outer-shell
python tools/glb_check.py assets/models/package_clean_v1.glb --kind package --pivot base
python tools/blender_cleanup_test.py --blender 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe'
~~~

## Regresión

- Suite completa de PowerShell: 257 tests, 0 fallos; XML de esa corrida no conservado: la suite posterior lo sobrescribió. El de la integración está en ../integracion/full_suite_results.xml. Conteo actual, no los 255 históricos del plan.
- Red: 1 host + 3 clientes, salida 0; extracto exacto de sesión 62933 en suite_summary.log.
- Suite imprime mensajes preexistentes de CameraArbiter (eye_camera/cabin_camera), registrados en BACKLOG.md; no equivale a consola limpia.
- Arranque normal headless: salida 0, solo encabezado del motor, sin errores (startup.log).
- Los reportes antiguos desaparecieron al limpiar reports/ en run_tests; esta carpeta contiene evidencia posterior a esa limpieza.

## Pendiente

- Autorización R12 para modificar src/cargo/package.tscn y borrar el provisional, su .import y PNG auxiliares.
- Pivote base confirmado; al integrar, cambiar solo posición del visual dentro de caja centrada, nunca colisión D81.
- Captura en Playground, comparación con board y aprobación visual humana. No marcar gate pasado por tests verdes.

## Nota de conservación

Copiado el 2026-09-24 desde `reports/m_art_cleanup/`, carpeta ignorada por git que `tools/run_tests.ps1` borra al empezar. Logs convertidos de UTF-16 a UTF-8.
