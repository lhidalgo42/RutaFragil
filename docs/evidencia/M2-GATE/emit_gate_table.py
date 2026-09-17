"""Render the complete evidence table from an immutable gate summary."""
import json
import sys
from pathlib import Path

base = Path(__file__).resolve().parent
iteration = int(sys.argv[1])
source_commit = sys.argv[2]
raw = base / "04_raw" / f"iteration_{iteration}"
data = json.loads((raw / "summary.json").read_text(encoding="utf-8"))
host, client = data["host"], data["client"]
lines = [f"# Gate — corrida {iteration}, criterios revisión 04", "",
         f"Resultado automático: **{data['status']}**; válida: **{data['valid']}**. "
         "Aprobación humana pendiente.", "",
         f"Código de simulación: `{source_commit}`. Motor 4.7.2, Jolt. Dos ventanas, "
         "VSync=0, max_fps=0. Véase el ledger para el recuento de intentos válidos; "
         "los experimentos 13 no consumen D96.", "",
         "Muestreo común: observador independiente `GateMetrics`, después de los nodos, "
         "`process_priority=1000`, `process_physics_priority=1000`. No escribe transformadas ni input.", "",
         "| Métrica | Anfitrión | Cliente |", "|---|---:|---:|"]


def fmt(value):
    if value is None:
        return "no aplica"
    if isinstance(value, bool):
        return str(value)
    if isinstance(value, (float, int)):
        return f"{value:.6f}"
    return str(value)


def row(label, a, b):
    lines.append(f"| {label} | {fmt(a)} | {fmt(b)} |")


row("**Apoyo local en bus (%) — mínimo 95 %**", host["bus_support"]["percent"], client["bus_support"]["percent"])
row("Ticks apoyados / total", f"{host['bus_support']['supported_ticks']:.0f}/{host['ticks']:.0f}",
    f"{client['bus_support']['supported_ticks']:.0f}/{client['ticks']:.0f}")
for key in ["duration_s", "ticks", "off_bus_support_ticks", "support_loss_count"]:
    row(key, host[key], client[key])
for key in ["p95_m", "p99_m", "p999_m", "max_m", "samples"]:
    row("Desplazamiento local por tick " + key, host["slip"][key], client["slip"][key])
row("p99 juzgado", data["slip_judged"], data["slip_judged"])
row("Límite p99 cliente", "—", data["slip_p99_limit_m"])
row("Cociente p99 cliente / anfitrión", "—", data["slip_p99_ratio"])
for key in ["max_depth_m", "max_run_ticks"]:
    row("Penetración de cuerpos simulados " + key, host["penetration"][key], client["penetration"][key])
for key in ["p1", "percent_below_60", "frames"]:
    row("FPS " + key, host["fps"][key], client["fps"][key])
row("Render verificado", data["render_verified"], data["render_verified"])
row("Cámaras mínimo/máximo", f"{host['cameras']['min']}/{host['cameras']['max']}",
    f"{client['cameras']['min']}/{client['cameras']['max']}")
for key in ["unauthorized_cargo_simulation_ticks", "remote_crew_simulation_ticks"]:
    row(key, host[key], client[key])
row("ERROR / WARNING", f"{data['logs']['host']['errors']}/{data['logs']['host']['warnings']}",
    f"{data['logs']['client']['errors']}/{data['logs']['client']['warnings']}")
row("Salida del hijo", data["exit_codes"]["host"], data["exit_codes"]["client"])
lines += ["", "Si alguna instancia tiene apoyo inferior al 95 %, el desplazamiento no se cita "
          "como jitter ni se juzga contra 1,5×. El máximo solo se reporta. Penetración: "
          "casco finito con hueco de puerta excluido; límites 5 cm y 3 ticks, solo cuerpos "
          "simulados localmente. Réplicas y cuerpos congelados quedan en diagnóstico.", "",
          "| Actividad confirmada | Anfitrión | Cliente |", "|---|---:|---:|"]
for key in sorted(host["activity"]):
    row(key, host["activity"][key], client["activity"][key])
lines += ["", "| Error remoto | Anfitrión | Cliente |", "|---|---:|---:|"]
for kind in ["bus", "crew", "cargo"]:
    for key in ["p95_m", "max_m", "p95_deg", "max_deg", "matched", "unmatched"]:
        row(kind + " " + key, host[kind + "_remote_error"].get(key), client[kind + "_remote_error"].get(key))
lines += ["", "Error contra la autoridad al mismo UTC local; trazas 10 Hz interpoladas, "
          "sin extrapolar ni cruzar transferencias de autoridad. No se inventan umbrales.", "",
          "| Penetración juzgada por cuerpo: profundidad / racha | Anfitrión | Cliente |", "|---|---:|---:|"]
for entity in sorted(set(host["penetration"]["entities"]) | set(client["penetration"]["entities"])):
    values = []
    for reading in [host, client]:
        record = reading["penetration"]["entities"].get(entity, {})
        values.append(f"{record.get('max_depth_m', 0):.6f} m / {record.get('max_run_ticks', 0):.0f} ticks; "
                      f"{record.get('excluded_ticks', 0):.0f} excluidos")
    row(entity, *values)
lines += ["", "Motivos automáticos:", ""]
for reason in data["invalid_reasons"] + data["failures"]:
    lines.append("- " + reason)
if not data["invalid_reasons"] and not data["failures"]:
    lines.append("Sin incumplimientos automáticos registrados; aprobación humana pendiente.")
lines += ["", "Ruta y velocidades medidas: `" + json.dumps(host.get("drive", {}), ensure_ascii=False) + "`.", "",
          f"Datos completos: [summary.json](04_raw/iteration_{iteration}/summary.json). "
          f"Logs: [anfitrión](04_raw/iteration_{iteration}/host.log), [cliente](04_raw/iteration_{iteration}/client.log). "
          "Los JSON incluyen diagnóstico de penetraciones excluidas y contadores por entidad.", ""]
(base / f"04_gate_iteration_{iteration}.md").write_text("\n".join(lines), encoding="utf-8")
