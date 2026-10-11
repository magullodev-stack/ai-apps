"""Workspace tools exposed through ChatDev's native function-tool manager.

No generic shell, no access to the parent repository, no Codex.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess


def _room():
    from lab import RUNS, CREATIVE_RUNS
    raw = os.environ.get("AGENTLAB_ROOM", "")
    room = Path(raw).resolve(strict=True)
    if room.parent not in {RUNS.resolve(), CREATIVE_RUNS.resolve()} or not (room / "room.json").is_file():
        raise ValueError("Sala de agentes inexistente o fuera de agent-lab/runs")
    if (room / "workspace").is_symlink():
        raise ValueError("El workspace no puede ser un enlace")
    return room


def _path(relative: str, *, writable=False):
    root = _room() / "workspace"
    if not isinstance(relative, str) or not relative or len(relative) > 220:
        raise ValueError("Indica una ruta relativa al proyecto Flutter")
    normalized = relative.replace("\\", "/")
    if normalized in (".", "./") and not writable:
        return root
    if normalized.startswith("./"):
        normalized = normalized[2:]
    # Models often use the filename shown by room_list without its lib/ prefix.
    if "/" not in normalized and normalized.endswith(".dart"):
        normalized = "lib/" + normalized
    parts = Path(normalized).parts
    if (not parts or Path(normalized).is_absolute() or
            any(p in ("", ".", "..") or ":" in p for p in parts)):
        raise ValueError("Solo se permiten rutas relativas, sin escapes ni unidades externas")
    target = root.joinpath(*parts)
    if not target.resolve(strict=False).is_relative_to(root.resolve()):
        raise ValueError("La ruta escapa del proyecto")
    for parent in (target, *target.parents):
        if parent == root:
            break
        if parent.is_symlink() or (hasattr(parent, "is_junction") and parent.is_junction()):
            raise ValueError("No se admiten enlaces ni junctions")
    if writable and (parts[0] != "lib" or len(parts) < 2 or target.suffix != ".dart"):
        raise ValueError("Solo puedes modificar archivos lib/**/*.dart")
    return target


def _announce(name: str, result: str):
    from creative_live import publish
    publish("tool", name=name, result=result[:260])
    return result


def room_list(directory: str = "lib") -> str:
    """Explora los archivos de Flutter dentro del experimento, sin salir del workspace."""
    target = _path(directory)
    if not target.is_dir():
        return "Directorio inexistente."
    items = []
    root = _room() / "workspace"
    for f in sorted(target.iterdir()):
        if f.is_symlink() or (hasattr(f, "is_junction") and f.is_junction()):
            continue
        # Always return a path the agent can paste into room_read or room_list.
        items.append(f.relative_to(root).as_posix() + ("/" if f.is_dir() else ""))
    return _announce("room_list", "\n".join(items[:70]) or "(vacío)")


def room_read(path: str) -> str:
    """Lee un archivo Dart existente, con un máximo de 16000 caracteres."""
    target = _path(path)
    if target.suffix != ".dart" or not target.is_file():
        return "Archivo Dart no encontrado; utiliza la ruta lib/main.dart o consulta room_list."
    contents = target.read_text(encoding="utf-8")[:16000]
    _announce("room_read", path + f" ({len(contents)} caracteres)")
    return contents


def room_write(path: str, content: str) -> str:
    """Crea o reescribe un archivo Dart en lib/; pasa el contenido completo."""
    target = _path(path, writable=True)
    if not isinstance(content, str) or not 15 <= len(content) <= 36000:
        return "Contenido rechazado: escribe entre 15 y 36000 caracteres."
    disallowed = re.findall(r"(?m)^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]", content)
    if any(not (imp.startswith("package:flutter/") or
                imp in ("dart:math", "dart:ui", "dart:async"))
           for imp in disallowed):
        return "Imports no permitidos. Solo Flutter SDK y dart:math/ui/async."
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")
    return _announce("room_write", "Escrito " + str(target.relative_to(_room() / "workspace")) + " (" + str(len(content)) + " caracteres).")


def room_analyze() -> str:
    """Ejecuta únicamente flutter analyze en el proyecto aislado y devuelve los errores."""
    from lab_android import runtime_env
    exe = shutil.which("flutter")
    if not exe:
        return "Flutter no está disponible en PATH."
    env = runtime_env()
    env["FLUTTER_SUPPRESS_ANALYTICS"] = "true"
    try:
        project = _room() / "workspace"
        if not (project / ".dart_tool" / "package_config.json").is_file():
            prep = subprocess.run(
                [exe, "--no-version-check", "--suppress-analytics",
                 "pub", "get", "--offline"],
                cwd=project, env=env, capture_output=True,
                text=True, encoding="utf-8", errors="replace", timeout=100,
            )
            if prep.returncode:
                return "Flutter no pudo preparar el SDK sin red:\n" + (prep.stdout + prep.stderr)[-2000:]
        p = subprocess.run(
            [exe, "--no-version-check", "--suppress-analytics",
             "analyze", "--no-pub", "lib"],
            cwd=_room() / "workspace", env=env, capture_output=True,
            text=True, encoding="utf-8", errors="replace", timeout=100,
        )
        output = "flutter analyze (exit " + str(p.returncode) + "):\n" + (p.stdout + p.stderr)[-3500:]
        _announce("room_analyze", "salida " + str(p.returncode) +
                  (": " + (p.stdout + p.stderr)[-160:] if p.returncode else ""))
        return output
    except (OSError, subprocess.TimeoutExpired) as exc:
        return "flutter analyze no se ha podido completar: " + type(exc).__name__


def room_launch() -> str:
    """Compila y abre esta aplicación en SU emulador Android aislado; nunca QuizAI."""
    if os.environ.get("AGENTLAB_ANDROID_ENABLED") != "1":
        return "Android no está autorizado para esta sesión; continúa editando código."
    from lab_android import AndroidExperiment
    state = AndroidExperiment(_room()).start()
    return _announce("room_launch", "Android: " + str(state.get("status", "desconocido")))


def room_observe() -> str:
    """Lee el estado y errores del emulador propio; captura pantalla para la persona."""
    if os.environ.get("AGENTLAB_ANDROID_ENABLED") != "1":
        return "Android no está autorizado para esta sesión."
    from lab_android import AndroidExperiment
    app = AndroidExperiment(_room())
    status = app.status()
    result = "Estado Android: " + str(status.get("status", "desconocido"))
    latest = app.folder / "logs"
    snippets = []
    for filename in ("flutter.stderr.log", "flutter.stdout.log"):
        log = latest / filename
        if log.is_file():
            data = log.read_text(encoding="utf-8", errors="replace")
            snippets.append(filename + ": " + data[-1400:])
    if snippets:
        result += "\n" + "\n".join(snippets)
    if status.get("status") == "running" and status.get("session"):
        try:
            receipt, _pixels = app.client.capture(status["session"])
            result += "\nCaptura para inspección humana: " + str(receipt.get("file", "capturada"))
            result += "\nNo puedo interpretar los píxeles con esta conexión de IA."
        except (OSError, RuntimeError, ValueError):
            result += "\nNo se ha podido obtener la captura."
    _announce("room_observe", "Android " + str(status.get("status", "desconocido")))
    return result[-3800:]
