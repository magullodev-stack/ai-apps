"""Locate the native Codex CLI, including the binary bundled with VS Code."""
import os
from pathlib import Path
import platform
import shutil
import subprocess


def extension_directories():
    home = Path(os.environ.get("USERPROFILE") or Path.home())
    candidates = []
    custom = os.environ.get("VSCODE_EXTENSIONS")
    if custom:
        candidates.append(Path(custom).expanduser())
    candidates.extend(home / name / "extensions" for name in (
        ".vscode", ".vscode-insiders", ".vscode-oss", ".cursor"))
    unique = []
    for path in candidates:
        if path not in unique and path.is_dir():
            unique.append(path)
    return unique


def find_codex(executable="codex", *, roots=None):
    """Use PATH/explicit CLI, then find the bundled native codex.exe.

    Only searches known extension directories; never walks the user's files
    or installs anything. Does not depend on the VS Code webview starting.
    """
    if not isinstance(executable, str) or not executable.strip():
        return None
    direct = Path(executable).expanduser()
    if direct.is_file() and direct.suffix.lower() == ".exe":
        return str(direct.resolve())
    for candidate in (executable, "codex.exe") if executable == "codex" else (executable,):
        result = shutil.which(candidate)
        if result and (os.name != "nt" or Path(result).suffix.lower() == ".exe"):
            return str(Path(result).resolve())
    if executable not in ("codex", "codex.exe"):
        return None
    machine = platform.machine().lower()
    arch = ("arm64" if "arm" in machine or "aarch64" in machine else "x86_64")
    found = []
    for directory in roots if roots is not None else extension_directories():
        base = Path(directory)
        if not base.is_dir():
            continue
        for pattern in ("openai.chatgpt-*", "openai.codex-*"):
            for extension in base.glob(pattern):
                if not extension.is_dir() or extension.is_symlink():
                    continue
                binaries = [
                    extension / "bin" / f"windows-{arch}" / "codex.exe",
                    extension / "bin" / "windows-x64" / "codex.exe",
                    extension / "bin" / "windows-x86_64" / "codex.exe",
                    extension / "bin" / "windows-arm64" / "codex.exe",
                    extension / "bin" / "codex.exe",
                ]
                binaries.extend(extension.glob("bin/*/codex.exe"))
                for binary in binaries:
                    if binary.is_file() and not binary.is_symlink():
                        priority = (arch in str(binary.parent).lower())
                        found.append((int(priority), extension.stat().st_mtime, binary))
    if not found:
        return None
    found.sort(key=lambda x: (x[0], x[1]), reverse=True)
    return str(found[0][2].resolve())


def check_codex(executable):
    """No model calls or credentials; confirms that the binary can start."""
    try:
        result = subprocess.run([executable, "--version"], capture_output=True,
                                text=True, errors="replace", timeout=12)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return f"Codex se encontró, pero no pudo iniciarse: {type(exc).__name__}"
    if result.returncode:
        return "Codex existe, pero '--version' falló: " + (result.stderr or result.stdout)[-350:]
    return None
