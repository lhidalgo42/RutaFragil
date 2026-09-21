# M-ART — Pipeline de arte: del style board al primer asset en el juego · Plan v1.0

**Fecha:** 2026-09-17 · **Rama propuesta:** `art/m-art-style-board` desde `main` (`bfa2e0d`) · **Pliego:** maestro §10, §10.1 (D27), §10.2, §0.7 · Corre **en paralelo a M3**, que es lo que el maestro fija («Pipeline de arte: paralelo desde M3; gate en M8»).

## 1. Lo que encontré, y es incómodo

**El style board no existe.** El maestro §10 nombra `Referencias/bus_interior_canonico_v1.png` y `bus_exterior_canonico_v1.png` como la fuente de verdad del arte, y el punto 6 del checklist exige comparar **cada** asset contra él antes de aprobarlo. `docs/referencias/` está vacío salvo un `.gitkeep`, y `Referencias/` en la raíz no existe. Es decir: hoy el criterio de coherencia visual no tiene referente, y sin él cada asset deriva por su cuenta y la deriva solo se ve cuando ya hay veinte.

**El único generador 3D instalado es el que el maestro prohíbe.** Inventario del servidor (`192.168.50.200:8188`, revisado hoy):

| | Modelo | Licencia | Veredicto |
|---|---|---|---|
| Imagen | **`flux1-schnell`** | **Apache 2.0** | ✅ aprobado, ya instalado |
| 3D | `hunyuan_3d_v2.1` + nodos `Hy3D21*` | Territorio excluye UE, Reino Unido y Corea | ❌ **prohibido para publicar** (§10.2); solo exploración interna |
| 3D | **Trellis (MIT)**, el por defecto del maestro | MIT | ⚠️ **no está instalado** |
| Imagen | `flux2_dev` | no comercial | ❌ prohibido |
| Varios | Illustrious-XL, Qwen, Z-Image, Krea, Wan, MiniMax, Stable Audio 3, `triposplat` | sin verificar | ⏸ no usar hasta registrar licencia |

Registrado en `CREDITS.md` **antes** de generar nada, que es lo que exige §10.2.

**Consecuencia práctica:** la mitad de imagen del pipeline está lista y limpia hoy; la mitad de 3D no. Se puede avanzar mucho sin desbloquear 3D —style board, referencias de bioma, texturas— pero ninguna malla generada podrá publicarse hasta que haya un 3D con licencia limpia.

## 2. Alcance

**Dentro:** style board canónico (D16); el pipeline completo `ComfyUI → Blender → glTF → Godot` demostrado **con un solo asset**; el checklist de §10.1 convertido en algo comprobable; `CREDITS.md` al día.

**Fuera:** producir el set de assets del juego (eso viene después, y solo cuando el pipeline esté probado); tocar física, colisión de gameplay o tuning; los biomas Cerro y Pantano como escenas; audio.

**Regla que no se negocia (§10.1 punto 3):** la física del juego **nunca** usa el mesh generado como colisión. La colisión se autora aparte, con primitivas o convex hull simple. Es exactamente lo que hace compatibles «validar físicas sobre greybox» y «usar assets de IA», y es lo que ha permitido que M2 se validara sin arte.

## 3. Decisiones

| # | Decisión | Por qué |
|---|---|---|
| **DA1** | **El style board se genera primero y lo aprueba el dueño**, antes que cualquier asset. Cinco láminas: bus exterior, bus interior, Ciudad, Cerro, Pantano. Viven en `docs/referencias/` y el maestro §10 se corrige para apuntar ahí (hoy cita `Referencias/`, que no existe). | El checklist exige comparar contra él. Sin board, «coherente con D16» no es verificable y la aprobación se vuelve gusto del momento. |
| **DA2** | **Solo `flux1-schnell` produce lo que entra al repositorio**, hasta que otra licencia esté registrada. | §10.2. Es el único instalado que es a la vez capaz y limpio. |
| **DA3** | **Hunyuan3D queda para exploración interna y su salida no entra al repo.** Si se usa, el archivo se queda fuera de `assets/` y se dice en el reporte. | El maestro lo permite explícitamente como exploración y lo prohíbe para publicar. Mezclarlo sin marcar es lo que produce un asset imposible de rastrear el día del lanzamiento. |
| **DA4 — RESUELTA (D101, 2026-09-21)** | ~~Instalar Trellis en el servidor, o elegir otro 3D con licencia verificada.~~ **TRELLIS.2 llegó nativo con ComfyUI 0.37.0**; pesos MIT instalados, ruta nativa sin `nvdiffrast`. El 3D del pipeline ya se puede demostrar con un asset publicable. Herramienta: `tools/comfy_mesh.py`. | Sin esto, la parte 3D del pipeline no se podía demostrar con un asset publicable. |
| **DA5** | **El primer asset del pipeline es el paquete** (0.4 m, ≤800 tris): es el prop más visible del juego, el más simple y el que ya tiene colisión autorada y medidas fijadas por D81. | Probar el pipeline con el bus (≤25k tris, interior caminable con nueve piezas de colisión) mezcla dos riesgos. Un asset pequeño prueba el camino entero y no arriesga nada. |
| **DA6** | **El checklist de §10.1 se vuelve un script**: escala, pivote, ejes, conteo de triángulos, caras sueltas, normales invertidas, número de materiales y tamaño de textura se comprueban solos sobre el glTF. Los puntos 6 y 7 (coherencia con el board, registro de licencia) los valida el humano. | Siete puntos a ojo, asset por asset, no se sostiene. Lo mecánico se automatiza; lo de criterio se queda con quien tiene criterio. |

## 4. Pasos

**Paso 1 — Licencias y esqueleto.** `CREDITS.md` con el inventario del servidor (hecho). Crear `assets/models/`, `assets/textures/`, `docs/referencias/`. Corregir la ruta del style board en el maestro §10.

**Paso 2 — Style board (DA1).** Cinco láminas con `flux1-schnell` vía API, prompts guardados junto a cada imagen. El bus sigue D16: largo, librea amarillo/rojo, techo crema, ventanas corridas, low-poly estilizado, legibilidad sobre detalle. **Para el dueño (§0.7):** mirar las cinco y decir cuáles valen. Es dirección de arte; no hay medición que lo sustituya.

**Paso 3 — Validador del checklist (DA6).** Script que toma un `.glb` y responde sí/no a los puntos 1–5, con el número concreto que falla. Rojo primero: un glTF deliberadamente malo (escala ×100, pivote centrado, 5k tris) tiene que suspender en los cinco.

**Paso 4 — Un asset de punta a punta (DA5).** El paquete, desde la generación hasta verlo en el Playground, con colisión autorada, pasando el validador y registrado en `CREDITS.md`. Si DA4 no está resuelta, el paso 4 se hace con el mesh de exploración **fuera del repo** para probar el camino, y se repite con el 3D limpio cuando lo haya.

**Paso 5 — Evidencia.** Comparación lado a lado con el board, conteo de triángulos, captura en el juego, y el arnés en verde (el arte no debe tocar nada de lo que M2 validó: 255 tests siguen pasando).

## 5. Riesgos

- **El más probable:** que se genere mucho asset bonito antes de que el pipeline esté probado, y haya que rehacerlo entero por escala, pivote o licencia. Por eso el paso 4 es **un** asset.
- **El más caro:** descubrir en M8 que un modelo tenía licencia territorial y hay que regenerar todo. Lo evita la regla de registrar antes de generar, que ya está aplicada.
- **El más silencioso:** que el mesh generado acabe usándose como colisión «porque se ve bien». Rompería en un día todo lo que M2 midió durante dos semanas.
