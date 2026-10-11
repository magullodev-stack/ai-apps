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
        if args.idea or args.flutter:
            raise ValueError("Al continuar una sala no repitas -Idea ni -Flutter")
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
             "model": args.model or ("gemini-2.5-flash" if args.provider == "gemini" else "gpt-4o-mini"),
             "conversation": []}
    save(room, state)
    return room, state


def save(room, state):
    (room / "room.json").write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


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
    state["conversation"].append({"name": name, "text": answer})
    save(room, state)
    print("\n" + name + ":\n" + answer + "\n", flush=True)
    match = re.search(r"(?im)^CREAR:\s*(.+)$", answer)
    return match.group(1).strip() if match else None


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--idea")
    parser.add_argument("--room")
    parser.add_argument("--provider", choices=("openai", "gemini"), default="openai")
    parser.add_argument("--model")
    parser.add_argument("--voices", type=int, choices=range(1, 4), metavar="{1,2,3}", default=3)
    parser.add_argument("--flutter", action="store_true")
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--android", action="store_true")
    parser.add_argument("--codex", default="codex")
    args = parser.parse_args()
    if args.android and not args.build:
        parser.error("--android necesita --build")
    verify_chatdev()
    room, state = open_room(args)
    key = "OPENAI_API_KEY" if state["provider"] == "openai" else "GEMINI_API_KEY"
    if not os.environ.get(key):
        print("La sala está preparada, pero falta " + key +
              ". Es una credencial API independiente de la cuota de Codex.", file=sys.stderr)
        print("Sala: " + str(room))
        return 2
    sys.path.insert(0, str(ROOT / ".deps" / "chatdev"))
    import creative_provider
    creative_provider.register()
    print("Sala: " + str(room) + "\n")
    suggestion = None
    offset = len(state["conversation"]) % len(VOICES)
    for step in range(args.voices):
        name, character = VOICES[(offset + step) % len(VOICES)]
        proposal = speak(room, state, name, character)
        if proposal:
            suggestion = proposal
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
