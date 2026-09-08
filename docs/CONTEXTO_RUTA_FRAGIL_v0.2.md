> Copia reconstruida desde el texto pegado en chat por el dueño, escrita por Claude el 2026-09-08 con autorización del dueño (D35). Contenido íntegro; solo se normalizaron saltos de línea para que tablas, listas y bloques de código rendericen en Markdown. Si existe el archivo original, reemplazar esta copia por él.

# CONTEXTO_RUTA_FRAGIL.md — Briefing de arranque para agentes de IA

**Versión 0.2 — 7 de septiembre de 2026** (reemplaza a v0.1; la v0.1 queda como historial)

Archivo compañero de: `RUTA_FRAGIL_documento_maestro_v0.2_godot.md` (la fuente de verdad).

---

## 0. Instrucción de arranque — SI ERES UN AGENTE, ESTO ES LO PRIMERO QUE OBEDECES

1. Lee este briefing completo. 2. Lee el documento maestro v0.2 completo. 3. No ejecutes NINGUNA acción sin una tarea del backlog (Parte 3 del maestro) o instrucción explícita del humano. 4. Jerarquía: maestro > briefing > tu criterio. 5. Contradicciones se reportan, no se resuelven en silencio. 6. Plan primero, aprobación, después archivos (§0.4 del maestro).

---

## 1. Qué es el proyecto (60 segundos)

**Ruta Frágil** (título provisional, marca sin verificar): co-op online 1–4 jugadores (escalable a 8) donde la tripulación vive dentro de un bus de reparto caminable. Cada bioma ataca la carga de forma distinta, cada paquete exige cuidados activos y las tareas críticas requieren acciones cooperativas sincronizadas. "Overcooked sobre ruedas". PC/Steam, EA USD 9.99–14.99, sesiones 20–40 min. Motor: **Godot 4.7.2**. Pilares: la carga es el jefe final · nadie mira por la ventana · el desastre es gracioso y clippeable.

---

## 2. Estado actual — verdad al 07/09/2026

- **Fase:** pre-producción. NO existe proyecto Godot, ni repositorio, ni código. Nada comprado (sin App ID Steam, sin marca, sin cuenta Apple).
- **Existe:** documento maestro v0.2 (Godot), este briefing, y el style board D16 (dos imágenes canónicas del bus).
- **Cambio de rumbo (D17):** el proyecto migró de Unity a Godot el 07/09/2026 antes de escribir una línea, así que no hay código que portar. Toda decisión técnica de v0.1 marcada SUPERSEDIDA abajo ya no aplica.
- **Equipo:** [COMPLETAR — el dueño no ha confirmado tamaño ni experiencia previa]. Hardware: 1 Mac + 1 Windows.
- **Modelo de trabajo (D19):** la IA escribe ~95% del código; el humano ejecuta el protocolo de validación (§0.7 del maestro) en cada gate.
- **Próximo hito:** Semana 0 → M0-T0.1 (proyecto Godot 4.7.2 + gdUnit4 headless + puente MCP elegido).

---

## 3. Registro de decisiones (D-log)

| # | Decisión | Porqué |
|---|---|---|
| D1 (act. D18) | MVP = Ciudad (tutorial), Cerro, **Pantano**. Submarino y Volcán se diseñan ahora, se construyen en EA. | 5 biomas al lanzamiento es alcance suicida; los éxitos del género lanzaron chicos. |
| D2 | Diferenciador: bus caminable + paquetes con cuidados activos + acciones sincronizadas; toda amenaza exterior genera ≥1 tarea interior. | El nicho "manejar y entregar co-op" está saturado; el hook es la tripulación. |
| D3 | ~~Unity 6.3 LTS~~ **SUPERSEDIDA por D17.** | — |
| D4 | ~~NGO + Facepunch~~ **SUPERSEDIDA por D21.** | — |
| D5 | ~~Vivox~~ **SUPERSEDIDA por D22.** | — |
| D6 (act.) | ADR-003 interior caminable, versión Godot: amarrado = hijo congelado, en mano = cinemático, suelto = RigidBody3D Jolt; jugadores CharacterBody3D sobre plataforma móvil. Gate duro M2, plan B = espacio local. | Sigue siendo EL riesgo técnico; se valida antes de construir encima. |
| D7 | Revivir en camilla del bus + botiquín + recuperar el cuerpo. Estatuas tipo PEAK descartadas. | Base móvil; separar el revivir del vehículo rompe el pilar 2. |
| D8 (act.) | Bus hundido, ahogado **o atascado**: rescate manual → grúa NPC pagada → pérdida total (run fallida, conserva 25%). | El fracaso es gameplay primero y castigo después. |
| D9 | Recursos del bus: Combustible / Integridad / Desgaste separados + Blindaje consumible. | Dos relojes crean decisiones distintas. |
| D10 | Sin tuning mecánico ni deformación visual; cosméticos sí. | Alcance; el estado se comunica con humo/sonido/paneles. |
| D11 (act.) | Moddabilidad día 1 en Godot: scripts sin cifrar, contenido en Resources+JSON con carga desde `user://mods/` y packs `.pck`, `max_players` configurable (default 4, probado a 8, bus con 6 posiciones). | La puerta a mods se deja abierta con arquitectura. |
| D12 | Economía: contratos → pago por integridad y tiempo; cuota cada 3 contratos; derrota conserva 25%. Tabla de tuning v0 en §8.1 del maestro. | Sin presión no hay tensión; sin fail-forward no hay reintento. |
| D13 (act.) | Entorno dual: misma versión exacta de Godot (4.7.2) en Mac y Windows; Git+LFS para binarios; `.godot/` no se versiona; escenas/recursos en texto; Forward+ (MoltenVK en Mac) → shaders se verifican en ambas; máquina débil = referencia; gate M4 entre ambas máquinas con 2 cuentas Steam. | Dos máquinas sin disciplina de versionado corrompen el proyecto. |
| D14 | Windows primero; macOS post-lanzamiento. | La Mac vale para desarrollo y pruebas de red, no como target v1. |
| D15 (act. D19) | Workflow IA: una tarea por sesión, reglas R1–R14, plan antes de tocar archivos, tests headless obligatorios, gates humanos M2/M4/M8. | "95% IA" solo funciona con verificación humana disciplinada. |
| D16 (24/08/2026) — CERRADA | Style board del bus: interior canónico (`Referencias/bus_interior_canonico_v1.png`) y exterior canónico (`bus_exterior_canonico_v1.png`, guardar tras limpiar texto por inpaint). Bus largo, livrea amarillo/rojo, techo crema, ventanas corridas. La fase de concept del vehículo terminó. | Iterar sin congelar referencia quemaba créditos. |
| **D17 (07/09/2026)** | **Motor: Godot 4.7.2 stable** (ADR-000). Solo parches 4.7.x; salto a 4.8 entre milestones; nunca dev/beta. | **Razón declarada por el dueño:** que la IA pueda desarrollar y probar sin un humano en cada iteración. Se acepta con frontera explícita (§0.8 del maestro): autonomía total de iteración (headless, tests, red multi-instancia, export a staging) y supervisión humana concentrada en los gates — no eliminada. Costos aceptados: sin Vivox, menos precedentes de co-op 3D con física, addons pequeños o archivados. |
| **D18 (07/09/2026)** | Progresión de biomas: Ciudad → Cerro → Pantano → Submarino → Volcán. Eliminados: Islas, Bosque, Desierto, Ártico, Viento (sus mecánicas se absorben: lianas en Pantano, calor en Volcán). | Cadena coherente de dificultad; Pantano valida flotación, achique y aire antes de Submarino. |
| **D19 (07/09/2026)** | Modelo "95% IA / humano validador": el humano no revisa código, valida comportamiento con checklist PASA/FALLA/NO PROBADO por gate (§0.7 del maestro). | Sin definir la validación, "el humano valida" es una frase, no un rol. |
| **D20 (07/09/2026)** | Cámara en primera persona con manos/cuerpo visibles; conductor con cámara exterior opcional (ADR-004). | Interior estrecho; el género valida primera persona para comedia por voz. |
| **D21 (07/09/2026)** | Red: API de alto nivel de Godot; ENet en desarrollo/LAN, GodotSteam MultiplayerPeer oficial en release, detrás de `NetworkBackend` propio. Autoridad del bus al peer del **conductor** mientras conduce; paquetes sueltos con el bus; en mano con quien los sostiene; host dueño de economía/contratos/sistemas (ADR-001/006). | 100 ms de latencia en el volante arruina el manejo; dueño-autoridad es el patrón del género. |
| **D22 (07/09/2026)** | Voz: Steam Voice vía GodotSteam con proximidad artesanal (AudioStreamPlayer3D por jugador) + radio del bus. Alternativa: godot-voip. Regresión respecto a Vivox aceptada conscientemente. | No existe Vivox para Godot; es el costo #1 del cambio de motor. |
| **D23 (07/09/2026)** | GDScript con tipado estático (ADR-005); física Jolt (default Godot); bus RigidBody3D con suspensión por raycast (ADR-007); renderer Forward+. Sin C#/GDExtension sin ADR. | Un solo toolchain en ambas máquinas; el agente itera más rápido; control total del feel arcade. |
| **D24 (07/09/2026)** | Guardado: la **empresa** pertenece al host (3 slots); progreso personal por jugador; si el host se va, la sesión termina (sin migración de host en v1) (ADR-008). | Modelo Lethal Company; la migración de host es un pozo de complejidad fuera de alcance. |
| **D25 (07/09/2026)** | `CoopInteractable` (concurrente / sincronizado / relevo) como sistema núcleo: toda tarea "épica" se construye sobre él (enderezar bus, winche, flotadores, sellar escotilla, revivir en pareja). | El dueño pidió acciones sincronizadas; un sistema único evita código especial por caso. |
| **D26 (07/09/2026)** | Alcance de validación del dueño: físicas, funcionalidad del bus y de los paquetes, assets y texturas generados. Diálogos de NPC y sonido: al final (M8). **"Concreto" = jugable, no = con arte:** las físicas y el bus se validan sobre greybox en M1–M3, no sobre assets finales. | Validar físicas sobre arte terminado es el orden más caro posible; las primeras validaciones del dueño caen en M1 (conducir) y M3 (paquetes). |
| **D27 (07/09/2026)** | Assets 3D, texturas, SFX/música y voces gibberish se generan con ComfyUI, siempre vía Blender y el checklist §10.1 (colisión autorada, nunca el mesh generado). **Hunyuan3D 2.x prohibido para assets publicados** (licencia excluye UE, Reino Unido y Corea del Sur; Steam es global); Trellis (MIT) por defecto; toda licencia de modelo se copia en `CREDITS.md`; se declara IA en Steam. No existe sistema de diálogo: "diálogos" = tablas de líneas de reacción + texto de contratos, en M8. | Un modelo con territorio restringido convierte cada asset en un pasivo legal; y los meshes generados no son game-ready sin limpieza. |
| **D28 (07/09/2026)** | Combustible como loop de recolección física: tanque chico (40 L) que no alcanza la ruta; bidones de 10 L como props (se agarran, amarran, caen, ocupan volumen de carga); zonas de combustible gratis en ramas de una ruta **lineal** (surtidor, barriles); estaciones raras y pagadas; vertido por toma exterior con derrame en marcha. Retuning: consumo 4 L·km, rutas 6–10 km. **Proceso para mecánicas futuras:** entran por D-log con test de pilares, milestone destino y retuning que exigen; nada entra a un milestone en curso. | Con el tanque de 100 L de la v0 el sistema sobraba; la tensión real es bidones vs paquetes en el mismo espacio de carga. |
| **D29 (07/09/2026)** | HUD por capas: diegético (tablero, bidón, stickers) → siempre visible (retícula, voz, objeto en manos, cronómetro, entregas) → contextual (combustible <20%, aire <70%, compañero derribado, sistema fallando, zona de combustible cercana, marcador de entrega) → panel Tab con el estado completo. Nada permanente que ya esté en el tablero; la capa siempre visible no crece sin D-log. | "Stats en el HUD" sin capas destruye la lectura diegética y el pilar 3; con capas, la tripulación tiene los datos para coordinarse sin pantalla de Excel. |

**Fuera de alcance v1 (prohibido construir):** PvP, mundo abierto persistente, consolas, crossplay, servidores dedicados, migración de host, deformación del vehículo, stats de personaje, Submarino y Volcán jugables, Workshop, C#/GDExtension propios.

---

## 4. Reglas permanentes para agentes (R1–R14) — copia de §0.3 del maestro; si difieren, manda el maestro

```
R1  Nunca hardcodear el número de jugadores. Leer siempre GameConfig.max_players.
R2  Todo contenido en Resources (.tres) con espejo JSON en res://data/ y carga desde user://mods/.
    Prohibido definir contenido en código.
R3  GDScript con tipado estático en TODAS las declaraciones. Prohibido C#/GDExtension/addons sin ADR.
R4  Autoridad de red según ADR-006: el peer con autoridad del bus simula bus y paquetes sueltos;
    el host es dueño de economía, contratos, spawns y sistemas. Nadie simula lo que no le pertenece.
R5  Prohibido agregar addons/dependencias sin aprobación humana explícita.
R6  Una tarea por sesión. No tocar archivos fuera del alcance declarado.
R7  Terminado = abre sin errores + tests gdUnit4 pasan headless + criterios probados con evidencia.
    Lo que no se puede probar se declara; nunca se marca como cumplido.
R8  Scripts ≤400 líneas; escenas ≤60 nodos.
R9  Código, nodos y archivos en inglés, snake_case.
R10 Todo pendiente se registra en BACKLOG.md.
R11 No inventar APIs: verificar en docs de Godot 4.7 / GodotSteam.
R12 Ediciones destructivas requieren confirmación humana previa.
R13 Todo sistema de gameplay entrega con ≥1 test gdUnit4 ejecutable sin editor.
R14 Escenas y recursos en texto (.tscn/.tres). Prohibido binarios y cifrado de scripts.
```

---

## 5. División del trabajo

- **Cowork (conocimiento):** mantener los .md (proponiendo cambios), textos de Steam, briefs de arte/audio, investigación, checklist de marca, actualizar este briefing al cierre de sesión. NO toca el proyecto Godot.
- **Agente de código (Kimi Code / Claude Code + MCP de Godot o solo archivos + CLI headless):** ejecutar M0–M8 bajo R1–R14.
- **Humano (no delegable):** protocolo de validación §0.7 en cada gate, pruebas Mac+Windows, game feel, arte final, Steamworks, compras y licencias, decisiones.

## 6. Estilo de colaboración que exige el dueño

Sin halagos ni acuerdos automáticos; desafiar supuestos primero · etiquetar confianza [Seguro]/[Probable]/[Adivinando] · desacuerdo con estructura (razón → alternativa → riesgo) · la verdad incómoda en la primera línea · máximo una pregunta por respuesta · mantener posiciones salvo información genuinamente nueva.

## 7. Paisaje competitivo (para no re-investigar)

Directos: CARGO: Co-Op Delivery Simulator · PACS · Long Drive North (lección: multiplayer buggy = ~40% positivas) · Delivery & Beyond · Deliver Together · Drive Together · Backseat Drivers · Easy Delivery Co. Referencias: Lethal Company, R.E.P.O., PEAK, Pacific Drive, Overcooked/Moving Out, Barotrauma, Snowrunner. Anti-referencia: Totally Reliable Delivery Service.

## 8. Riesgos vivos

1. Interior caminable (ADR-003, gate M2). 2. Desync y tirones al cambiar de conductor (ADR-006, gate M4). 3. Voz de menor calidad que la competencia en Unity (D22). 4. Pocos precedentes de co-op 3D con física en Godot; addons pequeños/archivados → solo GodotSteam oficial, `NetworkBackend` propio. 5. Confianza ciega en código generado → R7/R13/§0.7. 6. Inflación de alcance hacia Submarino/Volcán. 7. Nicho saturado. 8. Nombre sin verificar.

## 9. Próximos pasos en orden

1. Descargar el maestro v0.2 y este briefing a `RutaFragil/`; repo Git con LFS (la copia canónica vive en Git).
2. Semana 0: si el dueño nunca ha compilado un proyecto, el tutorial oficial "Your first 3D game" de la documentación de Godot, en la máquina Windows.
3. Instalar Godot 4.7.2 stable idéntico en Mac y Windows.
4. Elegir e instalar puente MCP (Godot AI / godot-mcp / Godot MCP-CLI) — o empezar solo con archivos + CLI headless.
5. Ejecutar M0-T0.1 con el protocolo §0.4.
6. Paralelo (Cowork): checklist de marca; guardar el style board D16 limpio en `Referencias/`.

## 10. Manifiesto de archivos y ritual

| Archivo | Rol | Cómo se actualiza |
|---|---|---|
| `RUTA_FRAGIL_documento_maestro_v0.2_godot.md` | Fuente de verdad | Cambios se proponen, el humano aprueba, se versiona y se hace commit. |
| `CONTEXTO_RUTA_FRAGIL_v0.2.md` (este) | Memoria portátil | Al cierre de cada sesión relevante: D-log, §2 estado, §8 riesgos. |
| `*_v0.1*.md` | Historial (Unity) | No se edita. Sirve para entender por qué se decidió lo que se decidió. |

**Regla:** la versión de Git manda; toda copia en Claude, Cowork o proyectos de IA se reemplaza tras cada cambio. Un briefing desactualizado miente con autoridad.
