# Esquema de datos v1 — `game_config` y `tuning`

**Tarea:** M0-T0.2 · **Fuentes vinculantes:** maestro v0.2 §8.1 (valores v0), §13 (moddabilidad), §19 (arquitectura de datos), §20 (estructura y autoloads) y plan M0-T0.2 (§4: D43–D47; §6: pasos 1–5).
**Jerarquía:** maestro v0.2 > briefing v0.2 > plan M0-T0.2 > este documento. Si este documento difiere del maestro, manda el maestro.

## 1. Piezas

- **Esquema en código** (R2, D44): los Resources `GameConfigData` (`src/core/data/game_config_data.gd`) y `TuningTable` (`src/core/data/tuning_table.gd`) declaran cada campo como `@export` con **defaults neutros** (`0`, `0.0`, `{}`). Ningún valor de §8.1 vive en un `.gd`: `TuningTable.new().starting_money == 0`.
- **Valores en datos** (D44), ambos versionados en `res://data/`:
  - `game_config.tres` / `tuning.tres` — artefacto **autoritativo para el editor/Inspector** (R2, R14: texto, con `script_class`). En caliente gana la **última capa** aplicada (el JSON base va encima del `.tres`); el test de deriva impide que lleguen distintos al repo. Los `.tres` se regeneran **solo con la herramienta** (`import_data_mirror.gd`): no guardar desde el Inspector (un guardado manual añadiría `uid` y la herramienta lo quitaría).
  - `game_config.json` / `tuning.json` — espejo JSON: formato de modding y edición en caliente. Un test de deriva exige igualdad `.tres` = JSON; dos herramientas headless sincronizan en ambos sentidos (ver README, "Datos y mods").
- **Autoload** `GameConfig` (`src/autoloads/game_config.gd`, D43): expone `data: GameConfigData`, `tuning: TuningTable`, la propiedad delegada `max_players` (la expresión literal de R1, `GameConfig.max_players`), `reload(base_dir: String = "res://data", mods_dir: String = "user://mods") -> DataLoadReport` (los argumentos existen para pruebas; el juego usa los defaults) y la señal `reloaded(report)` (D46).
- **Mods** (§13): archivos planos `user://mods/*.json`, aplicados en **orden de bytes (ASCII)** — `B.json` < `a.json`; se recomienda minúsculas en los nombres de archivo de mod.

## 2. El sobre (envelope) por documento

Cada documento JSON viaja dentro de un sobre con su id de documento como única clave raíz (D45):

```json
{ "game_config": { "schema_version": 1, "max_players": 4, "max_players_hard_limit": 8 } }
```

```json
{ "tuning": { "starting_money": 500, "...": "..." } }
```

Ids de documento en v1: `game_config` y `tuning`. Un archivo de mod puede traer **varias secciones** en el mismo archivo (p. ej. `tuning` y `game_config` a la vez). Los archivos base (`res://data/<doc>.json`) son **mono-documento**: claves raíz adicionales se ignoran sin aviso. Los demás documentos de §19 (`PackageDefinition`, `BiomeDefinition`, `ContractDefinition`, `ToolDefinition`, `VehicleSystemDefinition`) reutilizarán este mecanismo cuando entren; sus ids se añadirán a este esquema en su tarea.

## 3. Documento `game_config` — Resource `GameConfigData`

| Campo | Tipo | Unidad | Valor v0 | Origen |
|---|---|---|---|---|
| `schema_version` | `int` | — | 1 | Versionado del esquema (plan M0-T0.2 §6 paso 3); **informativo en v1**, sin comprobación ni migración (BACKLOG) |
| `max_players` | `int` | jugadores | 4 | R1 / D11 ("default 4"); nunca hardcodeado en código |
| `max_players_hard_limit` | `int` | jugadores | 8 | D11 ("probado a 8") |

## 4. Documento `tuning` — Resource `TuningTable`

Campos agrupados con `@export_group` (nombres D47: ingleses, snake_case, unidad explícita). Tipos: `int` para cantidades enteras (dinero, litros, puntos, conteos); `float` para segundos, metros, m/s, multiplicadores y fracciones; los rangos "min–max" de §8.1 son dos campos `_min`/`_max`.

### 4.1 Economía

| Campo | Tipo | Unidad | Valor v0 | Origen (§8.1) |
|---|---|---|---|---|
| `starting_money` | `int` | dinero | 500 | "Dinero inicial" |
| `base_pay` | `Dictionary[String, int]` | dinero por paquete | `{normal: 60, fragile: 120, floating: 100, aquatic: 140}` | "Pago base: Normal / Frágil / Flotante / Acuático" |
| `rent_quota` | `int` | dinero | 900 | "Cuota de arriendo" |
| `rent_every_contracts` | `int` | contratos | 3 | "Cuota de arriendo" (cada 3 contratos) |
| `rent_increase_per_cycle` | `float` | fracción por ciclo | 0.15 | "Cuota de arriendo" (+15% por ciclo) |
| `defeat_keep_fraction` | `float` | fracción | 0.25 | Fuera de la tabla §8.1: D8/D12 ("derrota conserva 25%") |

### 4.2 Combustible

| Campo | Tipo | Unidad | Valor v0 | Origen (§8.1) |
|---|---|---|---|---|
| `fuel_tank_liters` | `int` | L | 40 | "Tanque … 40 L" |
| `fuel_consumption_l_per_km` | `float` | L/km | 4.0 | "consumo … 4 L·km" (tasa, no cantidad entera) |
| `fuel_slope_multiplier` | `float` | multiplicador | 1.5 | "×1.5 pendiente" |
| `fuel_mud_multiplier` | `float` | multiplicador | 2.0 | "×2 lodo" |
| `fuel_price_per_liter` | `int` | dinero/L | 3 | "3 por L en estación" (gratis en zonas) |
| `jerrycan_liters` | `int` | L | 10 | "Bidón 10 L" |
| `jerrycan_pour_seconds` | `float` | s | 8.0 | "vertido 8 s" |
| `jerrycan_fill_seconds` | `float` | s | 20.0 | "llenado en surtidor 20 s" |
| `jerrycan_fill_seconds_two_players` | `float` | s | 10.0 | "(10 s con dos)" |
| `fuel_zones_per_route_min` | `int` | zonas | 1 | "Zonas de combustible 1–2 por ruta en ramas" |
| `fuel_zones_per_route_max` | `int` | zonas | 2 | "Zonas de combustible 1–2 por ruta en ramas" |
| `barrel_liters_min` | `int` | L | 10 | "barriles 10–30 L aleatorios" |
| `barrel_liters_max` | `int` | L | 30 | "barriles 10–30 L aleatorios" |
| `empty_jerrycans_per_route_min` | `int` | bidones | 1 | "1–3 bidones vacíos por ruta en puntos fijos" |
| `empty_jerrycans_per_route_max` | `int` | bidones | 3 | "1–3 bidones vacíos por ruta en puntos fijos" |

**Sin campo en v1** (reglas cualitativas de §8.1, sin parámetro):

- El "derrame en marcha ∝ velocidad" (fila Bidón) **no tiene número** en el maestro: por D47 no se inventa un campo; queda registrado en `BACKLOG.md` para T1.2.
- "Surtidor ilimitado / gratis en zonas": repostar en una zona de combustible no cuesta dinero ni tiene límite en v1; `fuel_price_per_liter` aplica solo a las estaciones pagadas. Regla cualitativa sin parámetro, registrada en `BACKLOG.md`.

### 4.3 Servicios

| Campo | Tipo | Unidad | Valor v0 | Origen (§8.1) |
|---|---|---|---|---|
| `repair_cost_per_integrity_point` | `int` | dinero/punto de Integridad | 3 | "Reparación … 3 por punto de Integridad" |
| `maintenance_cost` | `int` | dinero | 150 | "mantención … 150 fijo" |
| `shop_prices` | `Dictionary[String, int]` | dinero | `{medkit: 120, armor: 250, cushion: 30, float: 80, jerrycan: 40, kit: 100}` | "Botiquín / Blindaje / Cojín / Flotador (×4) / Bidón / Kit" |

Claves de `shop_prices`: `medkit`, `armor`, `cushion`, `float` (precio por unidad; §8.1 indica ×4 por bus), `jerrycan`, `kit`.

**Regla cualitativa sin parámetro v1:** "Flotador ×4" (§8.1): el conteo de cuatro flotadores por bus no es un campo; `shop_prices.float` es el precio **por unidad**. Registrada en `BACKLOG.md`.

### 4.4 Contrato (Ciudad, B0)

| Campo | Tipo | Unidad | Valor v0 | Origen (§8.1) |
|---|---|---|---|---|
| `contract_packages_min` | `int` | paquetes | 3 | "Contrato Ciudad 3–5 paquetes" |
| `contract_packages_max` | `int` | paquetes | 5 | "Contrato Ciudad 3–5 paquetes" |
| `contract_destinations_min` | `int` | destinos | 1 | "1–3 destinos" |
| `contract_destinations_max` | `int` | destinos | 3 | "1–3 destinos" |
| `route_km_min` | `int` | km | 6 | "ruta 6–10 km (24–60 L: el tanque no alcanza a propósito)" |
| `route_km_max` | `int` | km | 10 | "ruta 6–10 km" |
| `target_minutes_min` | `int` | min | 15 | "objetivo 15–25 min" |
| `target_minutes_max` | `int` | min | 25 | "objetivo 15–25 min" |

### 4.5 Jugador

| Campo | Tipo | Unidad | Valor v0 | Origen (§8.1) |
|---|---|---|---|---|
| `player_walk_speed_mps` | `float` | m/s | 4.0 | "caminar 4 m/s" |
| `player_sprint_speed_mps` | `float` | m/s | 6.0 | "sprint 6 m/s" |
| `player_jump_height_m` | `float` | m | 1.0 | "salto 1 m" |
| `interaction_reach_m` | `float` | m | 2.5 | "alcance de interacción 2.5 m" |
| `player_mouse_sensitivity` | `float` | rad/px | 0.0025 | mirada con ratón (§9.2), añadido en M2-T2.2 r3 — preferencia del jugador, candidata a menú de ajustes |

### 4.5b Carga (M2-T2.3)

| Campo | Tipo | Unidad | Valor v0 | Origen |
|---|---|---|---|---|
| `package_mass_kg` | `float` | kg | 8.0 | ejemplo de §19 |
| `package_throw_speed_mps` | `float` | m/s | 6.0 | lanzamiento, §9.2/D87 |
| `package_hold_distance_m` | `float` | m | 0.7 | por delante de los ojos, D82/D87 |
| `strap_hold_seconds` | `float` | s | 1.5 | mantener E para amarrar, D86/D87 |
| `package_relative_damping_ns_per_m` | `float` | N·s/m | 160.0 | amortiguador vertical relativo al bus, ADR-003 — medido en el paso 1 (03): 80 deja escapes, 160 no |

### 4.6 Bus

| Campo | Tipo | Unidad | Valor v0 | Origen (§8.1) |
|---|---|---|---|---|
| `bus_mass_kg` | `int` | kg | 3000 | "masa 3000 kg" |
| `bus_integrity_max` | `int` | puntos | 100 | "Integridad 100" |
| `bus_integrity_max_loss_per_contract` | `int` | puntos/contrato | 5 | "Desgaste −5 al máximo por contrato" |
| `bus_max_speed_kmh` | `float` | km/h | 90.0 | §4.5 del maestro |
| `bus_traction_force_n` | `float` | N | 10000.0 | §4.5 del maestro (renombrado en M2-T2.1, r1.1 de T1.1: es la fuerza de tracción total, no un tiempo; el 0–60 real medido es 6,93 s) |
| `bus_wheelbase_m` | `float` | m | 5.5 | §4.5 / ADR-007 (M1-T1.1, valor de partida a ajustar midiendo) |
| `bus_track_width_m` | `float` | m | 2.2 | ADR-007 (M1-T1.1) |
| `bus_wheel_radius_m` | `float` | m | 0.5 | ADR-007 (M1-T1.1) |
| `bus_suspension_rest_m` | `float` | m | 0.6 | ADR-007 (M1-T1.1) |
| `bus_suspension_stiffness_n_per_m` | `float` | N/m | 60000.0 | ADR-007 (M1-T1.1) |
| `bus_suspension_damping_ns_per_m` | `float` | N·s/m | 6000.0 | ADR-007 (M1-T1.1) |
| `bus_grip_lateral` | `float` | 1/s | 10.0 | §4.5 "arcade con peso" (M1-T1.1) |
| `bus_grip_lateral_handbrake` | `float` | 1/s | 1.5 | §4.5 "freno de mano derrapante" (M1-T1.1) |
| `bus_brake_force_n` | `float` | N | 40000.0 | §4.5 (M1-T1.1) |
| `bus_steer_max_deg` | `float` | grados | 30.0 | §4.5 (M1-T1.1) |
| `bus_steer_speed_falloff` | `float` | fracción | 0.6 | §4.5 (M1-T1.1) |
| `bus_center_of_mass_y_m` | `float` | m | -0.6 | ADR-007 (M1-T1.1; negativo = bajo el origen) |

`bus_integrity_max_loss_per_contract` es una **magnitud positiva que se resta** de `bus_integrity_max` por cada contrato (§8.1: "−5 al máximo por contrato"): con el valor v0, la integridad máxima pasa de 100 a 95 tras el primer contrato.

## 5. Orden de capas y reglas de fusión (D45)

**Orden de carga** (cada capa se fusiona sobre el resultado de la anterior):

1. `res://data/<doc>.tres` (valores base autoritativos **para el editor/Inspector**; en caliente gana la última capa; el test de deriva mantiene `.tres` y espejo iguales).
2. `res://data/<doc>.json` (espejo; edición en caliente de desarrollo).
3. `user://mods/*.json` en **orden de bytes (ASCII)** (`aa.json` antes que `zz.json`, pero `B.json` antes que `a.json`: las mayúsculas van primero; el último en aplicar gana). Recomendación: minúsculas en los nombres de archivo de mod.

**Fusión profunda** (propia; `Dictionary.merge()` nativo es superficial y no se usa):

- Diccionarios anidados se fusionan **clave a clave**, recursivamente: un mod que trae `{"base_pay": {"fragile": 150}}` cambia solo `fragile` y conserva `normal`, `floating` y `aquatic`.
- Los **arrays se reemplazan** enteros, nunca se concatenan ni se fusionan por índice. *(Propiedad de `JsonMerge` pensada para documentos futuros: en v1 ningún campo admite arrays.)*
- Un escalar sobre un diccionario (o viceversa) reemplaza. *(Igualmente pensada para documentos futuros: en v1 un tipo distinto rechaza el archivo — la validación llega antes que la fusión.)*
- La fusión no muta las entradas (opera sobre copia profunda del base).

**Validación por clave contra el esquema** (antes de `set()`, que coaccionaría en silencio):

- `int` acepta solo `float` integral (todo número JSON se parsea como `float`; `500.0` sí, `8.5` no).
- `String` y `bool` son estrictos (`"12"` no entra en un `int`; `1.0`/`"true"` no entran en un `bool`).
- Diccionarios tipados (`base_pay`, `shop_prices`) se validan valor a valor y se aplican con `.assign()`.

**Rechazo, claves desconocidas y política de errores:**

- Un archivo de mod con **cualquier** error (JSON malformado, tipo inválido, raíz no-objeto, clave de sección no-string, sección que no es objeto) se **rechaza entero** y queda listado en el reporte de carga: **un archivo con errores no aplica nada; un archivo sin errores aplica todas sus secciones conocidas (aunque sean cero)**.
- Un mod `{}` bien formado **no es rechazo**: aviso "no sections; nothing to apply" y el archivo entra igual en `applied_files` (aplica cero secciones).
- Un mod con **solo secciones desconocidas** tampoco es rechazo: un aviso "unknown section … ignored" por cada una y el archivo entra en `applied_files` sin tocar ningún valor.
- Clave desconocida dentro de una sección conocida: **aviso** en mods, **error** en la base.
- `.tres` de **clase equivocada** (el recurso no es de la clase del documento): **error** `tres:<ruta>` y la capa se omite.
- Base JSON `{}` o **sin la sección `<doc>`**: **error** "missing object section" (`base:<ruta>`) y la capa se omite.
- Base JSON inválido: la capa se omite, `is_ok()` pasa a falso y el juego sigue con los valores del `.tres`.
- Un documento **sin ninguna capa aplicada** (ni `.tres` ni JSON base) es **error**, no aviso: es un fallo de integridad de los datos, no un problema de mod.
- La API del reporte es `is_ok()`. El `push_error` **del reporte** vive en el autoload (`_ready`/`reload()`) y se emite si `!is_ok()`; los demás `push_error` del código son de rutas de bug (p. ej. id de documento desconocido en el loader), no del reporte. El autoload además emite un `push_warning` por cada aviso del reporte, así los modders ven sus rechazos.
- `print_game_data` (`src/tooling/print_game_data.gd`) termina con código de salida 1 si `!is_ok()`.

## 6. Ejemplo de mod

`user://mods/zz_mi_mod.json`:

```json
{
  "tuning": {
    "starting_money": 999,
    "base_pay": { "fragile": 150 }
  },
  "game_config": {
    "max_players": 6
  }
}
```

Efecto: `starting_money` pasa a 999; `base_pay.fragile` pasa a 150 conservando el resto de claves; `max_players` pasa a 6. Al borrar el archivo y recargar, todo vuelve a los valores base. Un segundo mod `aa_otro.json` se aplicaría **antes** (orden de bytes ASCII), así que `zz_mi_mod.json` ganaría en las claves que ambos toquen.

## 7. Recarga, edición en caliente y límites

- **Recarga explícita** (D46): `GameConfig.reload(base_dir: String = "res://data", mods_dir: String = "user://mods") -> DataLoadReport` + señal `reloaded(report)`; los argumentos existen para pruebas (el juego usa los defaults); no hay vigilante automático de `mtime` en v1 (BACKLOG).
- Los JSON se leen con `FileAccess` (nunca con `load()`), que es lo que hace verdadero "cambiar un JSON sin reabrir el editor"; los `.tres` se releen con `ResourceLoader.CACHE_MODE_IGNORE`.
- **`res://` es de solo lectura en los exports**: la edición en caliente del JSON base es una función de **desarrollo**; la vía publicada para modders es `user://mods/*.json`.
- Mods empaquetados `.pck` (`ProjectSettings.load_resource_pack`, §13): fuera de v1, planeados para M4 (BACKLOG).
