"""One autonomous Codex programmer, iterating over the same isolated Flutter app."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid
from zipfile import ZipFile

from bridge import invoke_codex
from lab import CREATIVE_RUNS, RUNS, prepare_workspace


def save(room, state):
    (room / "room.json").write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def read_zip(filename):
    path = Path(filename).expanduser().resolve(strict=True)
    if path.stat().st_size > 5 * 1024 * 1024:
        raise ValueError("La semilla supera 5 MiB")
    with ZipFile(path) as archive:
        entries = archive.infolist()
        if len(entries) != 2 or {x.filename for x in entries} != {"imagen.png", "texto.md"}:
            raise ValueError("El ZIP debe contener solamente imagen.png y texto.md")
        if any(x.file_size > (3 * 1024 * 1024 if x.filename == "imagen.png" else 30000)
               for x in entries):
            raise ValueError("Semilla demasiado grande")
        image = archive.read("imagen.png")
        text = archive.read("texto.md").decode("utf-8")
    return image, text


def create_room(args):
    text = args.idea or ""
    image = None
    if args.seed_zip:
        if text or args.text_file or args.image:
            raise ValueError("El ZIP ya contiene texto e imagen")
        image, text = read_zip(args.seed_zip)
    else:
        if args.text_file:
            if text:
                raise ValueError("Elige Idea o TextFile")
            source = Path(args.text_file).resolve(strict=True)
            if source.stat().st_size > 30000:
                raise ValueError("Texto demasiado grande")
            text = source.read_text(encoding="utf-8")
        if args.image:
            source = Path(args.image).resolve(strict=True)
            if source.suffix.lower() != ".png" or source.stat().st_size > 3 * 1024 * 1024:
                raise ValueError("Se requiere PNG menor de 3 MiB")
            image = source.read_bytes()
    if not text.strip() and image is None:
        raise ValueError("Falta una imagen o texto original")
    if image is not None:
        from vision import png_metadata
        metadata = png_metadata(image)
    CREATIVE_RUNS.mkdir(parents=True, exist_ok=True)
    room = CREATIVE_RUNS / ("creative_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
                            + "_" + uuid.uuid4().hex[:6])
    room.mkdir()
    (room / "manifest.json").write_text(json.dumps({"run_id": room.name,
        "kind": "creative", "workspace": "workspace"}), encoding="utf-8")
    prepare_workspace(room, flutter=True)
    state = {"engine": "codex_loop", "idea": text, "cycles": [], "model": args.model,
             "feedback": ""}
    if image is not None:
        (room / "seed.png").write_bytes(image)
        state["seed_image"] = {"file": "seed.png", **metadata}
    save(room, state)
    return room, state


def rooms():
    found = []
    for parent in (RUNS, CREATIVE_RUNS):
        if parent.is_dir():
            found.extend(p for p in parent.glob("creative_*")
                         if p.is_dir() and (p / "room.json").is_file())
    return sorted(found, key=lambda p: p.name, reverse=True)


def existing_room(path=None):
    choices = [Path(path).resolve(strict=True)] if path else [
        p for p in rooms() if json.loads((p / "room.json").read_text(encoding="utf-8")
                                        ).get("engine") == "codex_loop"]
    if not choices:
        raise ValueError("Todavía no hay salas del nuevo modo continuo")
    room = choices[0]
    if room.parent not in (RUNS.resolve(), CREATIVE_RUNS.resolve()) or room.is_symlink() or (
            not (room / "room.json").is_file()):
        raise ValueError("Sala fuera del laboratorio")
    return room, json.loads((room / "room.json").read_text(encoding="utf-8"))


def original_image(room, state):
    if not state.get("seed_image"):
        return []
    meta = state["seed_image"]
    if meta["file"] != "seed.png":
        raise ValueError("Identidad de imagen inválida")
    path = room / "seed.png"
    if hashlib.sha256(path.read_bytes()).hexdigest() != meta["sha256"]:
        raise ValueError("La imagen original fue alterada")
    return [path]


def snapshot(workspace):
    """Capture only sources and resources; SDK/build caches are not development changes."""
    excluded = {".git", ".dart_tool", ".gradle", ".idea", "build",
                ".pub-cache", ".symlinks", "Pods"}
    result = {}
    for current, dirs, files in os.walk(workspace):
        dirs[:] = sorted(x for x in dirs if x not in excluded
                         and not (Path(current) / x).is_symlink())
        for name in sorted(files):
            p = Path(current) / name
            if p.is_symlink() or not p.is_file() or p.stat().st_size > 25 * 1024 * 1024:
                continue
            result[p.relative_to(workspace).as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
    return result


def changed(before, after):
    return sorted(k for k in before.keys() | after.keys() if before.get(k) != after.get(k))


def validate(workspace, folder, filenames):
    """Host, not the agent sandbox, maintains Flutter SDK and downloads packages."""
    from lab_android import runtime_env
    flutter = shutil.which("flutter") or shutil.which("flutter.bat")
    if not flutter:
        return "Flutter no disponible"
    commands = []
    if "pubspec.yaml" in filenames or not (workspace / ".dart_tool" / "package_config.json").is_file():
        commands.append(("pub get", [flutter, "pub", "get"]))
    if any(x.startswith(("lib/", "test/")) and x.endswith(".dart") for x in filenames):
        commands.append(("analyze", [flutter, "analyze", "--no-pub", "lib"]))
    if any(x.startswith("test/") and x.endswith(".dart") for x in filenames):
        commands.append(("test", [flutter, "test", "--no-pub"]))
    env = runtime_env()
    env["FLUTTER_SUPPRESS_ANALYTICS"] = "true"
    reports = []
    for label, command in commands:
        try:
            p = subprocess.run(command, cwd=workspace, env=env, capture_output=True,
                               timeout=240, text=True, errors="replace")
            reports.append({"check": label, "exit": p.returncode,
                            "output": (p.stdout + p.stderr)[-2000:]})
            if p.returncode:
                break
        except (OSError, subprocess.TimeoutExpired) as exc:
            reports.append({"check": label, "error": type(exc).__name__})
            break
    (folder / "flutter-checks.json").write_text(json.dumps(reports, ensure_ascii=False, indent=2),
                                                encoding="utf-8")
    return "\n".join(r["check"] + ": " + (r.get("output", r.get("error", "")))
                     for r in reports)[-2200:]


def build_prompt(state):
    recent = state["cycles"][-2:]
    progress = "\n".join("Iteración " + str(x["number"]) + ": " + x.get("message", "")[-700:]
                         for x in recent)
    diagnostic = recent[-1].get("diagnostic", "")[-1600:] if recent else ""
    return (
        "Desarrolla una aplicación Flutter real a partir de la imagen original adjunta "
        "(cuando exista) y del siguiente texto original de la persona:\n\n"
        + state["idea"] + "\n\n"
        "Eres un único agente de programación que continúa trabajando sobre el mismo proyecto. "
        "Inspecciona lo implementado, descubre qué necesita el producto y decide el siguiente avance. "
        "Escribe y modifica código de verdad en esta iteración. Puedes cambiar cualquier archivo "
        "del proyecto, incorporar dependencias y reorganizar libremente su arquitectura. "
        "Si cambias pubspec.yaml, el anfitrión resolverá las dependencias mediante flutter pub get. "
        "Al acabar comunica qué has implementado y qué queda por construir. "
        "Una compilación correcta no significa que el producto esté terminado.\n"
        + ("\nTrabajo reciente:\n" + progress if progress else "")
        + ("\nComprobaciones posteriores al último cambio:\n" + diagnostic if diagnostic else "")
        + ("\nComentario de la persona:\n" + state["feedback"] if state.get("feedback") else "")
    )


def cycle(room, state, number, codex, timeout):
    workspace = room / "workspace"
    folder = room / "cycles" / f"{number:03d}"
    folder.mkdir(parents=True, exist_ok=False)
    before = snapshot(workspace)
    request = {"executor": "codex", "codex": codex, "model": state["model"],
               "timeout": timeout, "network": True}
    response = invoke_codex(request, workspace, folder, build_prompt(state),
                            images=original_image(room, state))
    filenames = changed(before, snapshot(workspace))
    diagnostic = validate(workspace, folder, filenames) if filenames else ""
    result = {"number": number, "status": response["status"], "changed": filenames,
              "message": response.get("message", "")[-3000:], "diagnostic": diagnostic,
              "usage": response.get("usage", {})}
    state["cycles"].append(result)
    state["feedback"] = ""
    save(room, state)
    with (room / "conversacion.md").open("a", encoding="utf-8") as f:
        f.write("\n## Ciclo " + str(number) + "\n\n" + result["message"] +
                "\n\nArchivos modificados: " + (", ".join(filenames) or "ninguno") + "\n")
    print(f"Codex: {result['status']} · {len(filenames)} archivos modificados", flush=True)
    for filename in filenames[:25]:
        print("  " + filename, flush=True)
    if result["message"]:
        print(result["message"][-1500:], flush=True)
    if diagnostic:
        print("Flutter: " + diagnostic[-900:], flush=True)
    return result


def discard(room):
    from lab_android import AndroidExperiment
    app = AndroidExperiment(room)
    if app.state["session"]:
        app.owned(app.client.call("List"))
        app.client.call("Discard", app.state["session"])
    else:
        if any(item["appId"] == app.app_id for item in app.client.call("List")):
            raise RuntimeError("La sala todavía tiene una sesión Android registrada")
        shutil.rmtree(room)
    print("Experiencia y recursos descartados:", room.name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ("idea", "text-file", "image", "seed-zip", "room", "model", "feedback"):
        parser.add_argument("--" + field)
    parser.add_argument("--codex", default="codex")
    parser.add_argument("--rounds", type=int, default=10)
    parser.add_argument("--timeout", type=int, default=900)
    for flag in ("latest", "list-rooms", "transcript", "discard", "cost-only",
                 "probe", "flutter", "build", "android"):
        parser.add_argument("--" + flag, action="store_true")
    args = parser.parse_args()
    if not (1 <= args.rounds <= 100 and 60 <= args.timeout <= 3600):
        parser.error("Máximo de 1 a 100 ciclos; tiempo por ciclo de 60 a 3600 segundos")
    if args.list_rooms:
        for p in rooms():
            state = json.loads((p / "room.json").read_text(encoding="utf-8"))
            print(p.name, state.get("engine", "antiguo"),
                  len(state.get("cycles", [])), "ciclos")
        return 0
    if args.probe:
        print("Codex:", shutil.which(args.codex) or "No encontrado")
        return 0 if shutil.which(args.codex) else 2
    continuing = bool(args.latest or args.room)
    if args.latest and args.room:
        parser.error("Escoge -Latest o -Room")
    if continuing and any((args.idea, args.text_file, args.image, args.seed_zip)):
        parser.error("No repitas la semilla al continuar")
    if continuing:
        room, state = existing_room(args.room)
    elif args.discard or args.transcript or args.cost_only:
        parser.error("Selecciona -Latest o -Room")
    else:
        if not (args.flutter and args.build):
            parser.error("Una sala nueva necesita -Flutter -Build")
        room, state = create_room(args)
    if args.discard:
        discard(room)
        return 0
    if args.transcript:
        p = room / "conversacion.md"
        print(p.read_text(encoding="utf-8") if p.is_file() else "Sin ciclos")
        return 0
    if args.cost_only:
        print("Codex CLI no proporciona una tarifa API comprobable; ciclos:",
              len(state.get("cycles", [])))
        return 0
    if state.get("engine") != "codex_loop":
        raise ValueError("Esta sala pertenece al laboratorio anterior de tres agentes")
    if not args.build:
        parser.error("Utiliza -Build para continuar")
    if not shutil.which(args.codex):
        raise FileNotFoundError("No se encuentra codex.exe en PATH; indica -CodexPath")
    if args.model:
        state["model"] = args.model
    if args.feedback:
        state["feedback"] = args.feedback[:1200]
    save(room, state)
    print("Sala:", room, "\nUn agente Codex; máximo", args.rounds, "ciclos", flush=True)
    idle = 0
    for _ in range(args.rounds):
        n = len(state["cycles"]) + 1
        print(f"\n────────── CICLO {n} ──────────", flush=True)
        result = cycle(room, state, n, args.codex, args.timeout)
        if result["status"] != "completed":
            print("Ciclo interrumpido; proyecto conservado para retomar.")
            return 1
        idle = idle + 1 if not result["changed"] else 0
        if idle >= 2:
            print("Dos ciclos consecutivos sin editar: se detiene el gasto improductivo.")
            break
    if args.android:
        from lab_android import AndroidExperiment
        try:
            status = AndroidExperiment(room).start()
            print("Android:", status.get("status", "desconocido"))
        except (RuntimeError, OSError, ValueError) as exc:
            print("Android no pudo abrirse, proyecto conservado:", exc, file=sys.stderr)
    print("Proyecto:", room / "workspace")
    print("Continúa con -Latest -Build -Android -Rounds 10")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Interrumpido; se conservan el código y los avances.")
        raise SystemExit(130)
