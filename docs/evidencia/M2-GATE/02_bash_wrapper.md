# Plazo externo del envoltorio Bash

`run_gate.sh` deriva el plazo externo del último `seconds=` (o GATE_SECONDS),
con 140 s de margen. El watchdog avanza con tiempo del shell, independientemente
de Godot; al vencer termina el lanzador y devuelve 124. No acredita terminar
todo el árbol de hijos bloqueados. Cada hijo Godot conserva su plazo interno.

Verificación final: Git Bash en Windows, sintaxis `bash -n` código 0 y
[prueba aislada](02_bash_wrapper_probe_verified.log) código 0: propaga 0 y 7,
y devuelve 124 ante un ejecutable bloqueado. No se lanzó otra corrida del gate.
El timeout se aceleró a 1 s sustituyendo `awk` solo en ese último caso;
la llamada original conserva `seconds=2`, que da 142 s sin el sustituto.

Fuentes reproducibles: copiar [check](02_bash_wrapper_check.txt) como check.sh,
[ejecutable](02_bash_wrapper_godot_stub.txt) como godot_stub y
[reloj acelerado](02_bash_wrapper_awk_stub.txt) como awk en una misma carpeta
temporal; ejecutar `bash /ruta/check.sh` desde la raíz del proyecto.
La prueba imprime y afirma los códigos; el mensaje de timeout es esperado.

Los logs initial/second/third/previous/trace conservan intentos de construcción
del watchdog y del fixture. Se sustituyó la espera larga por comprobaciones
cada segundo para evitar dejar una espera larga viva al salir. El log
`02_bash_wrapper_probe_final.log` corresponde a un intento que no arrancó:
el arnés había limpiado reports/ y eliminado su fixture. La repetición final
se hizo desde una carpeta temporal externa; no se presenta ese error como éxito.

No se ejecutó el gate con Bash/Godot en macOS o Linux.

El envoltorio PowerShell conserva el handle del lanzador y rechaza un código
de salida nulo: un proceso muy corto puede terminar antes del primer WaitForExit.
Comprobación con un `.cmd` que solo contiene `@exit /b 0` o `@exit /b 7`,
asignado temporalmente a GODOT_BIN: ambos códigos se propagan en
[02_powershell_wrapper_probe.json](02_powershell_wrapper_probe.json).
No modifica el resultado de las corridas de Godot ya guardadas, cuyos códigos
de salida estaban disponibles; cierra la ruta que podía aceptar un nulo.
