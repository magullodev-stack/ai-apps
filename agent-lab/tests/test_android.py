import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest
from unittest.mock import patch
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lab import ROOT, RUNS, git, prepare_workspace, write_json
from lab_android import AndroidExperiment, Manager, flutter_package, runtime_env
from deliberation import run_autonomous


class OfflineManager:
    offline = True

    def __init__(self):
        self.calls, self.sessions = [], [{"appId": "quizai", "serial": "emulator-5554", "active": True}]
        self.reloads, self.failure = 0, False

    def call(self, action, definition=None):
        self.calls.append((action, copy.deepcopy(definition)))
        if action == "List":
            return copy.deepcopy(self.sessions)
        if action == "Register":
            existing = next((s for s in self.sessions if s["appId"] == definition["appId"]), None)
            if not existing:
                self.sessions.append({**definition, "active": False, "status": "device_ready"})
        else:
            current = next(s for s in self.sessions if s["appId"] == definition["appId"])
            if action == "Start":
                current.update(active=not self.failure, status="failed" if self.failure else "running")
            if action == "Stop":
                current.update(active=False, status="device_ready")
            if action == "Unregister":
                self.sessions.remove(current)
        return definition

    def logs_snapshot(self, definition, destination):
        destination.mkdir(parents=True, exist_ok=True)
        (destination / "flutter.stdout.log").write_text("Hot reload automatico completado.\n" * self.reloads)
        return self.reloads

    def validate(self, project, destination):
        destination.mkdir(parents=True, exist_ok=True)
        return {"passed": True, "checks": [{"name": "offline", "exit_code": 0}]}


def add_flutter(workspace):
    for name, text in {
        "pubspec.yaml": "name: offline_app\ndependencies:\n  flutter:\n    sdk: flutter\n",
        "lib/main.dart": "void main() {}\n",
        "android/app/src/main/AndroidManifest.xml": "<manifest/>\n",
        "android/app/build.gradle.kts": 'android { defaultConfig { applicationId = "dev.agentlab.offline" } }\n',
    }.items():
        path = workspace / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")


class AndroidTest(unittest.TestCase):
    def experiment(self):
        RUNS.mkdir(exist_ok=True)
        run = RUNS / ("android_offline_" + uuid.uuid4().hex[:8])
        run.mkdir()
        write_json(run / "manifest.json", {"run_id": run.name, "status": "completed"})
        workspace, _, _ = prepare_workspace(run)
        add_flutter(workspace)
        return run, OfflineManager()

    def test_registration_recovery_stop_and_detach_preserve_primary(self):
        run, client = self.experiment()
        experiment = AndroidExperiment(run, client=client)
        state = experiment.start()
        self.assertEqual(state["session"]["serial"], "emulator-5556")
        self.assertEqual(state["session"]["projectPath"], str(run / "workspace"))
        restored = AndroidExperiment(run, client=client)
        restored.start()
        self.assertEqual(len(client.sessions), 2)
        restored.stop()
        self.assertTrue(client.sessions[0]["active"])
        self.assertEqual(restored.state["status"], "stopped")
        restored.stop(detach=True)
        self.assertEqual(len(client.sessions), 1)
        self.assertTrue((run / "android/logs/flutter.stdout.log").exists())
        self.assertEqual(restored.state["last_session"]["appId"], experiment.app_id)

    def test_ownership_checks_before_any_start_or_stop(self):
        run, client = self.experiment()
        experiment = AndroidExperiment(run, client=client)
        experiment.start()
        client.sessions[-1]["projectPath"] = str(ROOT.parent / "apps/quizai")
        for operation in (experiment.start, experiment.stop):
            with self.assertRaisesRegex(ValueError, "registration changed"):
                operation()
        self.assertFalse(any(action == "Stop" for action, _ in client.calls))
        experiment.state["session"]["appId"] = "quizai"
        with self.assertRaisesRegex(ValueError, "outside this experiment"):
            experiment.stop()

    def test_validation_traversal_suffix_and_plain_non_flutter(self):
        run, client = self.experiment()
        for project in ("../..", str(ROOT.parent)):
            with self.assertRaises(ValueError):
                AndroidExperiment(run, project=project, client=client)
        gradle = run / "workspace/android/app/build.gradle.kts"
        gradle.write_text('applicationId = "dev.agentlab.offline"\napplicationIdSuffix = ".debug"')
        with self.assertRaisesRegex(ValueError, "flavors or suffixes"):
            AndroidExperiment(run, client=client).start()
        (run / "workspace/pubspec.yaml").unlink()
        self.assertEqual(AndroidExperiment(run, client=client).start()["status"], "waiting_for_flutter")
        self.assertEqual(client.calls, [])

    def test_failure_is_saved_and_no_automatic_stop_of_other_apps(self):
        run, client = self.experiment()
        client.failure = True
        with self.assertRaisesRegex(RuntimeError, "runner failed"):
            AndroidExperiment(run, client=client).start()
        state = json.loads((run / "android.json").read_text())
        self.assertEqual(state["status"], "failed")
        self.assertTrue((run / "android/logs/flutter.stdout.log").exists())
        self.assertTrue(client.sessions[0]["active"])

    def test_flutter_validation_failure_returns_evidence_without_starting_android(self):
        run, client = self.experiment()
        experiment = AndroidExperiment(run, client=client)
        cycle = run / "cycles/001"
        cycle.mkdir(parents=True)
        client.validate = lambda *args: {"passed": False, "checks": [{"name": "test", "exit_code": 1, "output_tail": "Widget assertion failed"}]}
        result = experiment.after_cycle(cycle, {"name_status": ["M\tlib/main.dart"]})
        self.assertEqual(result["status"], "validation_failed")
        self.assertIn("Widget assertion", result["validation"]["checks"][0]["output_tail"])
        self.assertFalse(any(action == "Start" for action, _ in client.calls))
        self.assertTrue((cycle / "android.json").exists())

    def test_reload_evidence_and_missing_confirmation(self):
        run, client = self.experiment()
        experiment = AndroidExperiment(run, client=client, timeout=0)
        cycle = run / "cycles/001"
        cycle.mkdir(parents=True)
        experiment.after_cycle(cycle, {"name_status": ["M\tlib/main.dart"]})
        client.reloads = 1
        cycle2 = run / "cycles/002"
        cycle2.mkdir()
        result = experiment.after_cycle(cycle2, {"name_status": ["M\tlib/main.dart"]})
        self.assertTrue(result["reload_confirmed"])
        self.assertEqual(result["hot_reloads"], 1)
        with self.assertRaisesRegex(RuntimeError, "No successful Hot Reload"):
            experiment.after_cycle(cycle2, {"name_status": ["M\tlib/main.dart"]})
        self.assertEqual(json.loads((cycle2 / "android.json").read_text())["status"], "failed")

    def test_native_autonomous_cycles_keep_android_association_and_evidence(self):
        run, client = self.experiment()
        git(run / "workspace", "add", "-A")
        git(run / "workspace", "commit", "-m", "Offline Flutter fixture")
        result, manifest = run_autonomous("Build the counter", source=run / "workspace", offline=True,
                                          android={"project": "."}, android_client=client, timeout=30)
        self.assertEqual(manifest["status"], "completed", (result / "error.txt").read_text() if (result / "error.txt").exists() else manifest)
        for number in ("001", "002"):
            state = json.loads((result / "cycles" / number / "android.json").read_text())
            self.assertEqual(state["session"]["projectPath"], str(result / "workspace"))
            self.assertEqual(state["status"], "running")
        payload = json.loads((result / "decisions/001/input.json").read_text())
        self.assertEqual(payload["history"][0]["android"]["status"], "running")
        self.assertEqual(payload["android"]["session"], manifest["android"]["session"])
        self.assertTrue(client.sessions[0]["active"])

    def test_offline_never_calls_android_or_flutter_and_runtime_excludes_credentials(self):
        with self.assertRaisesRegex(ValueError, "Offline mode"):
            run_autonomous("Flutter", offline=True, android={"project": "."})
        with self.assertRaisesRegex(ValueError, "Offline mode"):
            run_autonomous("Flutter", offline=True, flutter=True)
        with patch.dict(os.environ, {"CODEX_API_KEY": "secret", "API_KEY": "secret", "GIT_DIR": "secret", "AI_APPS_AI_API_KEY": "secret"}):
            self.assertFalse(set(runtime_env()) & {"CODEX_API_KEY", "API_KEY", "GIT_DIR", "AI_APPS_AI_API_KEY"})
        run, _ = self.experiment()
        def manager_output(*args, **kwargs):
            kwargs["stdout"].write(b'[{"appId":"test"}]')
            return subprocess.CompletedProcess([], 0)
        with patch("lab_android.subprocess.run", side_effect=manager_output) as call:
            result = Manager(run).call("List")
            self.assertEqual(result[0]["appId"], "test")
            self.assertIn(str(ROOT.parent / "scripts/android-session.ps1"), call.call_args.args[0])
            self.assertTrue(list((run / "android/operations").glob("*.json")))


if __name__ == "__main__":
    unittest.main()
