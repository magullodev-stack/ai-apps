"""A room for ChatDev agents to imagine together, with optional Codex creation."""
import argparse
import contextlib
from datetime import datetime, timezone
import io
import json
import os
from pathlib import Path
import re
import shutil
import sys
import uuid

from lab import ROOT, RUNS, git, prepare_workspace, verify_chatdev

VOICES = (
    ("Chispa", "Imagina experiencias interactivas inesperadas, sensoriales y juguetonas. "
     "Evita utilidades genéricas y aplicaciones administrativas. Haz propuestas que den ganas de verlas."),
    ("Caos", "Eres un colaborador creativo inconformista. Responde de verdad a las ideas anteriores: "
     "combina, contradice, transforma y arriesga. No hagas revisión de calidad ni informes."),
    ("Materia", "Piensas con movimiento, color, sonido y tacto. Convierte lo que se conversa en "
     "experiencias que puedan vivir en una pantalla. Propón un gesto visual concreto, no un plan de ingeniería."),
)

COMMON = (
    "Estás conversando con otros agentes en un taller de arte interactivo. "
    "No eres un supervisor ni un gestor de tareas. Puedes discrepar, sorprender y cambiar de dirección. "
    "Habla en español, con naturalidad y brevedad. Nada de listas de verificación, auditorías, "
    "documentación, pruebas obligatorias ni relatos técnicos. "
    "Cuando de verdad queráis materializar o transformar una idea, puedes terminar tu intervención "
    "con una sola línea 'CREAR: <lo que debería experimentar la persona en pantalla>'. "
    "Es una posibilidad, no una obligación. No menciones herramientas ni otros proyectos."
)

WORKSPACE_RULES = (
    "Este espacio pertenece solo al experimento. Cambia únicamente los archivos de aquí. "
    "No accedas a directorios superiores, otras aplicaciones, servicios ni credenciales. "
    "No hagas commits, despliegues, documentación ni pruebas salvo que una idea lo requiera.\n"
)


def open_room(args):
    RUNS.mkdir(exist_ok=True)
    if args.room:
        room = Path(args.room).resolve(strict=True)
        if room.parent != RUNS.resolve() or not (room / "room.json").is_file():
            raise ValueError("Selecciona una sala existente dentro de agent-lab/runs")
        state = json.loads((room / "room.json").read_text(encoding="utf-8"))
        if any(str(item.get("text", "")).casefold().startswith("error calling model ")
               for item in state.get("conversation", [])):
            raise ValueError("Esta sala contiene solo respuestas fallidas; comienza una sala nueva con -Idea")
        if args.idea or args.flutter:
            raise ValueError("Al continuar una sala no repitas -Idea ni -Flutter")
        if args.model:
            state["model"] = args.model
            save(room, state)
        return room, state
    if not args.idea or not args.idea.strip():
        raise ValueError("Indica -Idea para comenzar o -Room para continuar")
    room = RUNS / ("creative_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "_" + uuid.uuid4().hex[:6])
    room.mkdir()
    if args.flutter:
        workspace, _, _ = prepare_workspace(room, flutter=True)
    else:
        workspace = room / "workspace"
        workspace.mkdir()
        (workspace / "AGENTS.md").write_text(WORKSPACE_RULES, encoding="utf-8")
        git(workspace, "init", "--initial-branch=lab")
        git(workspace, "config", "user.name", "Creative Room")
        git(workspace, "config", "user.email", "creative@localhost")
        git(workspace, "config", "core.hooksPath", "NUL" if os.name == "nt" else "/dev/null")
        git(workspace, "add", "-A")
        git(workspace, "commit", "-m", "Empty creative space")
    (workspace / "AGENTS.md").write_text(WORKSPACE_RULES, encoding="utf-8")
    state = {"idea": args.idea.strip(), "provider": args.provider,
             "model": args.model or ("gemini-2.5-flash" if args.provider == "gemini" else "gpt-5-nano"),
             "conversation": []}
    save(room, state)
    return room, state


def save(room, state):
    (room / "room.json").write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def actual_tokens(result):
    """Read provider-reported usage from ChatDev, never estimate token counts."""
    totals = (result.meta_info.token_usage or {}).get("total_usage") or {}
    incoming, outgoing = totals.get("input_tokens"), totals.get("output_tokens")
    if (type(incoming) is int and type(outgoing) is int and
            incoming >= 0 and outgoing >= 0 and incoming + outgoing > 0):
        return {"input": incoming, "output": outgoing}
    return None


def show_spending(meter, provider, model, *, completed):
    print("\n" + "=" * 46, flush=True)
    status = "FINALIZADO" if completed else "INTERRUMPIDO"
    print(f"SALA · {status} · {meter['calls']} respuestas válidas acumuladas", flush=True)
    print(f"Tokens de entrada: {meter['input']:,}", flush=True)
    print(f"Tokens de salida:  {meter['output']:,}", flush=True)
    print(f"Tokens totales:    {meter['input'] + meter['output']:,}", flush=True)
    if meter["calls"] == 0:
        print("Coste: desconocido (no hubo respuestas válidas ni datos de consumo).", flush=True)
    elif provider == "openai" and model == "gpt-5-nano":
        # Tarifas orientativas, no consulta a la facturación de OpenAI.
        incoming_rate, outgoing_rate = 0.05, 0.40  # USD por millón
        estimate = (meter["input"] * incoming_rate + meter["output"] * outgoing_rate) / 1_000_000
        qualifier = "parcial " if (meter["missing"] or not completed) else ""
        print(f"Coste {qualifier}estimado: US${estimate:.6f}", flush=True)
        print("Referencia: US$0.05/M entrada + US$0.40/M salida.", flush=True)
        print("Estimación sin descuento por caché; consulta la factura para el coste real.", flush=True)
    else:
        print("Coste USD: tarifa no configurada para este modelo.", flush=True)
    if meter["missing"]:
        print(f"Sin datos de tokens: {meter['missing']} respuestas.", flush=True)
    if not completed:
        print("El coste de solicitudes fallidas no se puede deducir de este contador.", flush=True)
    print("=" * 46, flush=True)


def speak(room, state, name, character):
    import runtime.sdk as sdk
    recent = state["conversation"][-10:]
    conversation = "\n\n".join(item["name"] + ": " + item["text"] for item in recent)
    prompt = ("Semilla inicial: " + state["idea"] + "\n\n" +
              ("Lo que habéis imaginado hasta ahora:\n" + conversation[-9000:] + "\n\n" if conversation else "") +
              "Ahora habla tú, " + name + ", dirigiéndote a los demás.")
    before = Path.cwd()
    try:
        os.chdir(room)
        sdk.OUTPUT_ROOT = room / "internal"
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            result = sdk.run_workflow(
                ROOT / "workflows" / "creative_turn.yaml",
                task_prompt=prompt,
                variables={"CREATIVE_PROVIDER": "lab_creative_" + state["provider"],
                           "CREATIVE_MODEL": state["model"],
                           "CREATIVE_ROLE": COMMON + "\n\nTu personalidad: " + character},
                session_name="creative_" + str(len(state["conversation"]) + 1),
                log_level="ERROR",
            )
    finally:
        os.chdir(before)
    answer = result.final_message.text_content().strip() if result.final_message else ""
    if not answer:
        raise RuntimeError(name + " no ha podido responder")
    if answer.casefold().startswith("error calling model "):
        # Upstream ChatDev converts model exceptions to ordinary assistant text.
        # Never propagate these messages to other agents or attempt another round.
        reason = answer.split("Original input:", 1)[0].strip()
        raise RuntimeError(name + ": " + reason[:650])
    usage = actual_tokens(result)
    state["conversation"].append({"name": name, "text": answer, "usage": usage})
    save(room, state)
    print("\n" + name + ":\n" + answer + "\n", flush=True)
    match = re.search(r"(?im)^CREAR:\s*(.+)$", answer)
    return (match.group(1).strip() if match else None), usage


def build(room, idea, executable):
    from bridge import invoke_codex
    if not shutil.which(executable):
        raise FileNotFoundError("No se encuentra Codex. La conversación se ha conservado.")
    folder = room / "builds"
    folder.mkdir(exist_ok=True)
    artifact = folder / f"{len(list(folder.iterdir())) + 1:03d}"
    artifact.mkdir()
    result = invoke_codex(
        {"executor": "codex", "codex": executable, "model": None, "timeout": 120},
        room / "workspace", artifact,
        "Da vida a esta idea dentro de este workspace: " + idea +
        "\nConstruye o transforma directamente la experiencia interactiva. "
        "Prefiere impacto visual y una primera versión visible a complejidad. "
        "No hagas informes, auditorías, documentación ni baterías de pruebas. "
        "No toques archivos fuera del workspace, ni inicies Android, ni hagas commits.",
    )
    if result["status"] != "completed":
        print("Codex no pudo construir ahora. La sala y sus ideas siguen disponibles.", file=sys.stderr)
        return False
    print("La creación ha cambiado. Puedes verla o continuar la conversación.", flush=True)
    return True


def probe_openai(model):
    """One minimal request that bypasses ChatDev and the custom provider."""
    from openai import OpenAI, APIStatusError

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("Falta OPENAI_API_KEY.", file=sys.stderr)
        return 2

    print("Probando una única solicitud directa a OpenAI con " + model + "...", flush=True)
    client = OpenAI(api_key=api_key, base_url="https://api.openai.com/v1",
                    max_retries=0, timeout=30)
    try:
        reply = client.responses.create(
            model=model, input="Responde únicamente con HOLA.",
            max_output_tokens=256,
        )
    except APIStatusError as exc:
        response = exc.response
        try:
            payload = response.json()
        except (ValueError, AttributeError):
            payload = None

        details = payload.get("error", payload) if isinstance(payload, dict) else {}
        if not isinstance(details, dict):
            details = {"message": str(details)}

        # Unlike the old probe, show the actual response if it is not JSON.
        # Redact credentials before displaying any text returned by a gateway.
        def safe(value):
            string = str(value).replace(api_key, "[CLAVE_OCULTA]")
            string = re.sub(r"sk-[A-Za-z0-9_-]{12,}", "[CLAVE_OCULTA]", string)
            string = re.sub(r"(?i)Bearer\\s+[^\\s,;]+", "Bearer [CLAVE_OCULTA]", string)
            return string[:900]

        print(f"Solicitud rechazada: HTTP {exc.status_code}", file=sys.stderr)
        print("  Content-Type: " + safe(response.headers.get("content-type", "ausente")),
              file=sys.stderr)
        print("  Request-ID: " + safe(
            response.headers.get("x-request-id") or
            getattr(exc, "request_id", None) or "ausente"),
            file=sys.stderr)
        for field in ("message", "type", "code", "param"):
            if details.get(field):
                print(f"  {field}: {safe(details[field])}", file=sys.stderr)

        if not any(details.get(field) for field in ("message", "type", "code", "param")):
            body = response.text or getattr(exc, "body", None)
            if body:
                print("  Respuesta original: " + safe(body), file=sys.stderr)
            else:
                print("  Respuesta original: vacía", file=sys.stderr)

        if response.headers.get("via"):
            print("  La respuesta pasó por un intermediario HTTP.", file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"No se pudo conectar: {type(exc).__name__}: {str(exc)[:500]}", file=sys.stderr)
        return 1
    usage = getattr(reply, "usage", None)
    tokens_in = getattr(usage, "input_tokens", None) if usage else None
    tokens_out = getattr(usage, "output_tokens", None) if usage else None
    print("OpenAI responde correctamente. Modelo: " + str(reply.model), flush=True)
    print("Texto: " + repr((reply.output_text or "")[:180]), flush=True)
    if tokens_in is not None and tokens_out is not None:
        print(f"Tokens de esta única prueba: {tokens_in} entrada, {tokens_out} salida.",
              flush=True)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--idea")
    parser.add_argument("--room")
    parser.add_argument("--provider", choices=("openai", "gemini"), default="openai")
    parser.add_argument("--model")
    parser.add_argument("--rounds", type=int, default=10, help="Rondas completas de Chispa, Caos y Materia")
    parser.add_argument("--flutter", action="store_true")
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--android", action="store_true")
    parser.add_argument("--codex", default="codex")
    parser.add_argument("--probe", action="store_true", help="Una llamada directa para diagnosticar la API sin ChatDev")
    args = parser.parse_args()
    if args.probe:
        if args.provider != "openai":
            parser.error("--probe está disponible para OpenAI")
        return probe_openai(args.model or "gpt-5-nano")
    if not 1 <= args.rounds <= 50:
        parser.error("--rounds debe estar entre 1 y 50")
    if args.android and not args.build:
        parser.error("--android necesita --build")
    # Never prepare Flutter or create a room if there is no model connection.
    if not args.room:
        requested_key = "OPENAI_API_KEY" if args.provider == "openai" else "GEMINI_API_KEY"
        if not os.environ.get(requested_key):
            print("Falta " + requested_key +
                  ". Esta conexión usa una API independiente de Codex; puede tener coste.", file=sys.stderr)
            return 2
    verify_chatdev()
    room, state = open_room(args)
    key = "OPENAI_API_KEY" if state["provider"] == "openai" else "GEMINI_API_KEY"
    if not os.environ.get(key):
        print("Falta " + key + " para continuar esta sala.", file=sys.stderr)
        return 2
    sys.path.insert(0, str(ROOT / ".deps" / "chatdev"))
    import creative_provider
    creative_provider.register()
    print(f"Sala: {room}", flush=True)
    print(f"Modelo: {state['model']} · {args.rounds} rondas · {args.rounds * 3} intervenciones", flush=True)
    print("Las respuestas aparecen al completarse; no se transmiten palabra por palabra.", flush=True)
    suggestion = None
    # Include earlier successful turns if this is a continuation of the same room.
    meter = {"input": 0, "output": 0, "missing": 0, "calls": 0}
    for turn in state["conversation"]:
        meter["calls"] += 1
        usage = turn.get("usage")
        if isinstance(usage, dict):
            meter["input"] += usage["input"]
            meter["output"] += usage["output"]
        else:
            meter["missing"] += 1
    completed = False
    try:
        for round_number in range(1, args.rounds + 1):
            print(f"\n{'─' * 14} RONDA {round_number}/{args.rounds} {'─' * 14}", flush=True)
            for _ in VOICES:
                name, character = VOICES[len(state["conversation"]) % len(VOICES)]
                print(f"\n{name} está pensando...", flush=True)
                proposal, usage = speak(room, state, name, character)
                meter["calls"] += 1
                if usage:
                    meter["input"] += usage["input"]
                    meter["output"] += usage["output"]
                else:
                    meter["missing"] += 1
                if proposal:
                    suggestion = proposal
        completed = True
    except RuntimeError as exc:
        print(f"\nConexión interrumpida: {exc}", file=sys.stderr, flush=True)
        return 1
    finally:
        show_spending(meter, state["provider"], state["model"], completed=completed)
    if args.build and suggestion:
        if build(room, suggestion, args.codex) and args.android:
            from lab_android import AndroidExperiment
            try:
                status = AndroidExperiment(room).start()
                print("Pantalla: " + status["status"])
            except Exception as exc:
                print("No se pudo mostrar todavía la app: " + str(exc), file=sys.stderr)
    elif args.build:
        print("Los agentes prefirieron seguir imaginando. No se ha invocado Codex.")
    print("Para seguir: .\\agent-lab\\creative.ps1 -Room '" + str(room) + "'")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nConversación interrumpida.")
        raise SystemExit(130)
