"""Bounded autonomous ChatDev decisions and Codex iterations over one workspace."""

import argparse
import contextlib
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sys
import traceback
import uuid

from lab import ROOT, CHATDEV, RUNS, collect_changes, git, prepare_workspace, utc_now, verify_chatdev, write_json


def load_settings(path):
    settings = json.loads(path.read_text(encoding="utf-8"))
    if set(settings) != {"provider", "model", "timeout_seconds", "max_iterations"}:
        raise ValueError("Config accepts only provider, model, timeout_seconds and max_iterations; no credentials")
    if settings["provider"] != "lab_codex" or not isinstance(settings["model"], str) or not settings["model"].strip():
        raise ValueError("Select lab_codex and a nonempty model name (or default)")
    for name, low, high in (("max_iterations", 2, 10), ("timeout_seconds", 1, 3600)):
        if type(settings[name]) is not int or not low <= settings[name] <= high:
            raise ValueError(f"{name} must be an integer between {low} and {high}")
    return settings


def workspace_context(workspace):
    names = set(git(workspace, "ls-files", "-z").decode("utf-8").split("\0"))
    names.update(git(workspace, "ls-files", "--others", "--exclude-standard", "-z").decode("utf-8").split("\0"))
    files, budget = [], 80000
    for name in sorted(names - {""}):
        if len(files) >= 80:
            files.append({"omitted": "File count limit reached"})
            break
        path = workspace / name
        if path.is_symlink() or not path.resolve().is_relative_to(workspace.resolve()):
            raise ValueError("Workspace contains an external link")
        if not path.is_file():
            continue
        entry = {"path": name, "size": path.stat().st_size}
        if entry["size"] <= min(24000, budget) and not name.startswith((".env", ".secrets/", ".codex/")):
            try:
                content = path.read_text(encoding="utf-8")
                if "\0" not in content:
                    entry["content"] = content
                    budget -= entry["size"]
            except UnicodeError:
                pass
        if "content" not in entry:
            entry["omitted"] = "Binary, private or context size limit"
        files.append(entry)
    return files


def decision_from_text(text, *, reviewing):
    import jsonschema
    decision = json.loads(text)
    schema = json.loads((ROOT / "prompts/decision.schema.json").read_text(encoding="utf-8"))
    jsonschema.validate(decision, schema)
    if not decision["summary"].strip():
        raise ValueError("Decision summary must contain design or evaluation evidence")
    if decision["action"] == "execute" and not decision["instruction"].strip():
        raise ValueError("An execution decision requires a new instruction")
    if decision["action"] == "finish" and (decision["instruction"] or decision["assessment"] != "accepted"):
        raise ValueError("A finish decision must accept the result and have no instruction")
    if (reviewing and decision["assessment"] == "pending") or (not reviewing and decision["assessment"] != "pending"):
        raise ValueError("Assessment does not match the decision phase")
    return decision


def workflow(run_dir, artifacts, yaml_name, prompt, variables, session_name):
    previous_cwd = Path.cwd()
    try:
        os.chdir(run_dir)
        with (artifacts / "chatdev.log").open("w", encoding="utf-8") as log:
            with contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
                import runtime.sdk as sdk
                sdk.OUTPUT_ROOT = artifacts / "chatdev"
                result = sdk.run_workflow(ROOT / "workflows" / yaml_name, task_prompt=prompt,
                                          variables=variables, session_name=session_name)
        text = result.final_message.text_content() if result.final_message else ""
        (artifacts / "chatdev-result.txt").write_text(text, encoding="utf-8")
        return text
    finally:
        os.chdir(previous_cwd)


def decide(run_dir, manifest, history, settings, codex, offline):
    artifacts = run_dir / "decisions" / f"{len(history):03d}"
    artifacts.mkdir(parents=True)
    before = collect_changes(run_dir, manifest["baseline"], artifacts_dir=artifacts)["tree"]
    payload = {"initial_instruction": manifest["initial_instruction"], "minimum_iterations": 2,
               "max_iterations": settings["max_iterations"], "completed_iterations": len(history),
               "consecutive_successes": manifest["consecutive_successes"],
               "remaining_iterations": settings["max_iterations"] - len(history),
               "android": manifest.get("android"), "history": history, "workspace_files": workspace_context(run_dir / "workspace")}
    write_json(artifacts / "input.json", payload)
    text = workflow(run_dir, artifacts, "deliberate.yaml", json.dumps(payload, ensure_ascii=False), {
        "PLANNER_PROVIDER": "lab_offline" if offline else settings["provider"],
        "PLANNER_MODEL": settings["model"], "PLANNER_EXECUTABLE": codex,
        "PLANNER_WORKSPACE": str(run_dir / "workspace"), "PLANNER_ARTIFACTS": str(artifacts),
        "PLANNER_TIMEOUT": settings["timeout_seconds"],
    }, manifest["run_id"] + f"_decision_{len(history):03d}")
    after = collect_changes(run_dir, manifest["baseline"], artifacts_dir=artifacts)["tree"]
    if before != after:
        raise RuntimeError("Deliberating agent changed the workspace")
    decision = decision_from_text(text, reviewing=bool(history))
    write_json(artifacts / "decision.json", decision)
    with (run_dir / "decisions.jsonl").open("a", encoding="utf-8") as log:
        log.write(json.dumps({"at": utc_now(), "after_iteration": len(history), **decision}, ensure_ascii=False) + "\n")
    return decision


def run_autonomous(instruction, *, source=None, codex="codex", model=None, timeout=300,
                   offline=False, config=None, fake_mode="success", flutter=False, android=None, android_client=None):
    if not instruction.strip() or not 1 <= timeout <= 3600:
        raise ValueError("Provide a nonempty instruction and a timeout between 1 and 3600")
    if offline and (flutter or (android is not None and not getattr(android_client, "offline", False))):
        raise ValueError("Offline mode never starts Flutter or Android; supply an offline test adapter")
    settings = load_settings(config or ROOT / "config/deliberation.json")
    verify_chatdev()
    RUNS.mkdir(exist_ok=True)
    run_id = "session_auto_" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "_" + uuid.uuid4().hex[:8]
    run_dir = RUNS / run_id
    run_dir.mkdir()
    manifest = {"run_id": run_id, "status": "started", "started_at": utc_now(),
                "initial_instruction": instruction, "settings": settings, "offline": offline,
                "iterations": [], "consecutive_successes": 0,
                "chatdev_commit": git(CHATDEV, "rev-parse", "HEAD").decode().strip()}
    write_json(run_dir / "manifest.json", manifest)
    baseline = None
    android_session = None
    try:
        _, origin, baseline = prepare_workspace(run_dir, source, flutter=flutter)
        manifest.update({"source": origin, "baseline": baseline})
        write_json(run_dir / "manifest.json", manifest)
        if android is not None:
            from lab_android import AndroidExperiment
            android_session = AndroidExperiment(run_dir, client=android_client, **android)
            manifest["android"] = android_session.state
        sys.path.insert(0, str(CHATDEV))
        import runtime.sdk
        import planner_provider
        planner_provider.register()
        history = []
        previous_tree = git(run_dir / "workspace", "rev-parse", baseline + "^{tree}").decode().strip()
        decision = decide(run_dir, manifest, history, settings, codex, offline)
        for iteration in range(1, settings["max_iterations"] + 1):
            if decision["action"] != "execute":
                manifest["status"] = "stopped_early"
                break
            cycle = run_dir / "cycles" / f"{iteration:03d}"
            cycle.mkdir(parents=True)
            write_json(cycle / "decision.json", decision)
            request = {"run_id": run_id, "iteration": iteration, "instruction": decision["instruction"],
                       "executor": "fake" if offline else "codex", "codex": codex,
                       "model": model, "timeout": timeout, "fake_mode": fake_mode}
            write_json(cycle / "request.json", request)
            cycle_manifest = {"run_id": run_id, "iteration": iteration, "status": "started", "baseline": previous_tree}
            write_json(cycle / "manifest.json", cycle_manifest)
            text = workflow(run_dir, cycle, "codex.yaml", decision["instruction"], {
                "LAB_ROOT_LITERAL": json.dumps(str(ROOT)), "LAB_RUN_LITERAL": json.dumps(str(run_dir)),
                "LAB_CYCLE_LITERAL": json.dumps(cycle.name), "LAB_PYTHON": sys.executable,
                "NODE_TIMEOUT": timeout + 60,
            }, run_id + f"_cycle_{iteration:03d}")
            response = json.loads(text)
            if response != json.loads((cycle / "response.json").read_text(encoding="utf-8")) or response["run_id"] != run_id:
                raise RuntimeError("ChatDev did not receive this iteration's executor result")
            cycle_manifest["status"] = response["status"]
            cycle_manifest["finished_at"] = utc_now()
            write_json(cycle / "manifest.json", cycle_manifest)
            previous_tree = response["changes"]["tree"]
            git(run_dir / "workspace", "archive", "--format=tar", f"--output={cycle / 'workspace.tar'}", previous_tree)
            patch = (cycle / "changes.patch").read_text(encoding="utf-8", errors="replace")
            android_evidence = None
            if android_session:
                android_evidence = android_session.after_cycle(cycle, response["changes"])
                manifest["android"] = android_evidence
            evidence = {"android": android_evidence, "iteration": iteration, "decision": decision, "response": response,
                        "patch": patch[:64000], "patch_truncated": len(patch) > 64000}
            history.append(evidence)
            manifest["iterations"].append({"iteration": iteration, "status": response["status"],
                                           "path": f"cycles/{cycle.name}", "tree": previous_tree})
            manifest["consecutive_successes"] = manifest["consecutive_successes"] + 1 if response["status"] == "completed" else 0
            write_json(run_dir / "manifest.json", manifest)
            # The native ChatDev agent evaluates every result, including the final cycle.
            decision = decide(run_dir, manifest, history, settings, codex, offline)
            write_json(cycle / "evaluation.json", decision)
            if decision["action"] == "finish":
                manifest["status"] = "completed" if manifest["consecutive_successes"] >= 2 else "stopped_early"
                break
        else:
            manifest["status"] = "iteration_limit"
        if android_session and manifest["status"] == "completed" and manifest["android"]["status"] != "running":
            manifest["status"] = "android_not_ready"
        write_json(run_dir / "final-decision.json", decision)
    except Exception as exc:
        manifest["status"] = "failed"
        manifest["error_type"] = type(exc).__name__
        (run_dir / "error.txt").write_text(traceback.format_exc(), encoding="utf-8")
    finally:
        # A Python-node or SDK failure must not leave a cycle marked active forever.
        for path in (run_dir / "cycles").glob("*/manifest.json"):
            cycle_state = json.loads(path.read_text(encoding="utf-8"))
            if cycle_state["status"] == "started":
                cycle_state.update({"status": "failed", "finished_at": utc_now()})
                write_json(path, cycle_state)
        if baseline:
            try:
                collect_changes(run_dir, baseline)
            except Exception as exc:
                manifest.update({"status": "failed", "capture_error_type": type(exc).__name__})
        if android_session:
            manifest["android"] = android_session.state.copy()
        manifest["finished_at"] = utc_now()
        write_json(run_dir / "manifest.json", manifest)
    return run_dir, manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--instruction", required=True)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--codex", default="codex")
    parser.add_argument("--model")
    parser.add_argument("--config", type=Path)
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--flutter", action="store_true", help="Prepare an isolated Flutter Android template")
    parser.add_argument("--android", action="store_true", help="Start a valid Flutter app between iterations")
    parser.add_argument("--android-project", default=".")
    parser.add_argument("--android-serial")
    parser.add_argument("--android-avd")
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--fake-mode", choices=["success", "fail", "timeout", "no-final", "no-change"], default="success")
    args = parser.parse_args()
    android = {"project": args.android_project, "serial": args.android_serial, "avd": args.android_avd} if args.android else None
    run_dir, manifest = run_autonomous(args.instruction, source=args.source, codex=args.codex,
                                       model=args.model, config=args.config, timeout=args.timeout,
                                       offline=args.offline, fake_mode=args.fake_mode, flutter=args.flutter, android=android)
    print(json.dumps({"run_dir": str(run_dir), "status": manifest["status"],
                      "iterations": len(manifest["iterations"])}, ensure_ascii=False))
    return 0 if manifest["status"] == "completed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
