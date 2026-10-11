"""Creative room powered by ChatDev and AI-APPS shared AI service."""
import argparse
import contextlib
from datetime import datetime, timezone
import io
import json
import os
from pathlib import Path
import sys
import uuid

from lab import ROOT, RUNS, CREATIVE_RUNS, git, prepare_workspace, verify_chatdev

VOICES = (
    ("Chispa", "Te atraen las posibilidades inesperadas, la intuición y el juego."),
    ("Caos", "Tiendes a cuestionar convenciones, combinar ideas y cambiar de perspectiva."),
    ("Materia", "Te interesan la materialidad, el movimiento, los gestos y lo tangible."),
)

COMMON = (
    "Compartes con otros agentes un espacio de exploración. "
    "No hay encargo artístico, tema ni resultado predeterminado. "
    "Puedes conversar, disentir, experimentar y utilizar las herramientas "
    "disponibles cuando lo consideres interesante. Tampoco hay obligación de programar. "
    "Habla en español con naturalidad."
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


def creative_rooms():
    """Only room summaries, never generated Flutter/Android internals."""
    rooms = []
    for root in {RUNS, CREATIVE_RUNS}:
        if root.is_dir():
            rooms.extend(path for path in root.glob("creative_*")
                         if path.is_dir() and (path / "room.json").is_file())
    return sorted(rooms, key=lambda room: room.name, reverse=True)


def latest_room():
    rooms = creative_rooms()
    if not rooms:
        raise ValueError("Aún no hay experiencias creativas.")
    return rooms[0]


def list_rooms():
    rooms = creative_rooms()
    if not rooms:
        print("Todavía no hay experiencias creativas.")
        return
    print("EXPERIENCIAS RECIENTES")
    for room in rooms[:12]:
        try:
            state = json.loads((room / "room.json").read_text(encoding="utf-8"))
            idea = str(state.get("idea") or "Exploración libre").replace("\n", " ")[:75]
            mode = "Flutter" if (room / "workspace" / "pubspec.yaml").is_file() else "Ideas"
            meter = room_meter(state, room=room)
            spent = (" · aprox. US$" + format(
                meter["cost_input"] + meter["cost_output"], ".6f")
                if meter["priced"] else "")
            print(f"  {room.name} · {mode}{spent}")
            print("    " + idea)
        except (OSError, ValueError, KeyError):
            print("  " + room.name)
    print("\n-Lista para ver experiencias, -Latest -CostOnly para el precio más reciente.")


def open_room(args):
    CREATIVE_RUNS.mkdir(parents=True, exist_ok=True)
    if args.room:
        room = Path(args.room).resolve(strict=True)
        if room.parent not in {RUNS.resolve(), CREATIVE_RUNS.resolve()} or not (room / "room.json").is_file():
            raise ValueError("Selecciona una experiencia creativa existente")
        state = json.loads((room / "room.json").read_text(encoding="utf-8"))
        if any(str(item.get("text", "")).casefold().startswith("error calling model ")
               for item in state.get("conversation", [])):
            raise ValueError("Esta sala contiene solo respuestas fallidas; comienza una sala nueva")
        if args.idea or args.flutter:
            raise ValueError("Al continuar una sala no repitas -Idea ni -Flutter")
        if args.model:
            state["model"] = args.model
            save(room, state)
        return room, state
    if not (args.idea and args.idea.strip()) and not (args.flutter and args.build):
        raise ValueError("Indica -Idea o inicia una exploración libre con -Flutter -Build")
    room = CREATIVE_RUNS / ("creative_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "_" + uuid.uuid4().hex[:6])
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
    state = {"idea": (args.idea or "").strip(), "provider": "shared",
             "model": args.model or "gpt-5.6-luna",
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


def room_meter(state, *, room=None):
    """Read past turns and every model call made inside the ChatDev tool loop."""
    meter = {
        "input": 0, "output": 0, "missing": 0, "calls": 0,
        "priced": 0, "unpriced": 0, "cost_input": 0.0, "cost_output": 0.0,
        "priced_models": set(),
    }
    offset = state.get("studio_ledger_start")
    if isinstance(offset, int) and room is not None:
        turns = [*state["conversation"][:offset], *state.get("creations", [])]
        events_file = room / "studio-events.jsonl"
        if events_file.is_file():
            try:
                with events_file.open(encoding="utf-8") as source:
                    turns.extend(event for line in source if line.strip()
                                 for event in [json.loads(line)]
                                 if event.get("kind") == "model")
            except (OSError, ValueError):
                print("Aviso: el registro de consumo está incompleto.", file=sys.stderr)
    else:
        turns = [*state["conversation"], *state.get("creations", [])]
    for turn in turns:
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


def show_spending(meter, *, completed):
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
    prompt = (
        ("Propuesta aportada por la persona: " + state["idea"] + "\n\n" if state["idea"] else
         "No hay un encargo ni un tema inicial.\n\n") +
        ("Conversación hasta ahora:\n" + conversation[-9000:] + "\n\n" if conversation else "") +
        ("Observación de quien probó la experiencia: " + observation + "\n\n" if observation else "") +
        "Te toca participar en la conversación."
    )
    before = Path.cwd()
    try:
        os.chdir(room)
        sdk.OUTPUT_ROOT = room / "internal"
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            result = sdk.run_workflow(
                ROOT / "workflows" / "creative_turn.yaml",
                task_prompt=prompt,
                variables={"CREATIVE_MODEL": state["model"],
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
    return usage


def studio_round(room, state, *, android):
    """One ChatDev graph: three linked agents, native function tool loops."""
    import runtime.sdk as sdk
    history = "\n\n".join(
        item["name"] + ": " + item["text"] for item in state["conversation"][-9:]
    )
    feedback = (state.get("observations") or [""])[-1]
    prompt = (
        ("Propuesta de la persona: " + state["idea"] + "\n\n" if state["idea"] else
         "No hay tema, idea inicial ni encargo de crear algo.\n\n") +
        ("Conversación anterior:\n" + history[-8500:] + "\n\n" if history else "") +
        ("Observación de la persona: " + feedback + "\n\n" if feedback else "") +
        "Compartís un proyecto Flutter aislado y herramientas para leer y modificar "
        "archivos Dart, comprobar errores y, si os interesa, probar lo que hagáis. "
        "Decidid entre vosotros qué explorar, si deseáis construir algo y cuándo. "
        "No es obligatorio escribir código ni seguir una dirección concreta. "
        + ("Tenéis un emulador propio disponible para iniciar o consultar."
           if android else "En esta sesión el emulador no está habilitado.")
    )
    if "studio_ledger_start" not in state:
        state["studio_ledger_start"] = len(state["conversation"])
        save(room, state)
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
                    "CHISPA_ROLE": COMMON + "\n\n" + VOICES[0][1],
                    "CAOS_ROLE": COMMON + "\n\n" + VOICES[1][1],
                    "MATERIA_ROLE": COMMON + "\n\n" + VOICES[2][1],
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
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--idea")
    parser.add_argument("--room")
    parser.add_argument("--latest", action="store_true", help="Última experiencia, sin buscar su carpeta")
    parser.add_argument("--list-rooms", action="store_true", help="Mostrar experiencias sin archivos internos")
    parser.add_argument("--transcript", action="store_true", help="Leer la conversación sin gastar tokens")
    parser.add_argument("--discard", action="store_true", help="Eliminar completamente una experiencia propia")
    parser.add_argument("--model")
    parser.add_argument("--rounds", type=int, default=10, help="Rondas completas de Chispa, Caos y Materia")
    parser.add_argument("--feedback", help="Observación sobre lo que aparece en el emulador")
    parser.add_argument("--flutter", action="store_true")
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--android", action="store_true")
    parser.add_argument("--probe", action="store_true", help="Comprobar el servicio de IA compartido")
    parser.add_argument("--cost-only", action="store_true", help="Mostrar el precio de una sala sin hacer llamadas")
    args = parser.parse_args()
    if args.list_rooms:
        list_rooms()
        return 0
    if args.latest:
        if args.room or args.idea or args.flutter:
            parser.error("--latest no combina con --room, --idea ni --flutter")
        args.room = str(latest_room())
    if args.discard:
        if not args.room or args.idea or args.build or args.flutter or args.android or args.probe or args.cost_only or args.transcript or args.model:
            parser.error("--discard necesita únicamente --room o --latest")
        room, _ = open_room(args)
        from lab_android import AndroidExperiment
        import shutil
        if room.is_symlink() or (hasattr(room, "is_junction") and room.is_junction()):
            raise ValueError("No se pueden eliminar salas enlazadas")
        android = AndroidExperiment(room)
        if android.state["session"]:
            # The shared Android manager verifies app identity and removes this run.
            android.owned(android.client.call("List"))
            android.client.call("Discard", android.state["session"])
        else:
            matches = [item for item in android.client.call("List") if item.get("appId") == android.app_id]
            if matches:
                raise RuntimeError("Existe una sesión Android que debe retirarse antes de borrar archivos")
            shutil.rmtree(room)
        print("Experiencia y sus archivos descartados: " + room.name)
        return 0
    if args.transcript:
        if not args.room or args.idea or args.build or args.flutter or args.android or args.probe:
            parser.error("--transcript necesita una experiencia con --room o --latest")
        room, state = open_room(args)
        transcript = room / "conversacion.md"
        if transcript.is_file():
            print(transcript.read_text(encoding="utf-8")[-90000:])
        else:
            print("Conversación conservada de esta experiencia (las acciones antiguas no tienen vista simplificada):")
            for turn in state.get("conversation", []):
                print("\n" + str(turn.get("name", "Agente")) + ":\n" +
                      str(turn.get("text", "")))
        return 0
    if args.cost_only:
        if not args.room or args.idea or args.model or args.build or args.flutter or args.android or args.probe:
            parser.error("--cost-only necesita únicamente --room")
        _, state = open_room(args)
        show_spending(room_meter(state, room=Path(args.room)), completed=True)
        return 0
    if args.probe:
        from shared_ai import probe
        return probe(args.model or "gpt-5.6-luna")
    if not 1 <= args.rounds <= 50:
        parser.error("--rounds debe estar entre 1 y 50")
    if args.android and not args.build:
        parser.error("--android necesita --build")
    if args.android and not (args.flutter or args.room):
        parser.error("--android necesita --flutter en una sala nueva")
    if args.build and not (args.flutter or args.room):
        parser.error("Para crear con ChatDev debes indicar -Flutter o continuar una sala Flutter")
    # Validate the existing shared AI service before any model calls.
    from shared_ai import ensure_running
    try:
        ensure_running()
    except RuntimeError as exc:
        print("Servicio compartido no disponible: " + str(exc), file=sys.stderr)
        return 2
    verify_chatdev()
    room, state = open_room(args)
    if state.get("provider") != "shared":
        print("Esta sala antigua usaba una conexión ya retirada. "
              "Se conserva para consultar transcripciones y costes.", file=sys.stderr)
        return 2
    if args.feedback:
        state.setdefault("observations", []).append(args.feedback[:1800])
        save(room, state)
    studio = args.build
    if studio:
        if not args.flutter and not (room / "workspace" / "pubspec.yaml").is_file():
            print("La sala existente no es Flutter. Inicia una nueva con -Flutter -Build.",
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
    print("Conectado al servicio Dart de IA compartida de AI-APPS.", flush=True)
    print("Las respuestas aparecen al completarse; no se transmiten palabra por palabra.", flush=True)
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
                    speak(room, state, name, character)
        if studio:
            file = room / "workspace" / "lib" / "main.dart"
            changes = git(room / "workspace", "status", "--porcelain", "--untracked-files=all", "--", "lib")
            if changes.strip():
                print("Los agentes modificaron el proyecto Flutter: " + str(file), flush=True)
            else:
                print("Los agentes no editaron Flutter en este ciclo; "
                      "la decisión queda reflejada en su conversación.", flush=True)
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
        show_spending(room_meter(state, room=room), completed=completed)
    print("Para continuar la sala, usa -Latest -Build -Android -Rounds 1.")
    print("Si prefieres descartarla, usa -Latest -Discard.")
    print("Experiencia: " + str(room))
    print("Conversación: " + str(room / "conversacion.md"))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nConversación interrumpida.")
        raise SystemExit(130)
