> Copia reconstruida desde el texto pegado en chat por el dueño, escrita por Claude el 2026-09-08 con autorización del dueño (D35). Contenido íntegro; solo se normalizaron saltos de línea para que tablas, listas y bloques de código rendericen en Markdown. Si existe el archivo original, reemplazar esta copia por él.

# RUTA FRÁGIL — Documento Maestro de Desarrollo

**GDD + Especificación Técnica + Backlog ejecutable con agentes de IA**

Versión 0.2 (edición Godot) — 7 de septiembre de 2026

Reemplaza a v0.1 (Unity). Cambios mayores: motor Godot 4.7, roadmap de biomas Ciudad → Cerro → Pantano → Submarino → Volcán, modelo "95% IA / humano validador", y las definiciones que faltaban para el MVP (Apéndice D las lista).

Estado: pre-producción · Alcance: vertical slice → demo → Early Access

> "Ruta Frágil" sigue siendo título provisional sin verificar (Apéndice C).

---

# PARTE 0 — PROTOCOLO DE TRABAJO CON IA (leer antes de tocar nada)

Este documento se ejecuta **una tarea por sesión** (Parte 3), con las reglas de §0.3 pegadas al inicio de cada sesión y con validación humana en cada gate (§0.7). Pegarlo entero a un agente esperando "el juego completo" produce un proyecto que compila a medias y nadie puede auditar.

## 0.1 Reparto real del trabajo bajo el modelo "95% IA"

| El agente SÍ hace (≈95% de las líneas) | El humano DEBE hacer (las horas que deciden) |
|---|---|
| Todo el GDScript (gameplay, red, UI, herramientas, tests) | Aprobar el plan de cada tarea antes de que toque archivos |
| Escenas y recursos como texto (.tscn/.tres) y vía MCP en el editor | Ejecutar el protocolo de validación (§0.7) en cada gate |
| Tests automatizados (gdUnit4) y ejecución headless | Probar multijugador REAL: Mac + Windows con cuentas Steam distintas |
| Depuración con logs, tests y screenshots del editor | Juzgar game feel: manejo, peso, "caos divertido vs frustrante" |
| Contenido data-driven (paquetes, biomas, contratos) | Dirección de arte (style board D16), audio final |
| Scripts de exportación y CI | Cuenta Steamworks, depots, builds, página de tienda, licencias |

**Regla de honestidad:** "95% del código" es alcanzable porque en Godot TODO el proyecto es texto (escenas, recursos, scripts) y se prueba headless. Lo que no es alcanzable es "95% del trabajo": la validación humana es el otro trabajo, y este documento la define como un rol con checklist, no como "mirar si funciona".

## 0.2 Setup de herramientas

- **Godot 4.7.2 stable** (ADR-000, §15). Descargar el binario oficial en ambas máquinas y fijar la versión en `README.md` y en `project.godot` (`config/features`). Godot no tiene Hub: la disciplina de versión es manual.
- **Lenguaje:** GDScript con tipado estático obligatorio (ADR-005). Nada de C# sin ADR aprobado.
- **Tests:** gdUnit4 (addon) ejecutado headless desde CLI. Todo sistema de gameplay entrega con tests (R13).
- **Puente editor↔agente (MCP):** opciones vigentes, todas comunitarias — Godot AI (hi-godot, de los creadores de MCP for Unity, requiere 4.5+), godot-mcp (hybridindie, primera versión estable sept. 2026), Godot MCP/CLI (addon para 4.7). El agente elige uno en M0-T0.1 y lo documenta. La mayoría del trabajo NO necesita MCP: los archivos son texto y el juego corre headless.
- **Cliente de agente:** cualquiera con MCP y lectura de imágenes (Kimi Code, Claude Code, Cursor…).
- **Git desde el día 0**, una rama por tarea, el agente nunca en `main`. Godot guarda escenas y recursos en texto: los diffs son legibles y revisables — es la razón de fondo por la que el modelo 95% IA es viable aquí.

## 0.3 Reglas permanentes del agente (pegar en CADA sesión; mantener en `AGENTS.md`)

```
REGLAS DEL PROYECTO RUTA FRÁGIL — OBLIGATORIAS EN TODA SESIÓN (v0.2 Godot)
R1  Nunca hardcodear el número de jugadores. Leer siempre GameConfig.max_players.
    Toda UI de lobby/HUD se genera dinámicamente para N jugadores.
R2  Todo contenido (paquetes, biomas, contratos, herramientas, sistemas del bus)
    se define en Resources (.tres) con espejo JSON en res://data/ y carga desde
    user://mods/. Prohibido definir contenido en código.
R3  GDScript con tipado estático en TODAS las declaraciones (variables, parámetros,
    retornos). Prohibido C#, GDExtension o addons nuevos sin ADR aprobado.
R4  Autoridad de red: el peer con autoridad sobre el bus (ADR-006) simula el bus y
    los paquetes sueltos en su interior; el host es dueño de economía, contratos,
    spawns y estado de sistemas. Nadie simula física de lo que no le pertenece.
R5  Prohibido agregar addons/dependencias sin aprobación humana explícita.
R6  Una tarea por sesión. No tocar archivos fuera del alcance declarado en el plan.
R7  Antes de declarar una tarea terminada: (a) el proyecto abre sin errores en
    consola, (b) los tests gdUnit4 pasan en headless, (c) los criterios de
    aceptación se probaron con evidencia adjunta (salida de tests, log, screenshot).
    Si un criterio no se puede probar desde CLI/editor, decirlo; nunca marcarlo.
R8  Scripts de máximo 400 líneas; escenas de máximo 60 nodos. Si crece, dividir.
R9  Código, nodos y archivos en inglés, snake_case. Comentarios solo para el porqué.
R10 No dejar TODOs silenciosos: todo pendiente se registra en BACKLOG.md.
R11 No inventar APIs. Verificar en la documentación de Godot 4.7 / GodotSteam antes
    de escribir; si hay duda, pedirla.
R12 Ediciones destructivas (borrar archivos, reescribir escenas existentes)
    requieren confirmación humana previa.
R13 Todo sistema de gameplay nuevo entrega con al menos un test gdUnit4 que lo
    ejercite sin editor abierto.
R14 Escenas y recursos siempre en formato texto (.tscn/.tres). Prohibido .scn/.res
    binarios. Prohibido cifrar scripts (moddabilidad, D11).
```

## 0.4 Protocolo por tarea

1. Humano pega: reglas §0.3 + tarea completa (Parte 3) + rutas relevantes.
2. Agente responde con **plan** (archivos, enfoque, riesgos). Humano aprueba o corrige.
3. Agente implementa → `godot --headless` corre tests → adjunta evidencia.
4. Humano ejecuta el **GATE** (§0.7). Solo entonces merge.
5. Tres intentos fallidos = detenerse y replantear, no forzar.

## 0.5 Plantilla de prompt por tarea

Apéndice A. Usarla textual.

## 0.6 Entorno dual Mac + Windows (reglas duras)

1. Misma versión exacta de Godot (4.7.2) en ambas máquinas; nadie abre el proyecto con una versión más nueva "para probar".
2. Git con LFS para binarios (glb, png, wav, ogg). `.godot/` (caché de importación) jamás se versiona. Escenas/recursos en texto (R14) hacen los diffs revisables.
3. Renderer **Forward+** (Vulkan). En macOS corre sobre MoltenVK: todo shader nuevo se verifica en ambas máquinas antes de cerrar su tarea.
4. Máquina de referencia de performance: la más débil. Los gates de 60 fps corren ahí.
5. Red real: gate M4 entre la Mac y el Windows con dos cuentas Steam distintas (AppID 480 mientras no haya App ID propio). Desarrollo diario en LAN con ENet, sin Steam.
6. Distribución: Windows primero. macOS = post-lanzamiento (firma/notarización Apple).

## 0.7 Protocolo de validación humana (el "otro" trabajo del modelo 95% IA)

El humano no revisa código; valida comportamiento. Cada gate tiene una lista y cada ítem se marca **PASA / FALLA / NO PROBADO** con una nota de una línea. Un gate con cualquier FALLA bloquea el milestone.

**Qué significa "concreto" (D26):** concreto = **jugable**, no = con arte. Un bus gris que se conduce es concreto; un bus bonito que no se conduce es un boceto. Las físicas se validan sobre greybox (M1–M3) porque es cuando cambiarlas cuesta horas; validarlas sobre assets finales es el orden más caro posible. El dueño declaró que valida: físicas, funcionalidad del bus y de los paquetes, assets y texturas generados; diálogos de NPC y sonido quedan para M8.

| Gate | Qué valida el humano (ejemplos; la lista completa vive en cada milestone) |
|---|---|
| Cada tarea | Los criterios ✅ se cumplen jugando, no leyendo el reporte del agente. |
| M1 | **Primera validación del dueño (físicas + bus, sobre greybox):** conducir 3 minutos en el Playground: ¿controlable, con peso, sin tumbarse solo? |
| M2 | Con 2 instancias locales: caminar dentro del bus a 80 km/h por baches durante 5 min sin jitter ni atravesamientos. |
| M3 | **Paquetes:** 3 min jugando con los 4 tipos: el frágil se rompe con caídas, el flotante escapa por la puerta abierta, el acuático se seca si nadie rocía, el normal aguanta. Pago correcto. |
| M4 | Mac + Windows, 20 min: paquetes en el mismo lugar en ambas pantallas; voz posicional correcta; reconectar entre contratos. |
| M5 | Run completa de 15 min con 4 jugadores; dinero entra y sale; nadie ocioso más de 2 min (pilar 2). |
| Pipeline de arte (paralelo desde M3; gate en M8) | Cada asset generado pasa el checklist §10.1 y respeta el style board D16; texturas sin costuras, sin texto fantasma, sin marcas reales. Ningún modelo con licencia territorial restringida (§10.2). |
| M8 | Tres grupos externos: ≥2 piden seguir jugando. Sonido y líneas de NPC (§11) se validan aquí, no antes. |

Regla: si el humano no puede reproducir lo que el agente reporta, la tarea NO está hecha (R7).

## 0.8 Autonomía del agente: qué corre sin humano y qué no (agregado tras la razón declarada de D17)

La razón del cambio a Godot es que la IA pueda **desarrollar y probar sin un humano en cada iteración**. Eso es cierto para una clase de pruebas y falso para otra; esta es la frontera exacta.

**El agente ejecuta sin supervisión, tantas veces como quiera:**

- Correr el proyecto en headless (`godot --headless`) y los tests gdUnit4: unitarios y de simulación (decaimiento de paquetes, ventanas de sincronía de `CoopInteractable`, física del bus en el circuito automático del Playground — Jolt corre sin render).
- **Pruebas de red multi-instancia automáticas (T0.4):** lanzar 1 host + N clientes headless en procesos separados sobre ENet en la misma máquina, ejecutar un guion scriptado y afirmar convergencia de estado (posiciones de paquetes, dinero, ocupación de puestos, cambio de autoridad del bus). Esto no era posible sin editor en Unity; es la ventaja concreta de D17.
- Exportar builds por CLI a una carpeta de staging (nunca subirlas).
- Capturar screenshots por script en una ejecución con ventana (en la máquina de desarrollo) y compararlas contra referencias.
- Iterar código → test → código hasta que todo esté verde, sin pedir permiso entre iteraciones.

**El agente NO hace sin humano, nunca:** merge a `main` · crear o cambiar ADRs · agregar dependencias (R5) · borrar o reescribir escenas (R12) · tocar Steamworks, subir builds o gastar dinero · marcar un gate como pasado · declarar que algo "se siente bien".

**Lo que ninguna prueba automática mide (por eso existen los gates §0.7):** jitter *perceptible*, game feel, diversión, legibilidad visual, calidad de voz, comportamiento bajo latencia real de internet y con cuentas Steam reales. Un test verde en headless dice "la lógica converge"; no dice "es jugable". La supervisión no desaparece: **se mueve de cada iteración a cada gate.** Un agente que reporta verde sin que un humano lo reproduzca es exactamente cómo un co-op llega a Steam con 40% de reseñas positivas.

---

# PARTE 1 — GAME DESIGN DOCUMENT

## 1. Visión

### 1.1 Pitch

Co-op online de 1–4 jugadores (escalable) donde la tripulación vive dentro de un bus de reparto caminable. Cada bioma ataca la carga de una forma distinta; cada paquete exige cuidados activos durante el viaje; y las tareas críticas requieren coordinación real entre jugadores (acciones sincronizadas, §3.4). Overcooked sobre ruedas.

### 1.2 Pilares (todo feature nuevo debe pasar los 3)

1. **La carga es el jefe final.** ¿Este feature hace que algún paquete exija atención activa?
2. **Nadie mira por la ventana.** ¿El jugador 4 tuvo tareas ≥60% del tiempo?
3. **El desastre es gracioso y clippeable.** ¿El fallo produce un momento grabable?

### 1.3 Progresión de biomas (visión completa) y alcance

Ciudad (tutorial) → Cerro (escalada del bus) → Pantano (flotar) → Submarino (aire y carga seca) → Volcán (calor). **MVP y demo = Ciudad + Cerro + Pantano.** Submarino y Volcán se diseñan ahora (para que el modelo de datos los soporte) y se construyen en Early Access. Los biomas de la v0.1 que ya no están (Islas, Bosque, Desierto, Ártico, Viento) quedan eliminados; sus mejores mecánicas se absorben: lianas en Pantano, calor/radiador en Volcán.

### 1.4 Referencias y anti-referencias

Tomar de: Lethal Company (contratos/cuota, voz por proximidad, recuperar cuerpos), R.E.P.O. (pago por integridad física), Pacific Drive (vehículo como personaje), Overcooked/Moving Out (caos por tareas), Barotrauma (inundación y aire, para Submarino), Snowrunner (winche). Anti-referencias: Totally Reliable Delivery Service (sin progresión), simuladores realistas.

### 1.5 Datos comerciales

PC/Steam · EA USD 9.99–14.99 · sesiones 20–40 min · 1–4 online (arquitectura probada a 8) · ES/EN desde el día 0 (Godot tiene traducción CSV nativa).

## 2. Loop principal

```
HUB → elegir CONTRATO → CARGAR bus (Tetris físico + amarrar) → RUTA (15–35 min)
→ ENTREGAS (pago por integridad y tiempo) → REGRESO → GASTOS → cuota cada 3 contratos
```

- **Contrato:** bioma, lista de paquetes con destino cada uno, número de entregas, pago base, bonus tiempo, modificadores, herramientas recomendadas (`ContractDefinition`).
- **Cuota de arriendo** cada 3 contratos; no pagar = quiebra de la empresa (reinicio de dinero/herramientas; se conservan cosméticos y estadísticas).
- **Derrota de run:** bus destruido, hundido sin rescate, o tripulación completa muerta → se pierde la carga, se conserva 25% de lo ganado.
- **Definición de ENTREGA (nueva en v0.2):** cada destino tiene una zona de entrega (Area3D) frente a la puerta del NPC. Entregar = colocar el paquete dentro de la zona + tocar el timbre. El contrato dice qué paquete va a qué dirección: paquete equivocado = rechazo (pago 0, el paquete vuelve a tus manos) — obliga a coordinar quién lleva qué.

## 3. La tripulación

### 3.1 Sin clases

Roles emergentes: Conductor / Navegante (mapa físico, radio del cliente) / Mecánico (paneles) / Cargador (correas, cojines, rociador, flotadores). Cualquiera hace cualquier cosa; la gracia es negociarlo a gritos.

### 3.2 Regla de oro

Toda amenaza exterior genera ≥1 tarea interior.

### 3.3 Interacciones base

Agarrar/soltar/lanzar (un objeto grande o dos pequeños) · amarrar con correas a anclajes · operar paneles, manivelas, extintor, rociador, bomba · empujar en grupo.

### 3.4 Acciones cooperativas sincronizadas (sistema núcleo, nuevo en v0.2)

Componente `CoopInteractable` con N puestos (2–4). Tres modos:

- **Concurrente:** progresa solo mientras ≥ `required_slots` están ocupados (levantar un paquete pesado, tensar el winche: 1 persona = lento, 2 = rápido).
- **Sincronizado:** los ocupantes deben pulsar dentro de una ventana común (0.5 s) tras una cuenta visible "3-2-1"; acierto suma un golpe de progreso, fallo resta (enderezar bus volcado, arrancar el motor ahogado, sellar la escotilla en Submarino).
- **Relevo:** una acción larga que un ocupante puede sostener mientras otro hace otra cosa (bombear agua mientras alguien parcha la fuga).

Reglas: el peer con autoridad del objeto resuelve el progreso; la ocupación de puestos y el progreso se replican; cada uso muestra quién está en cada puesto (legible para el clip). Toda tarea "épica" del juego se construye sobre este componente, no como código especial.

## 4. El bus (style board D16, **enmendado por D100 el 2026-09-17**: furgón largo de reparto de carrocería única sin cabina separada, morro cab-over, **lateral ciego** con ventanas pequeñas altas, puerta lateral corredera con estribo, puertas traseras dobles de carga, librea amarillo/rojo, techo crema. Las «ventanas corridas» de la v0.2 quedan RETIRADAS: hacían que el vehículo leyera como autobús escolar. Láminas: `docs/referencias/bus_exterior_canonico_v2.png`, `bus_exterior_trasera_v2.png`, `bus_interior_canonico_v1.png`)

### 4.1 Recursos (tres relojes)

| Recurso | Comportamiento | Se recupera con |
|---|---|---|
| Combustible | Drena por velocidad, pendiente y lodo; 0 = motor muerto (se empuja). **Tanque chico a propósito: no alcanza para una ruta completa** (§4.7). | Bidones llenados en zonas de combustible de la ruta (gratis, cuesta tiempo) o estación (pagado, rara) |
| Integridad 0–100 | Golpes, hazards, sistemas dañados; 0 = inutilizado salvo rescate | Kit (+25 en ruta), estación (total) |
| Desgaste | Reduce el máximo de Integridad con el uso | Solo mantención en estación |

Blindaje: consumible que agrega una barra previa a la Integridad.

### 4.2 Sistemas internos (paneles físicos operables)

| Sistema | Falla → consecuencia | Bioma que lo estresa |
|---|---|---|
| Motor | Pérdida de potencia, drena Integridad | Todos |
| Radiador | Sobrecalentamiento, humo tapa la visión | Cerro, Volcán |
| Anclajes de carga | Paquetes sueltos rebotan | Cerro, Pantano |
| Flotadores (4 puntos externos) | Sin ellos el bus se hunde en agua profunda | Pantano |
| Bomba de achique | Inundación interior: paquetes se mojan/flotan | Pantano, Submarino |
| Compresor de burbuja | Fugas → inundación acelerada, aire de jugadores cae | Submarino |
| Escudo térmico | Temperatura interior sube → paquetes se queman | Volcán |

### 4.3 Interior

Cabina con 2 asientos + pasillo central de altura de pie + estanterías con anclajes en ambos muros + banco de herramientas + camilla + puerta lateral de abordaje con escalones + puertas traseras dobles. **6 posiciones útiles** (default 4 jugadores; espacio para mods). Ancho de pasillo: dos jugadores se cruzan.

### 4.4 Personalización

Sin tuning mecánico ni deformación visual (el estado se comunica con humo, chispas, sonido, paneles). Cosméticos sí.

### 4.5 Manejo

Arcade con peso: vel. máx 90 km/h, 0–60 en ~5 s, freno de mano derrapante, volcadura recuperable con acción sincronizada. Física: RigidBody3D con suspensión por raycast (ADR-007).

### 4.6 Aire (recurso de jugador, definido ahora para Submarino)

Cada jugador tiene `air` 0–100. Fuera de una zona con aire (interior del bus con burbuja, superficie) baja 1.1/s (≈90 s). En 0 → Derribado; sigue bajando → Muerto. Tanque de oxígeno portátil: +90 s. En MVP el recurso existe pero solo se activa en agua profunda del Pantano (ahogo = 30 s).

### 4.7 Combustible: bidones y zonas (D28, nuevo)

El combustible es un **loop de recolección física**, no una barra que se llena en un menú.

- **Bidón:** prop físico de 10 L (mismo sistema que los paquetes: se agarra con las dos manos, se amarra, se cae, ocupa volumen del Tetris). Estado `fuel_liters 0–10` visible en el modelo. Se encuentran vacíos en la ruta (puntos fijos por bioma) o se compran en estación.
- **Zonas de combustible:** 1–2 por ruta, en ramas cortas fuera del camino principal (el desvío cuesta tiempo del contrato; el combustible es gratis). Tipos: surtidor abandonado (ilimitado, 20 s por bidón, 10 s con dos personas — `CoopInteractable` concurrente), barriles (10–30 L aleatorios, 15 s). Roadmap: sifonear vehículos abandonados.
- **Vertido:** toma exterior en el costado del bus. Verter tarda 8 s por bidón. Con el bus en movimiento se puede verter colgado de la puerta lateral, pero se derrama un % proporcional a la velocidad (y el derrame es un gancho para fuego en Volcán).
- **Estaciones:** raras (máximo 1 por contrato), venden combustible a precio y bidones vacíos. Son la opción cara y segura; las zonas son la barata y lenta.
- **La decisión que crea:** cada bidón a bordo es espacio que no lleva paquetes. Más combustible = menos carga = menos pago. Esa tensión es el diseño; si el tanque alcanzara para toda la ruta, el sistema entero sobraría — por eso los números de §8.1 hacen el tanque insuficiente a propósito.
- **Rol emergente:** "Abastecedor" — quien cuenta litros, decide el desvío y vierte en marcha. Tarea interior nueva para el pilar 2.

## 5. Paquetes

### 5.1 Estados runtime

`integrity 0–100` · `moisture 0–100` · `temperature °C` · `restraint {free, held, strapped}`

### 5.2 Regla general (nueva en v0.2)

Cada `PackageDefinition` declara rangos: `moisture_min/max` y `temp_min/max`. Fuera de rango, pierde integridad por segundo. Así "el acuático debe estar mojado" y "el electrónico no se puede mojar" y "nada se quema en el volcán" son el MISMO sistema con datos distintos.

### 5.3 Tipos MVP (valores v0, tunear en playtest)

| Tipo | Regla | Tarea | Valores v0 |
|---|---|---|---|
| Normal | Solo golpes fuertes; se moja mal | Ubicar y olvidar | moisture_max 60 (−0.3/s fuera), impacto >3 m/s = −10 |
| Frágil | Golpes, caídas y vibración acumulada | Acolchar, sostener, avisar | impacto >2 m/s = −10; camino roto −0.5/s sin cojín |
| Flotante | Sube sin correa; se escapa por puertas/ventanas abiertas | Amarrar siempre | fuerza ascensional 15 N |
| Acuático | Debe mantenerse húmedo | Rociar periódicamente | moisture_min 40, decae 0.8/s, −1 integridad/s bajo mínimo |

Roadmap: Seco/Electrónico (moisture_max 10 — estrella de Submarino), Congelado, Vivo, Explosivo, VIP.

### 5.4 Pago

`pago = base × (integrity/100) × mult_tiempo` (1.25 si <70% del tiempo, 1.0 a tiempo, 0.7 tarde). 100% = propina + reacción especial del NPC.

### 5.5 Carga en el hub

Tetris físico: volumen finito, amarrar es estrategia.

## 6. Mundo y biomas

### 6.1 Estructura

**Juego lineal, no mundo abierto (D28):** cada contrato es una ruta A→B con ramas cortas y atajos con riesgo. Las zonas de combustible y los bidones vacíos viven en esas ramas: desviarse cuesta tiempo del contrato, seguir recto arriesga quedarse sin combustible. Cada bioma = set de rutas + amenazas + una herramienta nueva.

### 6.2 MVP

**B0 — CIUDAD (tutorial jugable, 10–15 min).** Guion: (1) caminar, agarrar, lanzar; (2) subir al bus, asiento de conductor, conducir a la estación; (3) repostar en la estación y comprar un bidón vacío; (3b) desvío a la primera zona de combustible: llenar el bidón (más rápido entre dos) y verterlo en la toma exterior; (4) cargar 2 paquetes y amarrarlos; (5) primera entrega con timbre; (6) lomo de toro con un frágil (lección de acolchar); (7) túnel bajo con un flotante en el techo (lección de amarrar); (8) reparar; (9) cobrar y explicar la cuota. No se puede perder; se paga poco si se hace mal.

**B1 — CERRO**

| Amenaza exterior | Tarea interior | Herramienta |
|---|---|---|
| Pendientes que el motor no sube | Aligerar / empujar / winche a poste o roca (acción concurrente) | Winche + cuerda |
| Caminos rotos, baches | Acolchar frágiles, re-tensar correas | Cojines |
| Sobrecalentamiento | Operar radiador | Bidón de agua |
| Derrumbes menores | Bajarse a despejar mientras alguien vigila la carga | — |
| Caída por ladera | Bus volcado → enderezar (sincronizada) o rescate con winche | — |
| Ruta larga sin estación; subidas duplican el consumo | Racionar bidones; desvío a una zona de combustible en la ladera (se llega con winche) | Bidones |

**B2 — PANTANO (reemplaza a Islas)**

| Amenaza exterior | Tarea interior | Herramienta |
|---|---|---|
| Lodo (velocidad −50%, atascamiento si se frena) | Empujar en grupo; winche a manglar | Winche |
| Canales profundos | Instalar 4 flotadores ANTES de entrar (uno por punto; acción concurrente por flotador) | Flotadores |
| Agua que entra por puertas/escotilla abiertas | Cerrar puertas, subir paquetes sensibles a estantes altos, achicar | Bomba de achique |
| Lianas que bloquean | Bajarse a cortar por turnos (carga desatendida sufre) | Machete |
| Jugador que cae al agua profunda | Aire 30 s; los demás lo sacan con la cuerda | Cuerda |
| Falla catastrófica | Hundimiento → §7.4 | — |

Dato: el acuático es feliz en Pantano; todo lo demás odia la humedad. Pantano es el bioma que valida achique, flotación, aire y rescate — todo lo que Submarino necesitará después.

### 6.3 Roadmap (Early Access; el modelo de datos ya los soporta)

| Bioma | Mecánica única | Tarea interior estrella |
|---|---|---|
| Submarino | Burbuja de aire con fugas; aire de jugadores; carga que no se puede mojar | Parchar fugas (relevo) + compresor + sellar escotilla (sincronizada) + tanques de oxígeno para salir |
| Volcán | Proyectiles con sombra de aviso; ceniza reduce visión; calor del suelo sube la temperatura interior | Vigía en el techo cantando impactos; extintor sobre paquetes; escudo térmico; radiador |

### 6.4 Estaciones de servicio

Raras (máximo 1 por contrato). Repostar (pagado) · Bidones vacíos · Reparar · Mantención · Tienda (herramientas, botiquines, blindaje, flotadores, tanques) · Tablón de contratos secundarios.

### 6.5 NPCs receptores

Timbre + reacción según estado del paquete. VO gibberish. Cero diálogo ramificado.

## 7. Muerte, revivir y rescate

### 7.1 Jugador

`De pie → Derribado (60 s; un compañero lo levanta en 5 s, o 3 s con dos — acción concurrente) → Muerto.`

Revivir a un muerto: llevar el cuerpo a la camilla + botiquín. El cuerpo conserva la mochila.

Fuentes de daño en el MVP: caídas >4 m, atropello por el propio bus, ahogo (aire 0), objetos pesados lanzados (sí, entre jugadores; poco daño, mucho clip), derrumbes en Cerro.

### 7.2 Fantasma acotado

El muerto ve por las cámaras del bus y habla por la radio con estática. No interactúa.

### 7.3 Decisión registrada

Estatuas de revivir estilo PEAK: descartado (base móvil; rompe el pilar 2).

### 7.4 Bus hundido, ahogado o atascado (3 capas)

1. **Rescate manual:** cuerda del winche a anclaje en tierra + manivela concurrente, o flotadores de emergencia bajo el chasis. La carga sufre daño por agua proporcional al tiempo.
2. **Grúa NPC:** por radio; cara, lenta, daña un % de la carga. Sirve también para "atascado sin remedio".
3. **Pérdida total:** fin de run (§2).

### 7.5 Bus volcado

Acción sincronizada de empuje (cuenta 3-2-1). Con un solo jugador vivo: gato hidráulico comprable.

## 8. Economía y progresión

### 8.1 Tabla de tuning v0 (placeholders en `data/tuning.tres`; todos tuneables sin recompilar)

| Parámetro | Valor v0 |
|---|---|
| Dinero inicial | 500 |
| Pago base: Normal / Frágil / Flotante / Acuático | 60 / 120 / 100 / 140 |
| Cuota de arriendo | 900 cada 3 contratos, +15% por ciclo |
| Tanque / consumo / precio combustible | **40 L** / **4 L·km** (×1.5 pendiente, ×2 lodo) / 3 por L en estación; gratis en zonas |
| Bidón | 10 L; vacío cuesta 40 en tienda; vertido 8 s; llenado en surtidor 20 s (10 s con dos); derrame en marcha ∝ velocidad |
| Zonas de combustible | 1–2 por ruta en ramas; surtidor ilimitado; barriles 10–30 L aleatorios; 1–3 bidones vacíos por ruta en puntos fijos |
| Reparación / mantención | 3 por punto de Integridad / 150 fijo |
| Botiquín / Blindaje / Cojín / Flotador (×4) / Bidón / Kit | 120 / 250 / 30 / 80 c/u / 40 / 100 |
| Contrato Ciudad | 3–5 paquetes, 1–3 destinos, **ruta 6–10 km (24–60 L: el tanque no alcanza a propósito)**, objetivo 15–25 min |
| Jugador | caminar 4 m/s, sprint 6 m/s, salto 1 m, alcance de interacción 2.5 m |
| Bus | masa 3000 kg, Integridad 100, Desgaste −5 al máximo por contrato |

### 8.2 Desbloqueos

Por hitos, no por XP: herramientas → biomas → cosméticos. Sin stats de personaje.

## 9. UX / UI / Cámara / Controles

### 9.1 ADR-004 — Cámara: primera persona

Primera persona con manos y cuerpo visibles; el conductor ve desde la cabina y puede alternar a una cámara exterior de persecución. Razón: el interior es estrecho — una cámara en tercera persona colisiona con paredes y estantes constantemente; el género (Lethal Company, R.E.P.O., Content Warning) valida la primera persona para la comedia por voz. Revisitar solo con evidencia de playtest.

### 9.2 Mapa de inputs (teclado/ratón; equivalentes de mando vía Steam Input)

Mover WASD · mirar ratón · **E** interactuar/agarrar (mantener = amarrar) · **clic izq.** lanzar · **clic der.** soltar/colocar con cuidado · **Shift** sprint · **Espacio** salto · **Ctrl** agacharse · **Q** ping ("¡ESO!") · **V** alternar voz (push-to-talk opcional) · **F** linterna · **Tab** puntos de tripulación (quién está en qué puesto). Sin minimapa: el mapa es un objeto físico.

### 9.3 HUD por capas (D29)

El HUD muestra lo que la tripulación necesita para coordinarse, no todo lo que el juego sabe. Cuatro capas:

| Capa | Qué contiene | Quién lo ve | Cuándo |
|---|---|---|---|
| **Diegético (no HUD)** | Tablero del bus: velocímetro, aguja de combustible, temperatura del motor. Nivel visible en el modelo del bidón. Stickers y FX de estado en los paquetes. Integridad como humo/chispas/sonido. | Quien mire | Siempre, en el mundo |
| **Siempre visible** | Retícula · indicador de voz (quién habla) · objeto en manos con estado breve ("Bidón 6/10 L", "Frágil 72%") · cronómetro del contrato · entregas hechas/total | Todos | Toda la ruta |
| **Contextual (aparece solo cuando importa)** | Combustible <20% (espejo del tablero para toda la tripulación: el conductor no siempre lo grita) · aire <70% · compañero derribado con dirección · sistema del bus fallando (ícono + dirección al panel) · zona de combustible cercana (ícono al entrar a la rama) · marcador de entrega al estar a <100 m | Todos | Solo mientras la condición dure |
| **Panel Tab (mantener pulsado)** | Estado completo: combustible en litros, integridad, desgaste, bidones a bordo y sus litros, lista de paquetes con integridad/humedad/temperatura y destino, dinero, próxima cuota, quién ocupa qué puesto | Quien lo abra | A demanda |

Reglas: nada permanente en pantalla que ya esté en el tablero físico; toda alerta contextual tiene sonido propio (accesibilidad y para quien no mira); los valores se leen de los mismos Resources que el juego (nada calculado en la UI); la capa "siempre visible" no crece sin pasar por el D-log.

### 9.4 Accesibilidad v1

Subtítulos de eventos sonoros, modo daltonismo en etiquetas, remapeo completo, reducción de vibración de cámara.

## 10. Arte

Low-poly estilizado según style board D16 enmendado por D100. Las láminas viven en **`docs/referencias/`** (la ruta `Referencias/` que citaba la v0.2 nunca existió): `bus_exterior_canonico_v2.png`, `bus_exterior_trasera_v2.png`, `bus_interior_canonico_v1.png`, `bioma_b0_ciudad_v1.png`, `bioma_b1_cerro_v1.png`, `bioma_b2_pantano_v1.png`. Legibilidad de estado > detalle. Assets externos con licencia comercial verificada en `CREDITS.md`; nada que imite marcas reales.

### 10.1 Pipeline de assets generados con ComfyUI (D27)

`ComfyUI (imagen/3D/textura) → Blender (limpieza) → glTF → Godot`. Ningún asset generado entra al juego sin pasar por Blender y por este checklist; el agente puede operar ComfyUI por su API y Blender por script, pero el checklist lo valida el humano (§0.7).

**Checklist "asset listo para juego":**

1. Escala real (1 unidad = 1 m), pivote en la base o en el punto de agarre, ejes correctos (−Z adelante en glTF).
2. Topología limpia: retopología o decimado a presupuesto — props ≤2k tris, paquetes ≤800, bus ≤25k; sin caras sueltas ni normales invertidas. Los meshes generados salen densos y "derretidos": Blender no es opcional.
3. **Colisión separada y autorada** (primitivas o convex hull simple): la física del juego NUNCA usa el mesh generado como colisión. Esto es lo que hace compatibles "validar físicas" y "usar assets de IA".
4. Una sola textura por asset (atlas o paleta); para el estilo low-poly, la mayoría de los props usan paleta plana y no necesitan textura generada.
5. Texturas generadas: tileables sin costuras, sin texto fantasma, sin logos, ≤1024², en `res://assets/textures/` con su prompt y modelo registrados.
6. Coherencia con D16: comparación lado a lado con el style board antes de aprobar.
7. Registro en `CREDITS.md`: modelo generativo, licencia, fecha, prompt.

### 10.2 Licencias de modelos generativos (bloqueante para publicar)

Steam vende en todo el mundo. Un modelo cuya licencia excluye territorios no puede producir assets que se envíen.

- **Hunyuan3D 2.0 / 2.1 (Tencent): PROHIBIDO para assets que se publiquen.** Su licencia define el Territorio como el mundo excluyendo la Unión Europea, Reino Unido y Corea del Sur, y no aplica en esas regiones. Sirve solo para exploración interna. Hunyuan 3D 3.0 por Partner Nodes es un servicio con sus propios términos: revisarlos antes de usar sus salidas.
- **Trellis (Microsoft, MIT):** permitido. Es la opción por defecto para 3D.
- Imagen/textura: FLUX.1 [dev] es no comercial → prohibido; FLUX.1 [schnell] (Apache 2.0) y SDXL permitidos [verificar versión exacta en `CREDITS.md`].
- Audio: Stable Audio Open y ACE-Step tienen licencias permisivas por debajo de umbrales de ingresos [verificar y registrar].
- Regla: antes de que un modelo produzca cualquier cosa que llegue al build, su licencia (territorio, uso comercial, atribución, umbrales) queda copiada en `CREDITS.md`. Y **todo contenido generado por IA se declara en Steam** al publicar.

## 11. Audio y "diálogos" de NPC

El motor es el instrumento de feedback. Música ligera por bioma que se apaga en crisis. Voz de jugadores: sin oclusión dentro del bus; filtrada fuera y bajo el agua.

- **Generación (D27):** SFX y música con nodos de audio de ComfyUI; voces de NPC en gibberish con TTS. Todo en **M8**, con placeholders libres antes. Mismas reglas de licencia de §10.2 y registro en `CREDITS.md`.
- **No existe sistema de diálogo.** Los NPC reaccionan (júbilo / resignación / portazo) con gibberish y una línea de subtítulo corta tomada de una tabla por estado del paquete. "Diálogos" en este proyecto significa esas tablas de líneas + el texto de sabor de los contratos; se escriben en M8. Un sistema de diálogo ramificado sería una decisión nueva y está fuera de alcance (§14).

## 12. Multijugador (visión de producto)

### 12.1 Sesión

1–4 online, un jugador es host. Lobby e invitaciones por Steam. Drop-in/out solo entre contratos. **Si el host se va, la sesión termina** para todos (sin migración de host en v1; cada jugador conserva su progreso personal).

### 12.2 ADR-008 — Modelo de guardado (nuevo en v0.2)

La **empresa** (dinero, herramientas, desbloqueos, cosméticos del bus, cuota) pertenece al **host**: se juega sobre la empresa del host, como la nave en Lethal Company. Cada jugador conserva su progreso **personal** (cosméticos de personaje, estadísticas) en cualquier sesión. 3 slots de empresa por cuenta. Guardado automático al cerrar cada contrato.

### 12.3 Voz

Siempre integrada: canal 3D por proximidad + radio del bus (2D, toggle). `max_players` configurable: soporte oficial 4, arquitectura y UI probadas a 8.

## 13. Moddabilidad (día 1)

Scripts sin cifrar (R14); contenido en `res://data/` con carga adicional desde `user://mods/*.json` y packs `.pck` (`ProjectSettings.load_resource_pack`); IDs con namespace (`base.package.fragile`); esquemas documentados (Apéndice de datos → wiki). Workshop post-launch.

## 14. Fuera de alcance v1.0 (prohibido construir)

PvP · mundo abierto persistente · consolas · crossplay · servidores dedicados · migración de host · clima dinámico global · deformación del vehículo · stats de personaje · Submarino y Volcán jugables (solo datos y diseño) · Workshop · C# o GDExtension propios.

**Mecánicas futuras (D28):** toda mecánica nueva entra por el D-log con (a) el test de los 3 pilares, (b) el milestone de destino, (c) qué desplaza o qué retuning exige (el combustible obligó a rehacer tanque, consumo y largo de ruta). Nada entra a un milestone ya en curso: se encola al siguiente. "Se irán agregando mecánicas" es una promesa de roadmap, no una licencia para abrir el alcance del MVP.

---

# PARTE 2 — ESPECIFICACIÓN TÉCNICA

## 15. Stack y ADRs

- **ADR-000 — Engine: Godot 4.7.2 stable**, fijado hasta la demo. Godot no tiene LTS en 4.x: cada rama estable se mantiene al menos hasta que la siguiente recibe su primer parche, con cadencia de ~6 meses. Regla: se adoptan solo parches de 4.7.x; el salto a 4.8 se evalúa entre milestones, con backup y tarea dedicada; nunca dev/beta.
- **ADR-005 — Lenguaje: GDScript con tipado estático.** Razón: un solo toolchain en Mac y Windows (sin .NET SDK), addons clave en GDScript, iteración más rápida para el agente. Puertas abiertas: C# o GDExtension solo si el profiler demuestra un cuello de botella en M2/M4.
- **Física: Jolt** (default en Godot desde 4.6). Ticks de física 60 Hz; interpolación de física activada; el bus y los paquetes sueltos pueden subir a 120 Hz si M2 lo exige.
- **Renderer: Forward+** (Vulkan; MoltenVK en macOS).
- **ADR-001 — Red:** API de alto nivel de Godot (`SceneMultiplayer`, `MultiplayerSpawner`, `MultiplayerSynchronizer`, RPCs). Transporte: **ENet** en desarrollo/LAN y **GodotSteam MultiplayerPeer** (relay de Steam, NAT y cifrado incluidos) en release, ambos detrás de una interfaz `NetworkBackend` propia para cambiar de uno a otro sin tocar gameplay. Usar SOLO el MultiplayerPeer oficial de GodotSteam (godotsteam.com): varios forks comunitarios están archivados. Interpolación propia en clientes (buffer 100 ms); netfox se evalúa solo si la interpolación propia no basta.
- **ADR-002 — Voz: Steam Voice vía GodotSteam** (captura `Steam.getVoice` → red → `AudioStreamGenerator` sobre un `AudioStreamPlayer3D` por jugador = proximidad). Regresión registrada respecto a v0.1: no existe Vivox para Godot; la calidad de Steam Voice es menor y la proximidad es artesanal. Alternativa: addon godot-voip. Este es el costo #1 del cambio de motor y se acepta conscientemente.
- **Steam:** GodotSteam GDExtension (lobbies, invitaciones, rich presence, logros, cloud, Steam Input). Editor vanilla, sin compilar Godot.

## 16. ADR-003 (Godot) — Interior caminable en movimiento (EL riesgo técnico)

**Problema:** personajes y paquetes dentro de un vehículo que acelera, salta y se inclina.

**Opción A (elegida, pragmática):**

- Jugadores: `CharacterBody3D` sobre el bus como plataforma móvil (Jolt soporta plataformas cinemáticas; heredan velocidad de la plataforma).
- Paquetes **amarrados**: sin física, hijos congelados del bus (esto es la mayoría de la carga la mayoría del tiempo).
- Paquetes **en mano**: cinemáticos, siguen la mano del jugador.
- Paquetes **sueltos**: `RigidBody3D` reales en espacio de mundo con Jolt; son pocos, y que reboten ES el juego. Si hace falta, tick de física a 120 Hz solo en ruta.
- Fricción alta en el piso del bus y "amortiguador" de velocidad relativa para evitar que un bache expulse todo.

**Opción B (plan B):** re-parentar interior a espacio local del bus con pseudo-fuerzas (`−m·a_bus`) y sincronizar transforms locales.

**Gate M2:** con 2 instancias locales (y luego 4 en LAN), caminar, agarrar y amarrar dentro del bus a 80 km/h sobre baches, 60 fps en la máquina de referencia, sin jitter ni atravesamientos durante 5 minutos. Si A falla 3 iteraciones → B antes de construir nada encima.

## 17. ADR-006 — Autoridad de red (nuevo en v0.2)

- **Bus:** la autoridad de física es del **peer del conductor** mientras está sentado (`set_multiplayer_authority` al sentarse; vuelve al host al pararse). Razón: 100 ms de latencia en el volante arruina el manejo; el dueño-autoridad es el patrón del género para vehículos.
- **Paquetes sueltos dentro del bus:** misma autoridad que el bus (se mueven con él). **Paquete en mano:** autoridad del que lo sostiene. **Amarrado:** sin física, replicado como hijo del bus.
- **Personajes:** autoridad del propio jugador sobre su movimiento (co-op, sin anticheat). Los demás interpolan.
- **Host:** economía, contratos, spawns, estado de sistemas, resultados de `CoopInteractable`, muerte/revivir, cronómetros.
- Tasas: bus 30 Hz; paquetes sueltos 20 Hz snapshot + interpolación; escalares vía `MultiplayerSynchronizer`; eventos discretos vía RPC confiable.
- Reconexión: entre contratos; a mitad de ruta, el reconectado aparece en la camilla.

## 18. ADR-007 — Física del bus

`RigidBody3D` + suspensión por raycast (4 ruedas, resorte/amortiguador por script) en vez de `VehicleBody3D`: control total del feel arcade, comportamiento predecible con Jolt y con la autoridad transferible. Volcadura detectada por producto punto del eje "arriba" del bus.

## 19. Arquitectura de datos

Resources tipados (`class_name`) + espejo JSON: `GameConfig`, `TuningTable`, `PackageDefinition`, `BiomeDefinition`, `ContractDefinition`, `ToolDefinition`, `VehicleSystemDefinition`.

```json
{
  "id": "base.package.aquatic",
  "display_name_key": "pkg_aquatic_name",
  "mass_kg": 8, "size_class": "M", "base_pay": 140,
  "fragility": 0.3, "buoyancy": 0.1,
  "moisture_min": 40, "moisture_max": 100, "moisture_decay_per_s": 0.8,
  "temp_min_c": 4, "temp_max_c": 35,
  "fx_profile": "aquatic_bubbles"
}
```

## 20. Estructura del repo

```
project.godot   AGENTS.md   BACKLOG.md   CREDITS.md   DECISIONS.md
/addons        (gdUnit4, godotsteam, mcp bridge)
/src           (autoloads, core, vehicle, packages, crew, net, ui, biomes) — .gd + .tscn
/data          (.tres + espejo .json)
/assets        (glb, png, ogg — vía LFS)
/scenes        (playground, hub, b0_city, b1_hill, b2_swamp)
/tests         (gdUnit4, espejo de /src)
/tools         (export.sh / export.ps1, run_tests.sh)
```

Autoloads mínimos: `GameConfig`, `NetworkBackend`, `EventBus`. Nada más global.

## 21. Testing, CI y evidencia (nuevo en v0.2)

- gdUnit4 headless en cada tarea (`godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests` o el comando que el addon documente; el agente lo verifica en M0).
- Tests de simulación sin render: paquete acuático se seca en X s; frágil pierde integridad ante impacto simulado; `CoopInteractable` sincronizada acepta/rechaza ventanas.
- Escena `Playground` con "modo demo automático" (bus conducido por script sobre baches) para que el agente reproduzca bugs de interior sin humano.
- Exportación por CLI para Windows y macOS (`--export-release`) desde M4; el humano sube a Steam.

## 22. Steam / release

App ($100), depots dev/demo/release, demo separada (B0 + B1 recortado) para Steam Next Fest, Playtest previo (20–50 personas), tráiler de 30 s de caos con voz real.

---

# PARTE 3 — BACKLOG EJECUTABLE (M0–M8)

> Orden obligatorio. M2 y M4 son los riesgos y van temprano. Cada ✅ lo verifica el humano según §0.7.

## M0 — Fundaciones

- **T0.1** Proyecto Godot 4.7.2, Forward+, Jolt, estructura §20, Git+LFS, `AGENTS.md`, gdUnit4 corriendo headless con un test trivial, puente MCP elegido y documentado. ✅ *Acepta:* `run_tests` pasa en ambas máquinas; commit inicial.
- **T0.2** `GameConfig` + `TuningTable` (Resources + JSON) con loader que fusiona `user://mods/`. ✅ *Acepta:* cambiar un JSON sin reabrir el editor altera el juego; un JSON en mods sobreescribe base; test cubre la fusión.
- **T0.3** Escena `Playground` (plano, rampas, baches, agua) + modo demo automático (§21). ✅ *Acepta:* existe, carga, el bus placeholder recorre el circuito solo.
- **T0.4** Arnés de pruebas de red multi-instancia (§0.8): script que lanza 1 host + N clientes headless sobre ENet en la misma máquina, ejecuta un guion (spawn, agarrar, amarrar, conducir el circuito automático) y afirma convergencia de estado; integrado en `run_tests`. ✅ *Acepta:* 1 host + 3 clientes headless completan el guion y los asserts pasan en ambas máquinas; el arnés queda como herramienta permanente y es prerrequisito del gate M4.

## M1 — Bus y conducción (single, local)

- **T1.1** ADR-007: bus con suspensión por raycast, cámara conductor + exterior (§9.1). ✅ *Gate humano de feel (3 min).*
- **T1.2** Recursos Combustible/Integridad/Desgaste; motor muere en 0; empuje. Bidón como prop físico con `fuel_liters`; toma exterior con vertido de 8 s y derrame en marcha. ✅ *Acepta:* tablero placeholder muestra valores; tests de drenaje, vertido y derrame; el bidón se cae si no está amarrado.
- **T1.3** Estación (repostar pagado, bidones vacíos, reparar, mantención) con precios desde `TuningTable`. ✅ *Acepta:* ciclo dinero→servicio; comprar un bidón lo hace aparecer como prop.

## M2 — Interior caminable ⚠️ RIESGO #1

- **T2.1** Interior grey-box según §4.3 (6 posiciones, pasillo de doble ancho).
- **T2.2** Personaje primera persona (`CharacterBody3D`) sobre plataforma móvil; entrar/salir por puertas con el bus andando.
- **T2.3** Agarrar/soltar/lanzar + amarrar (`restraint`) + los tres estados físicos de ADR-003.
- ✅ **GATE M2 (duro, §0.7):** criterio de ADR-003 con 2 instancias locales. Si falla 3 veces → Opción B. Nada de M3+ sin este gate.

## M3 — Paquetes y acciones cooperativas

- **T3.1** `PackageDefinition` + estados + 4 tipos MVP con FX placeholder + tests de decaimiento.
- **T3.2** Herramientas de cuidado (rociador, cojines) y `CoopInteractable` con los tres modos (§3.4), con tests de ventana de sincronía.
- **T3.3** Entrega (zona + timbre + destino correcto/incorrecto) + scoring + pantalla de resultados. ✅ *Acepta:* recorrido de 3 min con 6 paquetes mixtos produce pagos correctos; el flotante se escapa si nadie lo ata; paquete a la dirección equivocada = rechazo.

## M4 — Red y voz ⚠️ RIESGO #2

- **T4.1** `NetworkBackend` con ENet (LAN): lobby, spawn de N jugadores (R1), personajes con autoridad propia.
- **T4.2** ADR-006 completo: autoridad del bus al conductor, paquetes sueltos/en mano/amarrados, `CoopInteractable` replicado, snapshots + interpolación.
- **T4.3** Backend Steam (GodotSteam MultiplayerPeer): lobby, invitar, relay. Mismo gameplay, cero cambios fuera de `NetworkBackend`.
- **T4.4** Voz Steam por proximidad + radio + indicador de quién habla.
- ✅ **GATE M4 (duro):** Mac + Windows en máquinas separadas, 20 min: paquetes coinciden en ambas pantallas; cambio de conductor sin tirones; voz posicional; reconexión entre contratos; medir ancho de banda con 30 paquetes.

## M5 — Loop económico + B0 Ciudad

- **T5.1** Contratos data-driven + tablón + cuota + guardado ADR-008 (empresa del host, progreso personal).
- **T5.2** B0 Ciudad grey-box con el guion de tutorial de §6.2, NPCs con reacciones, y 1–2 zonas de combustible en ramas (surtidor + barriles) con bidones vacíos en puntos fijos; la ruta mide 6–10 km para que el tanque no alcance.
- **T5.3** Carga tipo Tetris. ✅ *Acepta:* run completa de 15 min, 4 jugadores en LAN, dinero entra y sale, nadie ocioso >2 min.

## M6 — B1 Cerro + muerte/revivir

- **T6.1** Winche/cuerda (concurrente), pendientes que lo exigen, derrumbes.
- **T6.2** Derribado/muerto/camilla/botiquín/fantasma; fuentes de daño §7.1.
- **T6.3** Radiador + sobrecalentamiento; volcadura + enderezado sincronizado. ✅ *Acepta:* run de 25 min con un rescate por winche y una reanimación, sin softlocks.

## M7 — B2 Pantano + hundimiento/rescate

- **T7.1** Lodo (fricción/velocidad/atascamiento), lianas y machete.
- **T7.2** Flotadores instalables (4 puntos, concurrente) + flotación del bus; agua profunda; aire de jugador (§4.6) y rescate con cuerda.
- **T7.3** Inundación interior + bomba de achique (relevo) + daño por agua; protocolo §7.4 completo. ✅ *Acepta:* hundir el bus a propósito y recuperarlo por las 3 vías; el acuático sobrevive feliz, el frágil no; un jugador se ahoga y es rescatado.

## M8 — Producto

- **T8.1** Pase de arte según D16 (bus, paquetes, B0–B2, personajes) + audio.
- **T8.2** UX final, tutorial pulido, pings, accesibilidad, ES/EN.
- **T8.3** Steam: logros, cloud, rich presence, export CLI, demo. ✅ **GATE M8:** 3 grupos externos de 4; ≥2 piden seguir jugando.

Post-M8: Playtest → Next Fest → Early Access con B0–B2. Roadmap público: Submarino, luego Volcán, con tipos de paquete nuevos intercalados.

---

# PARTE 4 — RIESGOS TOP

| # | Riesgo | Mitigación |
|---|---|---|
| 1 | Interior caminable falla | ADR-003 con plan B y gate duro M2 |
| 2 | Desync / tirones al cambiar de conductor | ADR-006 (autoridad al conductor), gate M4 entre máquinas reales |
| 3 | Voz de menor calidad que la competencia Unity (Vivox) | Aceptado; medir en M4; godot-voip como alternativa; la comedia depende más de la latencia baja que de la fidelidad |
| 4 | Pocos precedentes de co-op 3D con física en Godot; addons pequeños o archivados | Solo GodotSteam oficial; `NetworkBackend` propio aísla dependencias; nada nuevo sin ADR |
| 5 | Confianza ciega en código generado | §0.7, R7, R13: sin tests y sin validación humana, no está hecho |
| 6 | Alcance se infla (5 biomas "ya que están diseñados") | §14: Submarino y Volcán prohibidos en v1 |
| 7 | Nicho saturado | Demo temprana; diferenciador = tripulación + acciones sincronizadas |
| 8 | Nombre sin verificar | Apéndice C antes de cualquier anuncio |

---

# APÉNDICE A — Plantilla de prompt por tarea

```
CONTEXTO: Proyecto "Ruta Frágil" (Godot 4.7.2, GDScript tipado). Obedece R1–R14 (abajo).
[pegar reglas §0.3 completas]
TAREA: [id y texto completo desde la Parte 3]
ARCHIVOS RELEVANTES: [rutas exactas]
CRITERIOS DE ACEPTACIÓN: [copiar los ✅]
INSTRUCCIONES:
1. Responde PRIMERO con un plan (archivos a crear/modificar, enfoque, riesgos). No toques nada aún.
2. Tras mi aprobación, implementa.
3. Corre los tests gdUnit4 en headless y adjunta la salida; adjunta screenshot si hay algo visual.
4. Lista qué criterios NO pudiste verificar desde CLI/editor para que yo los valide (§0.7).
```

# APÉNDICE B — Definition of Done

Abre sin errores en consola · tests gdUnit4 pasan headless · criterios probados con evidencia · gate humano ejecutado (§0.7) · sin TODOs silenciosos · contenido en datos, no en código · escenas/recursos en texto · merge a `main` referenciando la tarea.

# APÉNDICE C — Nombre y propiedad intelectual

Buscar el nombre en Steam · INAPI (Chile), USPTO, EUIPO clases 9 y 41 · dominio y redes · registrar antes del anuncio · `CREDITS.md` con licencias · nada de trade dress de marcas reales · las mecánicas ajenas no son infracción; arte, nombres, música y código sí · **auditoría de licencias de modelos generativos (§10.2): territorio, uso comercial, atribución, umbrales de ingresos** · **declaración de contenido generado por IA en Steam** al enviar el build y la página.

# APÉNDICE D — Definiciones agregadas en v0.2 (lo que faltaba para construir el MVP)

1. Cámara y perspectiva (ADR-004, primera persona). 2. Mapa de inputs y verbos (§9.2). 3. Definición operativa de ENTREGA y destino correcto (§2). 4. Sistema de acciones cooperativas sincronizadas (§3.4). 5. Modelo de guardado y propiedad de la empresa (ADR-008). 6. Qué pasa si el host se va (§12.1). 7. Autoridad de red por objeto, incluido el conductor (ADR-006). 8. Física del bus (ADR-007). 9. Tabla de tuning v0 con números (§8.1). 10. Fuentes de daño al jugador por bioma (§7.1). 11. Recurso de aire del jugador (§4.6). 12. Regla general de humedad/temperatura por paquete (§5.2). 13. Guion del tutorial B0 (§6.2). 14. Pantano definido (lodo, flotadores, achique, lianas, ahogo) y Submarino/Volcán con datos (§6.3). 15. Grúa también para "atascado" (§7.4). 16. Interior con medidas funcionales (§4.3). 17. Testing headless como parte del Definition of Done (§21, R13). 18. Protocolo de validación humana (§0.7). 19. `NetworkBackend` para alternar ENet/Steam (ADR-001). 20. Regla de versión sin LTS para Godot (ADR-000).
