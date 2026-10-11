import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from lab import RUNS, collect_changes, git, prepare_workspace
from bridge import codex_command, executor_env


class LabTest(unittest.TestCase):
    def cycle(self, mode="success", instruction="Fix increment; keep España, quotes ' and ${VAR} as data."):
        result = subprocess.run([
            sys.executable, str(ROOT / "lab.py"), "--executor", "fake",
            "--fake-mode", mode, "--timeout", "1" if mode == "timeout" else "30",
            "--instruction", instruction,
        ], cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
        self.assertTrue(result.stdout.strip(), result.stderr)
        info = json.loads(result.stdout)
        run_dir = Path(info["run_dir"])
        response = json.loads((run_dir / "response.json").read_text(encoding="utf-8"))
        returned = json.loads((run_dir / "chatdev-result.txt").read_text(encoding="utf-8"))
        self.assertEqual(response, returned)
        exchange = [json.loads(line) for line in (run_dir / "exchange.jsonl").read_text(encoding="utf-8").splitlines()]
        self.assertEqual(exchange[0]["instruction"], instruction)
        self.assertEqual(exchange[1]["response"], returned)
        self.assertTrue((run_dir / "chatdev" / run_dir.name / "node_outputs.yaml").exists())
        return result, run_dir, response

    def test_chatdev_round_trip_and_isolation(self):
        original = (ROOT / "examples/counter/counter.py").read_bytes()
        result, run_dir, response = self.cycle()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(response["status"], "completed")
        self.assertEqual(original, (ROOT / "examples/counter/counter.py").read_bytes())
        self.assertEqual(git(run_dir / "workspace", "remote").strip(), b"")
        self.assertTrue((run_dir / "workspace/.git").is_dir())
        patch = (run_dir / "changes.patch").read_bytes()
        self.assertIn(b"GIT binary patch", patch)
        self.assertIn(b"counter.py", patch)
        self.assertIn(b"new.bin", patch)
        subprocess.run([sys.executable, "-B", "-m", "unittest", "-v"], cwd=run_dir / "workspace", check=True, capture_output=True)
        check_dir = RUNS / ("patch_check_" + uuid.uuid4().hex[:8])
        check_dir.mkdir()
        ws, _, _ = prepare_workspace(check_dir)
        git(ws, "apply", "--check", str(run_dir / "changes.patch"))
        git(ws, "apply", str(run_dir / "changes.patch"))
        self.assertEqual((ws / "new.bin").read_bytes(), b"\x00\x01\x02\xff")

    def test_failure_returns_to_chatdev_and_keeps_partial_changes(self):
        result, run_dir, response = self.cycle("fail")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(response["status"], "failed")
        self.assertEqual(response["exit_code"], 7)
        self.assertTrue((run_dir / "changes.patch").stat().st_size)

    def test_timeout_returns_to_chatdev_and_keeps_partial_changes(self):
        result, run_dir, response = self.cycle("timeout")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(response["status"], "timed_out")
        self.assertTrue((run_dir / "changes.patch").stat().st_size)

    def test_exit_zero_without_final_message_is_failure(self):
        result, _, response = self.cycle("no-final")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(response["status"], "failed")

    def test_completed_turn_without_code_changes_is_not_success(self):
        result, _, response = self.cycle("no-change")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(response["status"], "no_changes")
        self.assertFalse(response["changes"]["has_changes"])

    def test_snapshot_does_not_modify_source_refs_or_dirty_files(self):
        run_dir = RUNS / ("snapshot_test_" + uuid.uuid4().hex[:8])
        run_dir.mkdir(parents=True)
        source_run = RUNS / ("source_test_" + uuid.uuid4().hex[:8])
        source_run.mkdir()
        source, _, _ = prepare_workspace(source_run)
        (source / ".gitignore").write_text("ignored.txt\n", encoding="utf-8")
        (source / "ignored.txt").write_text("tracked despite ignore rule", encoding="utf-8")
        git(source, "add", "--force", "-A")
        git(source, "commit", "-m", "Source with tracked ignored file")
        source_head = git(source, "rev-parse", "HEAD").decode().strip()
        (source / "counter.py").write_text("dirty user change", encoding="utf-8")
        source_status = git(source, "status", "--porcelain")
        ws, origin, baseline = prepare_workspace(run_dir, source)
        self.assertEqual(origin["commit"], source_head)
        self.assertEqual(git(source, "rev-parse", "HEAD").decode().strip(), source_head)
        self.assertEqual(git(source, "status", "--porcelain"), source_status)
        self.assertNotIn("dirty user change", (ws / "counter.py").read_text())
        self.assertIn(b"ignored.txt", git(ws, "ls-files"))
        (ws / "counter.py").unlink()
        git(ws, "add", "-A")
        git(ws, "commit", "-m", "Accidental executor commit")
        collect_changes(run_dir, baseline)
        self.assertIn(b"deleted file", (run_dir / "changes.patch").read_bytes())

    def test_prompt_is_not_executable_code(self):
        sentinel = RUNS / ("must_not_exist_" + uuid.uuid4().hex)
        instruction = f"```python\nopen({str(sentinel)!r}, 'w').write('unsafe')\n```"
        result, _, _ = self.cycle(instruction=instruction)
        self.assertEqual(result.returncode, 0)
        self.assertFalse(sentinel.exists())

    def test_command_uses_sandbox_and_prompt_stdin(self):
        command = codex_command({"executor": "fake", "fake_mode": "success", "model": None}, ROOT, ROOT / "final.txt")
        self.assertIn("workspace-write", command)
        self.assertIn('approval_policy="never"', command)
        self.assertIn("--ignore-user-config", command)
        self.assertIn("--ephemeral", command)
        self.assertEqual(command[-1], "-")
        self.assertNotIn("--dangerously-bypass-approvals-and-sandbox", command)

    def test_service_keys_and_git_overrides_not_forwarded(self):
        from unittest.mock import patch
        with patch.dict(os.environ, {"API_KEY": "private", "OPENAI_API_KEY": "private",
                                     "GIT_DIR": "parent", "SERVICE_TOKEN": "private"}):
            env = executor_env(ROOT)
        self.assertNotIn("API_KEY", env)
        self.assertNotIn("OPENAI_API_KEY", env)
        self.assertNotIn("SERVICE_TOKEN", env)
        self.assertNotIn("GIT_DIR", env)


if __name__ == "__main__":
    unittest.main()
