# 01 — Fuentes FLUX para la van

Fecha: 2026-09-24. Modelo: FLUX.1 [schnell], Apache 2.0, servidor `https://comfy.areum.cl`. Todas se generaron a 1024 × 1024, 4 pasos, con el sufijo de prompt «orthographic flat texture swatch, uniform even lighting, no perspective, no objects, no text, no letters, no numbers, no logos, no brand names, no trademark». Cada PNG tiene su JSON de procedencia al lado en `docs/referencias/`.

| Fuente | Seed | Veredicto de revisión | Uso previsto |
|---|---:|---|---|
| `van_tex_src_yellow_v1` | 101 | Apta. Trae cuatro tornillos en las esquinas: se usa solo el centro. | Carrocería exterior |
| `van_tex_src_red_v1` | 102 | Usable solo la franja roja superior. La mitad inferior gris y la línea blanca no entran. | Franja roja |
| `van_tex_src_cream_v1` | 103 | Apta. Ondulado horizontal suave, sin texto. | Techo crema |
| `van_tex_src_floor_v1` | 104 | Apta. Rombos antideslizantes regulares; borde oscuro de ~16 px que el paso seamless debe absorber. | Piso interior |
| `van_tex_src_rack_v1` | 105 | Apta. Metal azul claro con rayado fino. | Racks y gabinetes |
| `van_tex_src_seat_v1` | 106 | Apta. Vinilo granulado oscuro, sin costuras ni texto. | Asientos |
| `van_tex_src_tire_v1` | 107 | **Rechazada.** Neumático en perspectiva con lettering fantasma en el flanco. Contradice §10.1 punto 5 y la regla sin marcas. | — |
| `van_tex_src_tire_v2` | 207 | Apta. Parche plano de goma, dibujo angular inventado, sin flanco ni texto. | Banda de rodadura |
| `van_tex_src_rim_v1` | 108 | Apta. Metal oscuro cepillado radial. | Llanta |

La v1 del neumático se conserva como antecedente del rechazo, igual que las variantes descartadas del style board. Ninguna fuente entra al build directamente: pasan por el paso seamless donde toque, se componen en uno de los tres atlases y vuelven al gate humano.

**Límite declarado:** esta revisión es visual y la hice yo. Detectar texto o marca fantasma no se puede automatizar; el dueño la confirma en el gate.
