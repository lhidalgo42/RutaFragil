"""Render recorded gate JSON without recomputing or changing its verdict."""
import json
import sys
from pathlib import Path


def report(folder: Path) -> None:
    data = json.loads((folder / "summary.json").read_text(encoding="utf-8"))
    number = data["iteration"]
    roles = [data["host"], data["client"]]
    lines = [f"# Gate — corrida {number}", "",
             f"Resultado registrado: **{data['status']}**, válida: **{data['valid']}**. "
             "Aprobación humana: pendiente.", "",
             "Muestreo idéntico: observador independiente `GateMetrics`, "
             "`_physics_process`, `process_physics_priority=1000`, "
             "`process_priority=1000`, después de todos los escritores y del movimiento. "
             "El observador no escribe transformadas ni manda input.", "",
             "El deslizamiento es el desplazamiento local total por tick: incluye caminar "
             "y, si ocurre, quedar fuera del bus. No se descartan esas muestras.", "",
             "| Métrica | Anfitrión | Cliente |", "|---|---:|---:|"]

    def row(label: str, values: list) -> None:
        def fmt(value):
            if value is None:
                return "no aplica"
            return f"{value:.6f}" if isinstance(value, float) else str(value)
        lines.append(f"| {label} | {fmt(values[0])} | {fmt(values[1])} |")

    for key in ["duration_s", "ticks"]:
        row(key, [r[key] for r in roles])
    for key in ["p95_m", "p99_m", "p999_m", "max_m", "samples"]:
        row("slip " + key, [r["slip"][key] for r in roles])
    row("p99 cliente permitido (1,5 × anfitrión)", ["—", data["slip_p99_limit_m"]])
    row("Cociente p99 cliente/anfitrión", ["—", data["slip_p99_ratio"]])
    row("Ticks sin apoyo en el bus", [r["off_bus_support_ticks"] for r in roles])
    for key in ["max_depth_m", "max_run_ticks"]:
        row("Penetración " + key, [r["penetration"][key] for r in roles])
    for key in ["p1", "percent_below_60", "frames"]:
        row("FPS " + key, [r["fps"][key] for r in roles])
    row("Render VSync / max_fps / viewport", [str(r.get("render_configuration", "VSync proyecto, max_fps=120")) for r in roles])
    row("Cámaras activas mínimo/máximo", [f"{r['cameras']['min']:g}/{r['cameras']['max']:g}" for r in roles])
    for key in ["unauthorized_cargo_simulation_ticks", "remote_crew_simulation_ticks"]:
        row(key, [r[key] for r in roles])
    row("ERROR / WARNING", [f"{data['logs'][r]['errors']}/{data['logs'][r]['warnings']}" for r in ["host", "client"]])
    row("Código de salida del proceso", [data["exit_codes"][r] for r in ["host", "client"]])
    lines += ["", "El máximo de deslizamiento se informa; no decide el resultado. "
              "Penetración: cajas finitas del casco, hueco de la puerta excluido; "
              "límites 0,05 m y 3 ticks. Se excluyen únicamente cuerpos con colisión "
              "desactivada por estado (tripulante sentada o carga HELD).", "",
              "| Actividad confirmada | Anfitrión | Cliente |", "|---|---:|---:|"]
    for key in roles[0]["activity"]:
        row(key, [r["activity"][key] for r in roles])
    lines += ["", "| Error remoto | Anfitrión | Cliente |", "|---|---:|---:|"]
    for entity in ["bus", "crew", "cargo"]:
        for key in ["p95_m", "max_m", "p95_deg", "max_deg", "matched", "unmatched"]:
            row(entity + " " + key, [r[entity + "_remote_error"].get(key, "no aplica: autoridad local") for r in roles])
    lines += ["", "Errores contra la autoridad al mismo instante UTC, sin corregir "
              "la latencia por desplazamiento del reloj. Interpolación entre muestras "
              "de traza a 10 Hz; sin extrapolar ni cruzar cambios de autoridad.", "",
              "| Cuerpo: penetración máxima / racha máxima | Anfitrión | Cliente |", "|---|---:|---:|"]
    for entity in sorted(set(roles[0]["penetration"]["entities"]) | set(roles[1]["penetration"]["entities"])):
        row(entity, [f"{r['penetration']['entities'][entity]['max_depth_m']:.6f} m / {r['penetration']['entities'][entity]['max_run_ticks']:g} ticks" for r in roles])
    lines += ["", "Motivos registrados:", ""]
    lines += ["- " + s for s in data["invalid_reasons"] + data["failures"]]
    drive = roles[0]["drive"]
    lines += ["", "Ruta: recta por x=30, con retorno exterior sin teletransportar. "
              f"Vueltas: {drive['laps']:g}. Velocidades de entrada (km/h): "
              + ", ".join(f"{v:.3f}" for v in drive["entry_speeds_kmh"]) + ". "
              f"Velocidad media/mínima/máxima del tramo medido: {drive['bumps_mean_kmh']:.3f} / "
              f"{drive['bumps_min_kmh']:.3f} / {drive['bumps_max_kmh']:.3f} km/h. "
              "El contador histórico de velocidades cubre z=[2,46], "
              "no los últimos metros de la última rampa.", "",
              "Margen de interpolación del bus: " + str(roles[1].get("bus_interpolation_delay_s", "receptor reiniciado por llegada, un intervalo nominal")) + ".", "",
              f"Datos íntegros: [{folder.name}/summary.json](04_raw/{folder.name}/summary.json); "
              f"[log anfitrión](04_raw/{folder.name}/host.log), "
              f"[log cliente](04_raw/{folder.name}/client.log). "
              "Los JSON por instancia incluyen contadores de integración por cuerpo."]
    (folder.parent.parent / f"04_gate_iteration_{number}.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    report(Path(sys.argv[1]))
