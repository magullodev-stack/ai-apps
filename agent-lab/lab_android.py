"""Experiment ownership and Android evidence; all execution uses the shared manager."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

import yaml

from lab import ROOT, RUNS, utc_now, write_json


def runtime_env():
    allowed = {"SYSTEMROOT", "WINDIR", "COMSPEC", "PATH", "PATHEXT", "TEMP", "TMP",
               "USERPROFILE", "LOCALAPPDATA", "APPDATA", "PROGRAMFILES", "PROGRAMFILES(X86)",
               "HOMEDRIVE", "HOMEPATH", "ANDROID_HOME", "ANDROID_SDK_ROOT", "JAVA_HOME", "FLUTTER_ROOT"}
    return {k: v for k, v in os.environ.items() if k.upper() in allowed}


def contained(path, parent):
    absolute = Path(os.path.abspath(path))
    parent = Path(os.path.abspath(parent))
    if not absolute.is_relative_to(parent):
        raise ValueError("Path must stay inside the experiment")
    for item in [absolute, *absolute.parents]:
        if item.is_symlink() or (hasattr(item, "is_junction") and item.is_junction()):
            raise ValueError("Experiment paths must not contain links or junctions")
        if item == parent:
            break
    return absolute


def project_path(run_dir, relative):
    if not isinstance(relative, str) or not relative or Path(relative).is_absolute() or ".." in Path(relative).parts:
        raise ValueError("Use a relative Flutter project path without traversal")
    return contained(run_dir / "workspace" / relative, run_dir)


def flutter_package(project):
    # This checks the registration contract; the actual runner validates/builds Dart and Android.
    pubspec = project / "pubspec.yaml"
    if not pubspec.is_file():
        return None
    for name in ("pubspec.yaml", "lib/main.dart", "android/app/src/main/AndroidManifest.xml"):
        target = contained(project / name, project)
        if not target.is_file():
            raise ValueError(f"Flutter Android project is missing {name}")
    data = yaml.safe_load(pubspec.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or (data.get("dependencies") or {}).get("flutter") != {"sdk": "flutter"}:
        raise ValueError("pubspec.yaml must declare the Flutter SDK dependency")
    gradle = next((contained(project / name, project) for name in
                   ("android/app/build.gradle.kts", "android/app/build.gradle") if (project / name).is_file()), None)
    if not gradle:
        raise ValueError("Missing Android application Gradle file")
    text = gradle.read_text(encoding="utf-8")
    matches = re.findall(r'\bapplicationId\s*(?:=\s*)?["\']([A-Za-z]\w*(?:\.[A-Za-z]\w*)+)["\']', text)
    if len(matches) != 1 or re.search(r'\b(applicationIdSuffix|productFlavors)\b', text):
        raise ValueError("Use one literal Android applicationId without flavors or suffixes")
    return matches[0]


def prepare_flutter(workspace, run_dir):
    flutter = shutil.which("flutter")
    if not flutter:
        raise FileNotFoundError("Install Flutter separately and add it to PATH")
    command = [flutter, "create", "--no-pub", "--empty", "--platforms=android", "--org", "dev.agentlab",
               "--project-name", "lab_" + hashlib.sha256(run_dir.name.encode()).hexdigest()[:8], str(workspace)]
    with (run_dir / "flutter-create.stdout.log").open("wb") as out, (run_dir / "flutter-create.stderr.log").open("wb") as err:
        subprocess.run(command, cwd=run_dir, env=runtime_env(), stdout=out, stderr=err, check=True, timeout=180)


class Manager:
    offline = False

    def __init__(self, run_dir):
        self.run_dir = run_dir
        self.logs = run_dir / "android" / "operations"
        self.logs.mkdir(parents=True, exist_ok=True)

    def call(self, action, definition=None):
        command = ["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File",
                   str(ROOT.parent / "scripts/android-session.ps1"), "-Action", action]
        fields = {"AppId": "appId", "Serial": "serial"}
        if action == "Register":
            fields.update({"Label": "label", "AvdName": "avdName", "ProjectPath": "projectPath", "PackageName": "packageName"})
        if definition:
            for flag, name in fields.items():
                command.extend(["-" + flag, definition[name]])
        number = len(list(self.logs.glob("*.json"))) + 1
        record = {"at": utc_now(), "action": action, "command": command}
        try:
            result = subprocess.run(command, cwd=self.run_dir, env=runtime_env(), capture_output=True,
                                    timeout=240, encoding="utf-8", errors="replace")
            record.update({"exit_code": result.returncode, "stdout": result.stdout, "stderr": result.stderr})
            if result.returncode:
                raise RuntimeError(f"Android manager {action} failed: {result.stderr.strip()}")
            return json.loads(result.stdout.lstrip("\ufeff"))
        finally:
            write_json(self.logs / f"{number:04d}-{action}.json", record)

    def logs_snapshot(self, definition, destination):
        directory = ROOT.parent / ".ai-apps/android/sessions" / (definition["appId"] + "@" + definition["serial"])
        destination.mkdir(parents=True, exist_ok=True)
        for name in ("state.json", "flutter.stdout.log", "flutter.stderr.log", "worker.stdout.log", "worker.stderr.log"):
            if (directory / name).is_file():
                shutil.copyfile(directory / name, destination / name)
        text = (destination / "flutter.stdout.log").read_text(encoding="utf-8", errors="replace") if (destination / "flutter.stdout.log").exists() else ""
        return text.count("Hot reload automatico completado.")


class AndroidExperiment:
    def __init__(self, run_dir, *, project=".", serial=None, avd=None, client=None, timeout=240):
        self.run_dir = contained(run_dir, RUNS)
        if self.run_dir.parent != RUNS or not (self.run_dir / "manifest.json").is_file():
            raise ValueError("Select a direct experiment directory under agent-lab/runs")
        self.file = self.run_dir / "android.json"
        self.folder = self.run_dir / "android"
        self.folder.mkdir(exist_ok=True)
        self.client = client or Manager(self.run_dir)
        self.timeout = timeout
        self.project = project
        self.serial, self.avd = serial, avd
        self.app_id = "lab-" + hashlib.sha256(self.run_dir.name.encode()).hexdigest()[:12]
        self.state = json.loads(self.file.read_text(encoding="utf-8")) if self.file.exists() else {
            "version": 1, "run_id": self.run_dir.name, "workspace": "workspace", "project": project,
            "status": "waiting_for_flutter", "session": None, "hot_reloads": 0}
        if (self.state.get("version") != 1 or self.state.get("run_id") != self.run_dir.name or
                self.state.get("workspace") != "workspace" or self.state.get("project") != project):
            raise ValueError("Android experiment association mismatch")
        project_path(self.run_dir, project)

    def save(self, event, **extra):
        self.state.update(extra)
        self.state["updated_at"] = utc_now()
        write_json(self.file, self.state)
        with (self.folder / "events.jsonl").open("a", encoding="utf-8") as log:
            log.write(json.dumps({"at": utc_now(), "event": event, **self.state}, ensure_ascii=False) + "\n")

    def owned(self, sessions):
        definition = self.state["session"]
        if not definition:
            return None
        # Never trust editable state as permission to operate on another application.
        if (definition.get("appId") != self.app_id or definition.get("kind") != "flutter" or
                definition.get("projectPath") != str(project_path(self.run_dir, self.project))):
            raise ValueError("Refusing an Android session outside this experiment")
        current = next((item for item in sessions if item["appId"] == definition["appId"] and
                        item["serial"] == definition["serial"]), None)
        if current and any(current.get(k) != v for k, v in definition.items()):
            raise ValueError("Shared Android registration changed; refusing to control it")
        return current

    def start(self):
        try:
            project = project_path(self.run_dir, self.project)
            package = flutter_package(project)
            if not package:
                self.save("pending", status="waiting_for_flutter")
                return self.state.copy()
            sessions = self.client.call("List")
            current = self.owned(sessions)
            if not self.state["session"]:
                # Recover a registration made immediately before an interrupted state write.
                prior = next((s for s in sessions if s["appId"] == self.app_id), None)
                used = {s["serial"] for s in sessions}
                available = next((f"emulator-{p}" for p in range(5556, 5683, 2) if f"emulator-{p}" not in used), None)
                definition = {"appId": self.app_id, "label": "Lab " + self.run_dir.name[-8:], "kind": "flutter",
                              "serial": self.serial or (prior["serial"] if prior else available),
                              "avdName": self.avd or (prior["avdName"] if prior else "AI_APPS_Lab_" + self.app_id[4:]),
                              "projectPath": str(project), "packageName": package}
                if not definition["serial"]:
                    raise RuntimeError("No available emulator console port in the shared manager range")
                self.save("association", session=definition, status="registering")
                self.owned(sessions)
            definition = self.state["session"]
            if package != definition["packageName"]:
                raise ValueError("Android applicationId changed; detach the old session before registering again")
            self.client.call("Register", definition)
            self.client.call("Start", definition)
            self.save("start_requested", status="starting")
            deadline = time.monotonic() + self.timeout
            while True:
                current = self.owned(self.client.call("List"))
                if current and current["active"] and current["status"] == "running":
                    self.save("running", status="running", shared_state=current)
                    return self.state.copy()
                if current and current["status"] == "failed":
                    raise RuntimeError("Shared Flutter runner failed; inspect android/logs")
                if time.monotonic() >= deadline:
                    raise TimeoutError("Flutter startup timed out; session is retained for status/stop")
                time.sleep(1)
        except Exception as error:
            self.save("start_failed", status="failed", error=str(error))
            self.client.logs_snapshot(self.state["session"], self.folder / "logs") if self.state["session"] else None
            raise

    def status(self, *, destination=None):
        current = self.owned(self.client.call("List"))
        status = "running" if current and current["active"] else current["status"] if current else "unregistered"
        self.save("status", status=status, shared_state=current)
        count = self.client.logs_snapshot(self.state["session"], destination or self.folder / "logs") if self.state["session"] else 0
        self.save("logs", hot_reloads=count)
        return self.state.copy()

    def after_cycle(self, cycle, changes):
        try:
            return self._after_cycle(cycle, changes)
        except Exception:
            if self.state["session"]:
                self.client.logs_snapshot(self.state["session"], cycle / "android/logs")
            write_json(cycle / "android.json", self.state)
            raise

    def _after_cycle(self, cycle, changes):
        was_running = self.state["status"] == "running"
        before = self.state["hot_reloads"]
        self.start()
        result = self.status(destination=cycle / "android" / "logs") if self.state["session"] else self.state.copy()
        dart_changed = any(name.split("\t")[-1].endswith(".dart") for name in changes["name_status"])
        if was_running and dart_changed:
            deadline = time.monotonic() + min(self.timeout, 45)
            while result["hot_reloads"] <= before and time.monotonic() < deadline:
                if result["status"] != "running":
                    raise RuntimeError("Flutter stopped during the code iteration")
                time.sleep(1)
                result = self.status(destination=cycle / "android" / "logs")
            if result["hot_reloads"] <= before:
                self.save("reload_failed", status="failed", error="No successful Hot Reload after Dart changes")
                write_json(cycle / "android.json", self.state)
                raise RuntimeError(self.state["error"])
            result["reload_confirmed"] = True
        write_json(cycle / "android.json", result)
        return result

    def stop(self, *, detach=False):
        current = self.owned(self.client.call("List"))
        if current:
            self.client.call("Stop", self.state["session"])
            remaining = self.owned(self.client.call("List"))
            if remaining and (remaining.get("active") or remaining.get("appPid") or remaining.get("status") in ("starting", "stopping")):
                self.save("stop_failed", status="failed", error="Android application is still running after Stop")
                raise RuntimeError(self.state["error"])
            if detach:
                self.client.call("Unregister", self.state["session"])
        if self.state["session"]:
            self.client.logs_snapshot(self.state["session"], self.folder / "logs")
        if detach:
            self.state["last_session"] = self.state["session"] or self.state.get("last_session")
            self.state["session"] = None
        self.save("detached" if detach else "stopped", status="detached" if detach else "stopped")
        return self.state.copy()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--action", choices=("start", "status", "stop", "detach", "detach-all"), required=True)
    parser.add_argument("--run", type=Path)
    parser.add_argument("--project")
    parser.add_argument("--serial")
    parser.add_argument("--avd")
    args = parser.parse_args()
    runs = list(RUNS.glob("*/android.json")) if args.action == "detach-all" else [args.run / "android.json"] if args.run else []
    if not runs and args.action != "detach-all":
        parser.error("Specify --run")
    for file in runs:
        stored = json.loads(file.read_text(encoding="utf-8")) if file.exists() else {}
        experiment = AndroidExperiment(file.parent, project=args.project or stored.get("project", "."), serial=args.serial, avd=args.avd)
        result = experiment.start() if args.action == "start" else experiment.status() if args.action == "status" else experiment.stop(detach=args.action in ("detach", "detach-all"))
        print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
