"""Talk to the AI-APPS shared Dart service; no new API key or QuizAI changes."""

import json
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import ProxyHandler, Request, build_opener

SESSION = Path(__file__).resolve().parents[1] / ".ai-apps" / "dart-service.json"
SCHEMA = {
    "type": "object",
    "properties": {"speech": {"type": "string"}},
    "required": ["speech"],
    "additionalProperties": False,
}


def _connection():
    if not SESSION.is_file():
        raise RuntimeError(
            "No está activo el servicio de IA compartido de AI-APPS. "
            "Inicia QuizAI con su servicio Dart y vuelve a probar."
        )
    try:
        settings = json.loads(SESSION.read_text(encoding="utf-8"))
        endpoint = settings["endpoint"]
        token = settings["token"]
        parsed = urlsplit(endpoint)
        if (parsed.scheme != "http" or parsed.hostname != "127.0.0.1"
                or parsed.username or parsed.password or parsed.path not in ("", "/")
                or parsed.query or parsed.fragment or not 1 <= parsed.port <= 65535
                or not isinstance(token, str) or len(token) < 20):
            raise ValueError("invalid endpoint or token")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise RuntimeError("La sesión local de IA de AI-APPS no es válida.") from exc
    return endpoint.rstrip("/"), token, build_opener(ProxyHandler({}))


def _request(path, *, data=None, timeout=80):
    endpoint, token, opener = _connection()
    headers = {"Authorization": "Bearer " + token}
    if data is not None:
        headers["Content-Type"] = "application/json"
    request = Request(endpoint + path, data=data, headers=headers,
                      method="POST" if data is not None else "GET")
    try:
        with opener.open(request, timeout=timeout) as response:
            return json.loads(response.read(128_000).decode("utf-8"))
    except HTTPError as exc:
        try:
            error = json.loads(exc.read(4_096).decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            error = {}
        # The shared service returns sanitized diagnostics; never expose its token.
        details = error.get("diagnostic") if isinstance(error, dict) else None
        if isinstance(details, dict):
            summary = " / ".join(str(details[k])[:180] for k in
                                 ("providerStatus", "code", "type", "param", "message")
                                 if details.get(k) is not None)
        else:
            summary = ""
        status = error.get("error", "sin detalle") if isinstance(error, dict) else "sin detalle"
        raise RuntimeError(
            f"Servicio de IA: HTTP {exc.code} ({str(status)[:70]}). {summary}"
        ) from None
    except (URLError, OSError, ValueError) as exc:
        raise RuntimeError(
            "No se puede contactar con el servicio Dart de AI-APPS en esta sesión."
        ) from exc


def ensure_running():
    health = _request("/health", timeout=3)
    if (health.get("service") != "ai-apps-dart"
            or health.get("protocol") != 1):
        raise RuntimeError("El servicio local de IA no corresponde a AI-APPS.")
    return health


def generate(model, prompt):
    if len(prompt) > 31_000:
        raise RuntimeError("La conversación supera la longitud aceptada por el servicio.")
    request = {
        "application": "agentlab",
        "model": model,
        "input": prompt,
        "schemaName": "creativeSpeech",
        "schema": SCHEMA,
    }
    response = _request("/v1/generate", data=json.dumps(request, ensure_ascii=False).encode("utf-8"))
    if not isinstance(response, dict) or not isinstance(response.get("text"), str):
        raise RuntimeError("El servicio compartido no devolvió una respuesta válida.")
    try:
        message = json.loads(response["text"])
    except ValueError as exc:
        raise RuntimeError("El agente no devolvió una respuesta creativa válida.") from exc
    text = message.get("speech") if isinstance(message, dict) else None
    if not isinstance(text, str) or not text.strip():
        raise RuntimeError("El agente devolvió una respuesta vacía.")
    return text.strip(), response.get("usage") or {}


ACTION_SCHEMA = {
    "type": "object",
    "properties": {
        "speech": {"type": "string"},
        "tool": {"type": "string", "enum": [
            "none", "room_list", "room_read", "room_write", "room_analyze",
            "room_launch", "room_observe",
        ]},
        "path": {"type": "string"},
        "content": {"type": "string"},
    },
    "required": ["speech", "tool", "path", "content"],
    "additionalProperties": False,
}


def generate_action(model, prompt):
    """Structured tool intent; ChatDev executes the resulting native ToolCallPayload."""
    payload = {
        "application": "agentlab", "model": model, "input": prompt,
        "schemaName": "creativeAction", "schema": ACTION_SCHEMA,
    }
    response = _request("/v1/generate",
                        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"))
    try:
        action = json.loads(response["text"])
        if not isinstance(action, dict):
            raise ValueError("Not a map")
        if action["tool"] not in ACTION_SCHEMA["properties"]["tool"]["enum"]:
            raise ValueError("Unknown tool")
        for field in ("speech", "path", "content"):
            if not isinstance(action[field], str):
                raise ValueError("Invalid action text")
    except (KeyError, TypeError, ValueError):
        # The call may already have consumed tokens. Preserve provider usage,
        # report the malformed output, and let the next agent/ronda proceed.
        # Never pretend an invalid tool request ran.
        return {
            "speech": "[Error de formato de Luna: no se pudo interpretar esta "
                      "intervención. No se ha ejecutado ninguna herramienta.]",
            "tool": "none", "path": "", "content": "",
        }, response.get("usage") or {}
    return action, response.get("usage") or {}


def probe(model):
    try:
        ensure_running()
        print(f"Servicio compartido AI-APPS activo. Probando {model} una sola vez...", flush=True)
        response, usage = generate(model, "Responde solo con una frase de saludo.")
        print("Respuesta: " + response, flush=True)
        print("Tokens: " + str(usage.get("inputTokens", "no disponible")) +
              " entrada, " + str(usage.get("outputTokens", "no disponible")) +
              " salida.", flush=True)
        return 0
    except RuntimeError as exc:
        print("No se ha podido generar: " + str(exc), flush=True)
        return 1
