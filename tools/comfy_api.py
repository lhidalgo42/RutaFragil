"""Cliente HTTP mínimo del ComfyUI del dueño, compartido por los scripts de arte.

El servidor está detrás de Cloudflare Access. Las credenciales se leen del
entorno y NUNCA se escriben en el repositorio:

    COMFY_URL        por defecto https://comfy.areum.cl
    CF_ACCESS_ID     CF-Access-Client-Id
    CF_ACCESS_SECRET CF-Access-Client-Secret

Sin las dos variables, Cloudflare responde el login HTML y la llamada falla con
un mensaje claro en vez de un JSONDecodeError a treinta líneas de distancia.
"""
import json, os, time, urllib.parse, urllib.request

SERVER = os.environ.get("COMFY_URL", "https://comfy.areum.cl").rstrip("/")


def _headers() -> dict:
    cid = os.environ.get("CF_ACCESS_ID", "")
    secret = os.environ.get("CF_ACCESS_SECRET", "")
    if not cid or not secret:
        raise SystemExit(
            "Faltan CF_ACCESS_ID / CF_ACCESS_SECRET en el entorno.\n"
            "  PowerShell: $env:CF_ACCESS_ID='...'; $env:CF_ACCESS_SECRET='...'\n"
            "  bash:       export CF_ACCESS_ID=...  CF_ACCESS_SECRET=...")
    return {"CF-Access-Client-Id": cid, "CF-Access-Client-Secret": secret}


def _open(req: urllib.request.Request, timeout: int):
    for k, v in _headers().items():
        req.add_header(k, v)
    return urllib.request.urlopen(req, timeout=timeout)


def get_json(path: str, timeout: int = 60) -> dict:
    with _open(urllib.request.Request(SERVER + path), timeout) as r:
        return json.load(r)


def get_bytes(path: str, timeout: int = 120) -> bytes:
    with _open(urllib.request.Request(SERVER + path), timeout) as r:
        return r.read()


def post_json(path: str, payload: dict, timeout: int = 60) -> dict:
    req = urllib.request.Request(SERVER + path, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with _open(req, timeout) as r:
        return json.load(r)


def upload_image(local_path: str, timeout: int = 120) -> str:
    """Sube una imagen a la carpeta input/ del servidor y devuelve su nombre."""
    name = os.path.basename(local_path)
    with open(local_path, "rb") as f:
        blob = f.read()
    boundary = "----rutafragil%d" % time.time()
    body = b"".join([
        ("--%s\r\nContent-Disposition: form-data; name=\"image\"; filename=\"%s\"\r\n"
         "Content-Type: image/png\r\n\r\n" % (boundary, name)).encode(),
        blob,
        ("\r\n--%s\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n"
         "--%s--\r\n" % (boundary, boundary)).encode(),
    ])
    req = urllib.request.Request(SERVER + "/upload/image", data=body,
                                 headers={"Content-Type": "multipart/form-data; boundary=" + boundary})
    with _open(req, timeout) as r:
        return json.load(r)["name"]


def run(workflow: dict, budget_s: int = 1800) -> dict:
    """Encola un workflow y devuelve sus outputs. Aborta con mensaje si falla."""
    pid = post_json("/prompt", {"prompt": workflow})["prompt_id"]
    print("encolado %s" % pid)
    deadline = time.time() + budget_s
    last = 0.0
    while time.time() < deadline:
        hist = get_json("/history/" + pid)
        if pid in hist:
            entry = hist[pid]
            status = entry.get("status", {})
            if status.get("status_str") == "error" or not status.get("completed", True):
                raise SystemExit("ERROR del servidor: " + json.dumps(status)[:2000])
            return entry.get("outputs", {})
        if time.time() - last > 30:
            last = time.time()
            print("  ... esperando (%d s)" % int(time.time() - (deadline - budget_s)))
        time.sleep(2)
    raise SystemExit("ERROR: sin resultado en %d s" % budget_s)


def view_url(item: dict) -> str:
    return "/view?filename=%s&subfolder=%s&type=%s" % (
        urllib.parse.quote(item["filename"]),
        urllib.parse.quote(item.get("subfolder", "")), item.get("type", "output"))
