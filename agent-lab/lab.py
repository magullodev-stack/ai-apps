"""Local ChatDev orchestration. No writes to source repositories or their refs."""

import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import traceback
import uuid
from datetime import datetime, timezone


ROOT = Path(__file__).resolve().parent
CHATDEV = ROOT / ".deps" / "chatdev"
RUNS = ROOT / "runs"


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def clean_env():
    # Git must never inherit an index, worktree or hooks from the parent session.
    return {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}


def git(workspace, *args):
    return subprocess.run(
        ["git", "-c", "core.hooksPath=NUL" if os.name == "nt" else "core.hooksPath=/dev/null",
         "-c", "core.autocrlf=false", "-C", str(workspace), *args],
        env=clean_env(), capture_output=True, check=True,
    ).stdout


def prepare_workspace(run_dir, source=None):
    workspace = run_dir / "workspace"
    workspace.mkdir()
    if source is None:
        shutil.copytree(ROOT / "examples" / "counter", workspace, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        origin = {"kind": "example", "path": "examples/counter"}
    else:
        source = Path(source).resolve(strict=True)
        source_head = git(source, "rev-parse", "HEAD").decode().strip()
        archive = run_dir / "source.tar"
        git(source, "archive", "--format=tar", f"--output={archive}", source_head)
        with tarfile.open(archive) as handle:
            # Reject links, traversal and nested .git metadata from imported code.
            for member in handle.getmembers():
                target = (workspace / member.name).resolve()
                if not target.is_relative_to(workspace) or ".git" in Path(member.name).parts:
                    raise ValueError("Unsafe source archive path")
                if not (member.isfile() or member.isdir()):
                    raise ValueError("Source snapshots must not contain links or special files")
            handle.extractall(workspace, filter="data")
        archive.unlink()
        origin = {"kind": "git-archive", "path": str(source), "commit": source_head}
    # This replaces instructions from a source snapshot only in the isolated copy.
    (workspace / "AGENTS.md").write_text(
        "# Isolated agent-lab workspace\n\n"
        "Edit and test only this workspace. Do not access or change parent repositories, "
        "Android, running services, credentials or Git refs outside this directory. "
        "Do not commit, push, install global tools, or run deployment/startup scripts. "
        "Leave changes in the working tree. Report what changed and the tests run.\n",
        encoding="utf-8",
    )
    # An independent repository: no worktree, alternates, source remote or shared refs.
    git(workspace, "init", "--initial-branch=lab")
    git(workspace, "config", "user.name", "Agent Lab")
    git(workspace, "config", "user.email", "agent-lab@localhost")
    git(workspace, "config", "core.hooksPath", "NUL" if os.name == "nt" else "/dev/null")
    # Files tracked in the source may match its own ignore rules; retain them.
    git(workspace, "add", "--force", "-A")
    git(workspace, "commit", "-m", "Isolated input snapshot")
    return workspace, origin, git(workspace, "rev-parse", "HEAD").decode().strip()


def collect_changes(run_dir, baseline, *, artifacts_dir=None):
    workspace = run_dir / "workspace"
    artifacts_dir = artifacts_dir or run_dir
    # An auxiliary index captures added/deleted/binary files and even accidental commits,
    # without staging the executor's working tree or changing its repository refs.
    env = clean_env()
    env["GIT_INDEX_FILE"] = str(artifacts_dir / "snapshot.index")
    command = ["git", "-c", "core.hooksPath=NUL" if os.name == "nt" else "core.hooksPath=/dev/null",
               "-c", "core.autocrlf=false", "-C", str(workspace)]
    subprocess.run(command + ["read-tree", baseline], env=env, capture_output=True, check=True)
    subprocess.run(command + ["add", "-A"], env=env, capture_output=True, check=True)
    patch = subprocess.run(command + ["diff", "--cached", "--binary", baseline],
                           env=env, capture_output=True, check=True).stdout
    (artifacts_dir / "changes.patch").write_bytes(patch)
    names = subprocess.run(command + ["diff", "--cached", "--name-status", baseline],
                           env=env, capture_output=True, check=True).stdout.decode("utf-8", "replace")
    (artifacts_dir / "changes.txt").write_text(names, encoding="utf-8")
    (artifacts_dir / "git-status.txt").write_bytes(git(workspace, "status", "--short"))
    tree = subprocess.run(command + ["write-tree"], env=env, capture_output=True, check=True).stdout.decode().strip()
    changes = {
        "baseline": baseline, "patch_sha256": hashlib.sha256(patch).hexdigest(),
        "has_changes": bool(patch), "name_status": names.splitlines(),
        "tree": tree,
    }
    write_json(artifacts_dir / "changes.json", changes)
    return changes


def verify_chatdev():
    expected = json.loads((ROOT / "dependencies.json").read_text(encoding="utf-8"))["chatdev"]["commit"]
    if not CHATDEV.is_dir() or git(CHATDEV, "rev-parse", "HEAD").decode().strip() != expected:
        raise RuntimeError("ChatDev missing or wrong revision. Run install.ps1.")
    if git(CHATDEV, "status", "--porcelain", "--untracked-files=no").strip():
        raise RuntimeError("ChatDev dependency has local changes; restore or reinstall it.")


def run_cycle(instruction, *, source=None, executor="codex", codex="codex", model=None,
              timeout=300, fake_mode="success"):
    if not instruction.strip():
        raise ValueError("Instruction must not be empty")
    if not 1 <= timeout <= 3600:
        raise ValueError("Timeout must be between 1 and 3600 seconds")
    verify_chatdev()
    RUNS.mkdir(exist_ok=True)
    run_id = "session_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "_" + uuid.uuid4().hex[:8]
    run_dir = RUNS / run_id
    run_dir.mkdir()
    manifest = {"run_id": run_id, "status": "started", "started_at": utc_now(),
                "executor": executor, "chatdev_commit": git(CHATDEV, "rev-parse", "HEAD").decode().strip()}
    write_json(run_dir / "manifest.json", manifest)
    baseline = None
    try:
        workspace, origin, baseline = prepare_workspace(run_dir, source)
        manifest.update({"source": origin, "baseline": baseline})
        request = {"run_id": run_id, "instruction": instruction, "executor": executor,
                   "codex": codex, "model": model, "timeout": timeout, "fake_mode": fake_mode}
        write_json(run_dir / "request.json", request)
        write_json(run_dir / "manifest.json", manifest)
        sys.path.insert(0, str(CHATDEV))
        # SDK and upstream relative logs are confined to this run, in a separate CLI process.
        previous_cwd = Path.cwd()
        try:
            os.chdir(run_dir)
            with (run_dir / "chatdev.log").open("w", encoding="utf-8") as log:
                with contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
                    import runtime.sdk as sdk
                    sdk.OUTPUT_ROOT = run_dir / "chatdev"
                    result = sdk.run_workflow(
                        ROOT / "workflows" / "codex.yaml", task_prompt=instruction,
                        session_name=run_id, variables={
                            "LAB_ROOT_LITERAL": json.dumps(str(ROOT)),
                            "LAB_RUN_LITERAL": json.dumps(str(run_dir)),
                            "LAB_PYTHON": sys.executable,
                            "LAB_CYCLE_LITERAL": '""',
                            "NODE_TIMEOUT": timeout + 60,
                        },
                    )
            text = result.final_message.text_content() if result.final_message else ""
            (run_dir / "chatdev-result.txt").write_text(text, encoding="utf-8")
            response = json.loads(text)
            adapter_response = json.loads((run_dir / "response.json").read_text(encoding="utf-8"))
            if response != adapter_response or response.get("run_id") != run_id:
                raise RuntimeError("ChatDev did not return the bridge response")
            manifest["status"] = response["status"]
        finally:
            os.chdir(previous_cwd)
    except Exception as exc:
        manifest["status"] = "failed"
        manifest["error_type"] = type(exc).__name__
        (run_dir / "error.txt").write_text(traceback.format_exc(), encoding="utf-8")
    finally:
        if baseline:
            try:
                collect_changes(run_dir, baseline)
            except Exception as exc:
                manifest["status"] = "failed"
                manifest["capture_error_type"] = type(exc).__name__
                (run_dir / "capture-error.txt").write_text(traceback.format_exc(), encoding="utf-8")
        manifest["finished_at"] = utc_now()
        write_json(run_dir / "manifest.json", manifest)
    return run_dir, manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--instruction", required=True)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--executor", choices=["codex", "fake"], default="codex")
    parser.add_argument("--codex", default="codex")
    parser.add_argument("--model")
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--fake-mode", choices=["success", "fail", "timeout", "no-final", "no-change"], default="success")
    args = parser.parse_args()
    run_dir, manifest = run_cycle(args.instruction, source=args.source, executor=args.executor,
                                  codex=args.codex, model=args.model, timeout=args.timeout,
                                  fake_mode=args.fake_mode)
    print(json.dumps({"run_dir": str(run_dir), "status": manifest["status"]}, ensure_ascii=False))
    return 0 if manifest["status"] == "completed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
