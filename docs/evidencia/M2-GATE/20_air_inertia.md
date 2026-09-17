# 20 — Inercia en el aire: rojo y resultado final

Godot `4.7.2.stable.official.ed1daf0bf`, Jolt, 60 Hz. Mismo observador independiente postnodos, prioridades de proceso y física **1000**, en todas las filas. Bus cinemático con las 1.064 poses de `16_bank/recording.json`; 90 ticks de asentamiento fuera de la ventana. CrewMember de producción, máscaras intactas. No es una iteración D96.

**Resultado parcial:** pasan los tres saltos y los controles; **slow_encounter sigue fallando**. El proceso de la sonda sale 0 porque termina la medición, no porque todos los criterios pasen.

| Caso | Rojo: aire / fuera del casco | Final: aire / fuera del casco | Residuo final m | Distancia literal final m | Recuperación del bus | Veredicto |
|---|---:|---:|---:|---:|---|---|
| jump_standing | 0 / 0 | 12 / 0 | 0.031700 | 0.031700 | 12 ticks | cumple |
| jump_walking | 0 / 0 | 13 / 0 | 0.003195 | 0.430477 | 13 ticks | cumple |
| jump_bumps | 0 / 0 | 8 / 0 | 0.012098 | 0.012098 | 8 ticks | cumple |
| slow_encounter | 13 / 695 | 13 / 695 | 0.569664 | 0.569664 | no; ≥689 ticks | falla |
| control_standing | 0 / 0 | 0 / 0 | — | — | sin pérdida | cumple |
| control_walking | 0 / 0 | 0 / 0 | — | — | sin pérdida | cumple |

En rojo, ninguno de los tres saltos despega: la presión −0,5 sobrescribía el impulso. Por eso cero ticks fuera **no** era verde. Rojo antes de modificar CrewMember: [unitario](20_inertia_unit_red.log), dos casos, salida100; los seis logs `20_red_*.log` conservan los números previos.

El salto recto se ordena en tick660 a80,025km/h, el de baches en835 a85,541km/h. El residuo descuenta `v_paseo_local` del último tick apoyado por `ticks_en_aire/60`; el paseo durante el vuelo conserva la dirección de despegue. La medición literal caminando (0,430m) no es un error de acarreo.

**Techo:** el primer arreglo ya conservaba inercia, pero dejaba residuos0,35648/0,35422m. En tick662 se perdían0,32154m de avance al tocar el techo; la velocidad horizontal almacenada seguía22,1919m/s. Se conserva esa etapa en `20_green_*.log`. El test de techo descendiendo0,001m/s falla antes (`20_ceiling_unit_red.log`,100) y pasa después (`20_inertia_unit_green.log`,0). `slide_on_ceiling=false` cancela ascenso y conserva avance. El código del motor respalda la interpretación del remainder ascendente; el agotamiento de max_slides no se instrumentó directamente: [CharacterBody3D, commit del motor](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/3d/physics/character_body_3d.cpp#L167).

**Política de abandono:** `DO_NOTHING`; al perder suelo se suma una vez la velocidad de la última plataforma apoyada, después el input añade paseo a esa reserva. El motor sigue llevando al personaje apoyado. Aterrizar o sentarse borra la reserva. El test incluye dos saltos consecutivos para detectar doble suma.

**Límite no resuelto del banco lento:** primera salida del casco en tick370 (z local=3.826934814m); primera pérdida de apoyo en tick376; primer tick realmente en aire378. El empujón ya la ha sacado antes de que actúe la conservación de inercia. Aterriza en Ground en391, **no en el bus**. La distancia de vuelo mejora3,51910→0,56966m, pero siguen695 ticks fuera y689 sin recuperar apoyo. No se movió la caja ni el umbral. El requisito A de ese caso queda abierto.

Comando reproducible: `python docs/evidencia/M2-GATE/run_r6_probe.py <etiqueta> case=<caso>`. Los JSON y volcados de pérdidas están en [20_air](20_air/). Los CSV de reducción se usan para calcular estas filas y no se commitean según E0; la sonda queda versionada.
