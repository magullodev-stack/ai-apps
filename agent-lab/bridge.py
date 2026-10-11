"""Trusted ChatDev Python node: invoke Codex with a prompt on stdin, return JSON."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from lab import ROOT, RUNS, collect_changes, utc_now, write_json


def executor_env(workspace):
    allowed = {"SYSTEMROOT", "WINDIR", "COMSPEC", "PATH", "PATHEXT", "TEMP", "TMP",
               "USERPROFILE", "LOCALAPPDATA", "APPDATA", "PROGRAMFILES", "PROGRAMFILES(X86)",
               "HOMEDRIVE", "HOMEPATH", "CODEX_HOME", "CODEX_API_KEY"}
    env = {k: v for k, v in os.environ.items() if k.upper() in allowed}
    env["PYTHONIOENCODING"] = "utf-8"
    env["PATH"] = str(Path(sys.executable).parent) + os.pathsep + env.get("PATH", "")
    # Do not leak ChatDev keys, repository/service secrets or Git overrides to tools.
    return env


def codex_command(request, workspace, final_path):
    if request["executor"] == "fake":
        prefix = [sys.executable, str(ROOT / "tests" / "fake_codex.py"), request["fake_mode"]]
    else:
        executable = shutil.which(request["codex"])
        if not executable:
            raise FileNotFoundError("Codex executable missing; pass -CodexPath or add codex to PATH")
        if os.name == "nt" and Path(executable).suffix.lower() != ".exe":
            raise ValueError("Use the native codex.exe; shell wrappers are not supported")
        prefix = [executable]
    command = prefix + [
        "exec", "--ignore-user-config", "--ignore-rules", "--ephemeral",
        "--sandbox", "workspace-write", "-c", 'approval_policy="never"',
        "-c", 'sandbox_workspace_write.network_access=false',
        "--cd", str(workspace), "--json", "--color", "never",
        "--output-last-message", str(final_path),
    ]
    if request.get("model"):
        command += ["--model", request["model"]]
    if os.name == "nt":
        # CLI-only setting; avoids global sandbox setup or changes to user config.
        command += ["-c", 'windows.sandbox="unelevated"']
    return command + ["-"]


def stop_process_tree(process):
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                       capture_output=True, check=False)
    else:
        import signal
        os.killpg(process.pid, signal.SIGKILL)
    if process.poll() is None:
        process.kill()
    process.wait(timeout=15)


def execute(run_dir):
    request = json.loads((run_dir / "request.json").read_text(encoding="utf-8"))
    if request["run_id"] != run_dir.name:
        raise ValueError("Run identity mismatch")
    workspace = run_dir / "workspace"
    manifest = json.loads((run_dir / "manifest.json").read_text(encoding="utf-8"))
    final_path = run_dir / "codex-final.txt"
    prompt = (
        "Work only in the isolated Git workspace selected by --cd. "
        "Implement the instruction and run the relevant local tests. "
        "Do not access parent directories, change external files, start services, "
        "use Android, commit or push. Leave all code changes for inspection.\n\n"
        + "Python interpreter for local tests: " + sys.executable + "\n\n"
        + request["instruction"]
    )
    (run_dir / "codex-prompt.txt").write_text(prompt, encoding="utf-8")
    response = {"run_id": run_dir.name, "status": "failed", "exit_code": None,
                "message": "", "executor": request["executor"], "artifacts": {
                    "workspace": "workspace", "events": "codex-events.jsonl",
                    "stderr": "codex-stderr.txt", "patch": "changes.patch"}}
    exchange_path = run_dir / "exchange.jsonl"
    with exchange_path.open("w", encoding="utf-8") as exchange:
        exchange.write(json.dumps({"at": utc_now(), "from": "chatdev", "to": "codex",
                                   "instruction": request["instruction"]}, ensure_ascii=False) + "\n")
    try:
        command = codex_command(request, workspace, final_path)
        write_json(run_dir / "command.json", command)
        with (run_dir / "codex-events.jsonl").open("wb") as stdout:
            with (run_dir / "codex-stderr.txt").open("wb") as stderr:
                options = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == "nt" else {"start_new_session": True}
                process = subprocess.Popen(command, cwd=workspace, env=executor_env(workspace),
                                           stdin=subprocess.PIPE, stdout=stdout, stderr=stderr, **options)
                try:
                    process.communicate(prompt.encode("utf-8"), timeout=request["timeout"])
                except subprocess.TimeoutExpired:
                    stop_process_tree(process)
                    response["status"] = "timed_out"
                response["exit_code"] = process.returncode
        events = [json.loads(line) for line in (run_dir / "codex-events.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
        response["message"] = final_path.read_text(encoding="utf-8") if final_path.exists() else ""
        response["thread_id"] = next((e.get("thread_id") for e in events if e.get("type") == "thread.started"), None)
        complete = any(e.get("type") == "turn.completed" for e in events)
        failed = any(e.get("type") in ("turn.failed", "error") for e in events)
        if response["status"] != "timed_out" and process.returncode == 0 and complete and not failed and response["message"].strip():
            response["status"] = "completed"
    except Exception as exc:
        response["error_type"] = type(exc).__name__
        # Detailed errors remain private run artifacts; don't dump environment or auth.
        (run_dir / "bridge-error.txt").write_text(str(exc), encoding="utf-8")
    try:
        collect_changes(run_dir, manifest["baseline"])
        response["changes"] = json.loads((run_dir / "changes.json").read_text(encoding="utf-8"))
        if response["status"] == "completed" and not response["changes"]["has_changes"]:
            response["status"] = "no_changes"
    except Exception as exc:
        response["status"] = "failed"
        response["capture_error_type"] = type(exc).__name__
    write_json(run_dir / "response.json", response)
    with exchange_path.open("a", encoding="utf-8") as exchange:
        exchange.write(json.dumps({"at": utc_now(), "from": "codex", "to": "chatdev",
                                   "response": response}, ensure_ascii=False) + "\n")
    return response


def main():
    run_dir = Path(os.environ["AGENT_LAB_RUN"]).resolve(strict=True)
    if run_dir.parent != RUNS.resolve() or run_dir.is_symlink():
        raise ValueError("Bridge requires a direct run directory inside agent-lab/runs")
    print(json.dumps(execute(run_dir), ensure_ascii=False))


if __name__ == "__main__":
    main()
