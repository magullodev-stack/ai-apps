import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import unittest
from unittest.mock import patch
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from bridge import codex_command, executor_env
from deliberation import decision_from_text, load_settings, run_autonomous
from lab import RUNS, git, prepare_workspace
from tests.offline_planner import decide


class DeliberationTest(unittest.TestCase):
    def loop(self, fake_mode="success", timeout=30):
        result = subprocess.run([sys.executable, "-B", str(ROOT / "deliberation.py"),
                                 "--offline", "--fake-mode", fake_mode, "--timeout", str(timeout),
                                 "--instruction", "Build a small, tested integer counter; decide the milestones."],
                                capture_output=True, text=True, encoding="utf-8", cwd=ROOT)
        self.assertTrue(result.stdout.strip(), result.stderr)
        info = json.loads(result.stdout)
        run_dir = Path(info["run_dir"])
        manifest = json.loads((run_dir / "manifest.json").read_text(encoding="utf-8"))
        return result, run_dir, manifest

    def test_native_agent_two_consecutive_iterations_and_final_evaluation(self):
        original = (ROOT / "examples/counter/counter.py").read_bytes()
        result, run_dir, manifest = self.loop()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(manifest["status"], "completed")
        self.assertEqual(manifest["consecutive_successes"], 2)
        first, second = run_dir / "cycles/001", run_dir / "cycles/002"
        request1 = json.loads((first / "request.json").read_text())
        request2 = json.loads((second / "request.json").read_text())
        review1 = json.loads((first / "evaluation.json").read_text())
        self.assertNotEqual(request1["instruction"], request2["instruction"])
        self.assertEqual(review1["instruction"], request2["instruction"])
        input2 = json.loads((run_dir / "decisions/001/input.json").read_text())
        self.assertIn("return value + 1", input2["history"][0]["patch"])
        self.assertEqual(input2["history"][0]["response"]["status"], "completed")
        for cycle in (first, second):
            response = json.loads((cycle / "response.json").read_text())
            self.assertEqual(response, json.loads((cycle / "chatdev-result.txt").read_text()))
            self.assertTrue(response["changes"]["has_changes"])
            self.assertEqual((cycle / response["artifacts"]["workspace"]).resolve(), (run_dir / "workspace").resolve())
            self.assertTrue((cycle / "exchange.jsonl").exists())
            self.assertTrue((cycle / "workspace.tar").exists())
        with tarfile.open(first / "workspace.tar") as archive:
            self.assertNotIn(b"def decrement", archive.extractfile("counter.py").read())
        with tarfile.open(second / "workspace.tar") as archive:
            self.assertIn(b"def decrement", archive.extractfile("counter.py").read())
        final = json.loads((run_dir / "final-decision.json").read_text())
        self.assertEqual(final["action"], "finish")
        self.assertEqual(final, json.loads((second / "evaluation.json").read_text()))
        self.assertTrue((run_dir / "decisions/002/input.json").exists())
        node_outputs = next((run_dir / "decisions/001/chatdev").glob("*/node_outputs.yaml"))
        self.assertIn("builder", node_outputs.read_text(encoding="utf-8"))
        self.assertEqual(git(run_dir / "workspace", "remote"), b"")
        self.assertEqual(original, (ROOT / "examples/counter/counter.py").read_bytes())
        check_run = RUNS / ("auto_patch_check_" + uuid.uuid4().hex[:8])
        check_run.mkdir()
        workspace, _, _ = prepare_workspace(check_run)
        git(workspace, "apply", str(first / "changes.patch"))
        git(workspace, "apply", str(second / "changes.patch"))
        subprocess.run([sys.executable, "-B", "-m", "unittest", "discover", "-v"],
                       cwd=workspace, check=True, capture_output=True)

    def test_native_agent_evaluates_failure_and_keeps_partial_changes(self):
        result, run_dir, manifest = self.loop("fail")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(manifest["status"], "iteration_limit")
        self.assertEqual(manifest["consecutive_successes"], 0)
        review = json.loads((run_dir / "cycles/001/evaluation.json").read_text())
        self.assertEqual(review["assessment"], "needs_revision")
        self.assertIn("Repair", review["instruction"])
        self.assertTrue((run_dir / "cycles/001/changes.patch").stat().st_size)

    def test_cumulative_changes_do_not_count_as_a_second_code_iteration(self):
        def repeat_instruction(payload):
            decision = decide(payload)
            if len(payload["history"]) == 1:
                decision["instruction"] = "Fix increment so it adds one again."
            return decision
        with patch("tests.offline_planner.decide", repeat_instruction):
            run_dir, manifest = run_autonomous("Counter", offline=True, timeout=30)
        self.assertEqual(manifest["status"], "iteration_limit")
        self.assertTrue((run_dir / "changes.patch").stat().st_size)
        self.assertEqual((run_dir / "cycles/002/changes.patch").stat().st_size, 0)
        self.assertEqual(manifest["iterations"][1]["status"], "no_changes")

    def test_invalid_model_output_never_reaches_executor(self):
        bad = {"action": "execute", "assessment": "pending", "summary": "Invalid", "instruction": ""}
        with patch("tests.offline_planner.decide", return_value=bad):
            run_dir, manifest = run_autonomous("Counter", offline=True, timeout=30)
        self.assertEqual(manifest["status"], "failed")
        self.assertFalse((run_dir / "cycles").exists())
        self.assertTrue((run_dir / "decisions/000/chatdev-result.txt").exists())

    def test_early_finish_is_not_two_iterations(self):
        def finish_early(payload):
            if payload["history"]:
                return {"action": "finish", "assessment": "accepted", "instruction": "", "summary": "Finished too early"}
            return decide(payload)
        with patch("tests.offline_planner.decide", finish_early):
            _, manifest = run_autonomous("Counter", offline=True, timeout=30)
        self.assertEqual(manifest["status"], "stopped_early")
        self.assertEqual(len(manifest["iterations"]), 1)

    def test_timeout_evidence_is_reviewed_and_bounded(self):
        result, run_dir, manifest = self.loop("timeout", timeout=1)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(manifest["iterations"]), 2)
        self.assertTrue(all(i["status"] == "timed_out" for i in manifest["iterations"]))
        self.assertEqual(json.loads((run_dir / "cycles/002/evaluation.json").read_text())["assessment"], "needs_revision")

    def test_deliberation_command_is_read_only_and_structured(self):
        cmd = codex_command({"executor": "fake", "fake_mode": "success"}, ROOT, ROOT / "final.txt",
                            sandbox="read-only", schema=ROOT / "prompts/decision.schema.json")
        self.assertEqual(cmd[cmd.index("--sandbox") + 1], "read-only")
        self.assertIn("--output-schema", cmd)

    def test_configuration_has_no_credentials_and_planner_keys_are_not_forwarded(self):
        settings = load_settings(ROOT / "config/deliberation.json")
        self.assertGreaterEqual(settings["max_iterations"], 2)
        with patch.dict(os.environ, {"AGENT_LAB_PLANNER_CODEX_API_KEY": "private", "API_KEY": "private"}):
            env = executor_env(ROOT)
        self.assertNotIn("AGENT_LAB_PLANNER_CODEX_API_KEY", env)
        self.assertNotIn("API_KEY", env)

    def test_decisions_require_the_correct_phase_and_schema(self):
        decision = decide({"history": []})
        with self.assertRaises(ValueError):
            decision_from_text(json.dumps(decision), reviewing=True)
        with self.assertRaises(Exception):
            decision_from_text(json.dumps({**decision, "extra": "unsafe"}), reviewing=False)


if __name__ == "__main__":
    unittest.main()
