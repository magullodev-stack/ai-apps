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


# USD per million tokens. AI-APPS already uses these project-supplied
# rates in apps/quizai/tool/generar_pivotes.dart.
MODEL_RATES = {
    "gpt-5.6-luna": (0.20, 1.20),
    "gpt-5.6-terra": (2.0, 12.0),
    "gpt-5.6-sol": (4.0, 20.0),
    "gpt-5.4-mini": (0.75, 4.50),
    # Existing Nano reference rate (not a live billing lookup).
    "gpt-5-nano": (0.05, 0.40),
}


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
    (room / "manifest.json").write_text(
        json.dumps({"run_id": room.name, "kind": "creative", "workspace": "workspace"}),
        encoding="utf-8",
    )
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
             "model": args.model or ("gemini-2.5-flash" if args.provider == "gemini" else "gpt-5.6-luna" if args.provider == "shared" else "gpt-5-nano"),
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


def room_meter(state):
    """Recalculate the entire room from saved turns, including older sessions."""
    meter = {
        "input": 0, "output": 0, "missing": 0, "calls": 0,
        "priced": 0, "unpriced": 0, "cost_input": 0.0, "cost_output": 0.0,
        "priced_models": set(),
    }
    for turn in [*state["conversation"], *state.get("creations", [])]:
        meter["calls"] += 1
        usage = turn.get("usage")
        if not isinstance(usage, dict):
            meter["missing"] += 1
            continue
        incoming, outgoing = usage.get("input"), usage.get("output")
        if (not isinstance(incoming, int) or not isinstance(outgoing, int)
                or incoming < 0 or outgoing < 0):
            meter["missing"] += 1
            continue
        meter["input"] += incoming
        meter["output"] += outgoing
        model = turn.get("model", state["model"]).lower()
        rates = MODEL_RATES.get(model)
        if rates is None:
            meter["unpriced"] += 1
            continue
        meter["priced"] += 1
        meter["priced_models"].add(model)
        meter["cost_input"] += incoming * rates[0] / 1_000_000
        meter["cost_output"] += outgoing * rates[1] / 1_000_000
    return meter


def show_spending(meter, provider, model, *, completed):
    print("\n" + "=" * 46, flush=True)
    status = "FINALIZADO" if completed else "INTERRUMPIDO"
    print(f"SALA · {status} · {meter['calls']} llamadas acumuladas (agentes y creaciones)", flush=True)
    print(f"Tokens de entrada: {meter['input']:,}", flush=True)
    print(f"Tokens de salida:  {meter['output']:,}", flush=True)
    print(f"Tokens totales:    {meter['input'] + meter['output']:,}", flush=True)
    if meter["priced"]:
        amount = meter["cost_input"] + meter["cost_output"]
        partial = meter["missing"] or meter["unpriced"] or not completed
        print(f"Coste {'parcial ' if partial else ''}estimado: US${amount:.6f}", flush=True)
        print(f"  Entrada: US${meter['cost_input']:.6f} · Salida: US${meter['cost_output']:.6f}",
              flush=True)
        if len(meter["priced_models"]) == 1:
            priced_model = next(iter(meter["priced_models"]))
            rates = MODEL_RATES[priced_model]
            print(f"  Tarifa {priced_model}: US${rates[0]:g}/M entrada, "
                  f"US${rates[1]:g}/M salida", flush=True)
        print("Estimación con tarifas de referencia de AI-APPS; "
              "sin descuentos de caché.", flush=True)
    else:
        print("Coste: no disponible (no hay tokens con una tarifa conocida).", flush=True)
    if meter["unpriced"]:
        print(f"Sin tarifa: {meter['unpriced']} intervenciones.", flush=True)
    if meter["missing"]:
        print(f"Sin datos de tokens: {meter['missing']} intervenciones.", flush=True)
    if not completed:
        print("El coste de las solicitudes fallidas no puede calcularse aquí.", flush=True)
    print("=" * 46, flush=True)


def speak(room, state, name, character):
    import runtime.sdk as sdk
    recent = state["conversation"][-10:]
    conversation = "\n\n".join(item["name"] + ": " + item["text"] for item in recent)
    observation = (state.get("observations") or [""])[-1]
    prompt = ("Semilla inicial: " + state["idea"] + "\n\n" +
              ("Lo que habéis imaginado hasta ahora:\n" + conversation[-9000:] + "\n\n" if conversation else "") +
              ("Última impresión del observador que probó la experiencia: " + observation + "\n\n" if observation else "") +
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
    state["conversation"].append({"name": name, "model": state["model"], "text": answer, "usage": usage})
    save(room, state)
    print("\n" + name + ":\n" + answer + "\n", flush=True)
    match = re.search(r"(?im)^CREAR:\s*(.+)$", answer)
    return (match.group(1).strip() if match else None), usage


def materialize(room, state, idea):
    """One creative Luna call writes only lib/main.dart in the isolated Flutter app."""
    from shared_ai import generate_flutter
    from lab_android import flutter_package
    project = room / "workspace"
    if flutter_package(project) is None:
        raise RuntimeError(
            "La sala no contiene Flutter. Crea una nueva con -Flutter para verla en Android."
        )
    file = project / "lib" / "main.dart"
    previous = file.read_text(encoding="utf-8") if file.exists() else ""
    history = "\n\n".join(
        item["name"] + ": " + item["text"]
        for item in state["conversation"][-9:]
    )
    prompt = (
        "Eres Luna, una herramienta creativa que convierte el diálogo de tres "
        "artistas-agentes en una experiencia móvil Flutter REAL, no un boceto.\n"
        "Su idea actual es: " + (idea or " / ".join(state["idea"].splitlines())) +
        "\nSu conversación:\n" + history[-10_000:] +
        "\n\nDevuelve SOLO el archivo completo lib/main.dart. "
        "Construye una escena expresiva, cinematográfica, con animación continua "
        "e interacción táctil. Prioriza la idea estética y el movimiento, "
        "no pantallas de texto, menús, contadores ni botones genéricos. "
        "Usa CustomPainter, AnimationController o similares cuando aporten vida. "
        "Admite varios gestos y varios elementos móviles. "
        "Utiliza exclusivamente Flutter SDK y dart:math / dart:ui / dart:async. "
        "No importes paquetes externos ni uses archivos, red, procesos, assets, "
        "plugins o dispositivos. Debe arrancar con void main() y runApp(), "
        "compilar en Flutter estable y tener MaterialApp o WidgetsApp. "
        "No escribas documentación ni pruebas."
    )
    if previous:
        prompt += (
            "\n\nEsta es la experiencia actual. EVOLUCIÓNALA, no empieces de cero "
            "salvo que los agentes cambien radicalmente de dirección:\n" + previous[-16_000:]
        )
    print("\nLuna está materializando la experiencia en Flutter...", flush=True)
    code, usage = generate_flutter(state["model"], prompt)
    # The provider has already charged for generation, even if we reject its code.
    state.setdefault("creations", []).append({
        "model": state["model"],
        "usage": {"input": usage.get("inputTokens"), "output": usage.get("outputTokens")},
        "idea": idea,
    })
    save(room, state)
    import re as _re
    imports = _re.findall(r"^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]", code, flags=_re.M)
    allowed = {"package:flutter/material.dart", "package:flutter/widgets.dart",
               "package:flutter/painting.dart", "package:flutter/animation.dart",
               "package:flutter/gestures.dart", "package:flutter/scheduler.dart",
               "dart:math", "dart:ui", "dart:async"}
    if any(uri not in allowed for uri in imports) or _re.search(
        r"\b(?:Process|HttpClient|Socket|File\s*\(|Directory\s*\(|Isolate)\b", code
    ):
        raise RuntimeError("Luna intentó incluir dependencias o capacidades ajenas al experimento.")
    if "void main(" not in code or "runApp(" not in code:
        raise RuntimeError("Luna no devolvió una aplicación Flutter ejecutable.")
    file.write_text(code, encoding="utf-8")
    print("Experiencia creada en " + str(file), flush=True)
    return True



def studio_round(room, state, *, android):
    """One ChatDev graph: three linked agents, native function tool loops."""
    import runtime.sdk as sdk
    history = "\n\n".join(
        item["name"] + ": " + item["text"] for item in state["conversation"][-9:]
    )
    feedback = (state.get("observations") or [""])[-1]
    prompt = (
        "Idea inicial: " + state["idea"] +
        "\n\nConversación anterior:\n" + history[-8500:] +
        ("\n\nOpinión de quien acaba de usar el prototipo: " + feedback if feedback else "") +
        "\n\nEstá disponible un proyecto Flutter real en workspace. "
        "Tenéis herramientas de ChatDev para leer y escribir Dart, analizar errores, "
        "ejecutar el proyecto y observar el estado de Android. "
        "Hablad y colaborad como artistas, no como gestores. "
        "Conseguid una experiencia visible y táctil, no una descripción. "
        "Si lib/main.dart todavía es la plantilla vacía, transformadla con room_write. "
        "Cada participante puede intervenir en el código y mejorar lo que han creado los demás. "
        + ("Podéis abrir vuestro emulador con room_launch y revisar su estado con room_observe."
           if android else "Por ahora no abras Android; escribe y analiza el código.")
    )
    before = Path.cwd()
    try:
        os.chdir(room)
        sdk.OUTPUT_ROOT = room / "internal"
        print("ChatDev: Chispa → Caos → Materia (herramientas Flutter disponibles)...", flush=True)
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            result = sdk.run_workflow(
                ROOT / "workflows" / "creative_studio.yaml",
                task_prompt=prompt,
                variables={
                    "CREATIVE_MODEL": state["model"],
                    "CHISPA_ROLE": COMMON.replace(
                        "No menciones herramientas ni otros proyectos.",
                        "Usa las herramientas del experimento cuando quieras crear o transformar algo."
                    ) + "\n\n" + VOICES[0][1],
                    "CAOS_ROLE": COMMON.replace(
                        "No menciones herramientas ni otros proyectos.",
                        "Puedes cambiar directamente el código, aunque otros agentes tengan otra opinión."
                    ) + "\n\n" + VOICES[1][1],
                    "MATERIA_ROLE": COMMON.replace(
                        "No menciones herramientas ni otros proyectos.",
                        "Puedes tocar archivos Flutter y probar la experiencia cuando quieras."
                    ) + "\n\n" + VOICES[2][1],
                },
                session_name="studio_" + str(len(state["conversation"]) + 1),
                log_level="ERROR",
            )
    finally:
        os.chdir(before)
    outputs = result.meta_info.outputs or {}
    all_tokens = (result.meta_info.token_usage or {}).get("node_usages") or {}
    for node_id, name in (("chispa", "Chispa"), ("caos", "Caos"), ("materia", "Materia")):
        block = outputs.get("node_" + node_id) or {}
        results = block.get("results") or []
        if not results:
            raise RuntimeError("ChatDev no devolvió la intervención de " + name)
        payload = results[-1].get("payload")
        if isinstance(payload, dict):
            content = payload.get("content", "")
            if isinstance(content, list):
                speech = "\n".join(
                    str(element.get("text", "")) for element in content
                    if isinstance(element, dict)
                ).strip()
            else:
                speech = str(content).strip()
        else:
            speech = str(payload).strip()
        if not speech or "error calling model" in speech.casefold():
            raise RuntimeError(name + " no completó la intervención: " + speech[:280])
        usage = all_tokens.get(node_id) or {}
        tokens_in, tokens_out = usage.get("input_tokens"), usage.get("output_tokens")
        measured = (
            {"input": tokens_in, "output": tokens_out}
            if isinstance(tokens_in, int) and isinstance(tokens_out, int)
            and tokens_in + tokens_out > 0 else None
        )
        state["conversation"].append({
            "name": name, "model": state["model"], "text": speech, "usage": measured
        })
        save(room, state)
        print("\n" + name + ":\n" + speech + "\n", flush=True)
    return result


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
            string = re.sub(r"(?i)Bearer\s+[^\s,;]+", "Bearer [CLAVE_OCULTA]", string)
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
    parser.add_argument("--provider", choices=("shared", "openai", "gemini"), default="shared")
    parser.add_argument("--model")
    parser.add_argument("--rounds", type=int, default=10, help="Rondas completas de Chispa, Caos y Materia")
    parser.add_argument("--feedback", help="Observación sobre lo que aparece en el emulador")
    parser.add_argument("--flutter", action="store_true")
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--android", action="store_true")
    parser.add_argument("--codex", default="codex")
    parser.add_argument("--probe", action="store_true", help="Una llamada directa para diagnosticar la API sin ChatDev")
    parser.add_argument("--cost-only", action="store_true", help="Mostrar el precio de una sala sin hacer llamadas")
    args = parser.parse_args()
    if args.cost_only:
        if not args.room or args.idea or args.model or args.build or args.flutter or args.android or args.probe:
            parser.error("--cost-only necesita únicamente --room")
        _, state = open_room(args)
        show_spending(room_meter(state), state["provider"], state["model"], completed=True)
        return 0
    if args.probe:
        if args.provider == "shared":
            from shared_ai import probe
            return probe(args.model or "gpt-5.6-luna")
        if args.provider != "openai":
            parser.error("--probe solo está disponible para shared u openai")
        return probe_openai(args.model or "gpt-5-nano")
    if not 1 <= args.rounds <= 50:
        parser.error("--rounds debe estar entre 1 y 50")
    if args.android and not args.build:
        parser.error("--android necesita --build")
    if args.android and not (args.flutter or args.room):
        parser.error("--android necesita --flutter en una sala nueva")
    if args.build and args.provider == "shared" and not (args.flutter or args.room):
        parser.error("Para crear con ChatDev debes indicar -Flutter o continuar una sala Flutter")
    # Check connection before creating a room or spending any model tokens.
    if args.provider == "shared":
        from shared_ai import ensure_running
        try:
            ensure_running()
        except RuntimeError as exc:
            print("Servicio compartido no disponible: " + str(exc), file=sys.stderr)
            return 2
    elif not args.room:
        requested_key = "OPENAI_API_KEY" if args.provider == "openai" else "GEMINI_API_KEY"
        if not os.environ.get(requested_key):
            print("Falta " + requested_key, file=sys.stderr)
            return 2
    verify_chatdev()
    room, state = open_room(args)
    if state["provider"] != "shared":
        key = "OPENAI_API_KEY" if state["provider"] == "openai" else "GEMINI_API_KEY"
        if not os.environ.get(key):
            print("Falta " + key + " para continuar esta sala.", file=sys.stderr)
            return 2
    if args.feedback:
        state.setdefault("observations", []).append(args.feedback[:1800])
        save(room, state)
    studio = args.build and state["provider"] == "shared"
    if studio:
        if not args.flutter and not (room / "workspace" / "pubspec.yaml").is_file():
            print("La sala existente no es Flutter. Empieza con -Idea ... -Flutter -Build.",
                  file=sys.stderr)
            return 2
        os.environ["MAC_FUNCTIONS_DIR"] = str(ROOT / "creative_tools")
        os.environ["AGENTLAB_ROOM"] = str(room)
        os.environ["AGENTLAB_ANDROID_ENABLED"] = "1" if args.android else "0"
    sys.path.insert(0, str(ROOT / ".deps" / "chatdev"))
    import creative_provider
    creative_provider.register()
    print(f"Sala: {room}", flush=True)
    print(f"Modelo: {state['model']} · {args.rounds} rondas · {args.rounds * 3} intervenciones", flush=True)
    if state["provider"] == "shared":
        print("Conectado al servicio Dart de IA compartida de AI-APPS.", flush=True)
    print("Las respuestas aparecen al completarse; no se transmiten palabra por palabra.", flush=True)
    suggestion = None
    completed = False
    try:
        for round_number in range(1, args.rounds + 1):
            print(f"\n{'─' * 14} RONDA {round_number}/{args.rounds} {'─' * 14}", flush=True)
            if studio:
                studio_round(room, state, android=args.android)
            else:
                for _ in VOICES:
                    name, character = VOICES[len(state["conversation"]) % len(VOICES)]
                    print(f"\n{name} está pensando...", flush=True)
                    proposal, _usage = speak(room, state, name, character)
                    if proposal:
                        suggestion = proposal
        if args.build and not studio:
            if not build(room, suggestion or state["idea"], args.codex):
                raise RuntimeError("No se pudo crear la experiencia.")
            if args.android:
                from lab_android import AndroidExperiment
                print("Abriendo la experiencia en el emulador Android...", flush=True)
                output = AndroidExperiment(room).start()
                print("Emulador: " + output.get("status", "desconocido"), flush=True)
        elif studio:
            file = room / "workspace" / "lib" / "main.dart"
            if not file.is_file():
                raise RuntimeError("Los agentes no han creado ningún archivo Flutter.")
            changes = git(room / "workspace", "status", "--porcelain", "--untracked-files=all")
            if not changes.strip():
                raise RuntimeError(
                    "Los agentes conversaron pero no editaron Flutter. "
                    "La aplicación de plantilla permanece sin cambios."
                )
            print("Flutter modificado: " + str(file), flush=True)
            from lab_android import AndroidExperiment
            if args.android:
                controller = AndroidExperiment(room)
                status = controller.state.get("status")
                print("Estado del emulador propio: " + str(status or "sin iniciar"), flush=True)
                if status != "running":
                    print("Los agentes pueden abrirlo con room_launch en otra ronda.", flush=True)
        completed = True
    except (RuntimeError, FileNotFoundError, ValueError) as exc:
        print(f"\nExperimento interrumpido: {exc}", file=sys.stderr, flush=True)
        return 1
    finally:
        show_spending(room_meter(state), state["provider"], state["model"], completed=completed)
    print("Para seguir: .\\agent-lab\\creative.ps1 -Room '" + str(room) + "'")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nConversación interrumpida.")
        raise SystemExit(130)
