"""Offline process double using the same stdin/events/last-message contract as Codex."""

import json
from pathlib import Path
import sys
import time


def emit(data):
    print(json.dumps(data), flush=True)


mode = sys.argv[1]
prompt = sys.stdin.read()
assert "isolated Git workspace" in prompt
if mode != "no-change":
    if "Add decrement" in prompt:
        assert "return value + 1" in Path("counter.py").read_text(encoding="utf-8")
        Path("counter.py").write_text("def increment(value):\n    return value + 1\n\ndef decrement(value):\n    return value - 1\n", encoding="utf-8")
        Path("test_decrement.py").write_text("import unittest\nfrom counter import decrement\n\nclass DecrementTest(unittest.TestCase):\n    def test_decrement(self):\n        self.assertEqual(decrement(2), 1)\n", encoding="utf-8")
    else:
        Path("counter.py").write_text("def increment(value):\n    return value + 1\n", encoding="utf-8")
    Path("new.bin").write_bytes(b"\x00\x01\x02\xff")
emit({"type": "thread.started", "thread_id": "offline-test"})
if mode == "timeout":
    time.sleep(30)
if mode == "fail":
    emit({"type": "turn.failed", "error": {"message": "Simulated failure"}})
    raise SystemExit(7)
if mode == "no-final":
    emit({"type": "turn.completed"})
    raise SystemExit(0)
final = Path(sys.argv[sys.argv.index("--output-last-message") + 1])
import subprocess
test_result = subprocess.run([sys.executable, "-B", "-m", "unittest", "discover", "-v"], capture_output=True)
if mode != "no-change":
    assert test_result.returncode == 0
test_status = "passed" if test_result.returncode == 0 else "failed"
final.write_text(f"Counter milestone in isolated workspace. Local unittests {test_status}. Offline executor.\n", encoding="utf-8")
emit({"type": "item.completed", "item": {"type": "agent_message", "text": final.read_text(encoding="utf-8")}})
emit({"type": "turn.completed", "usage": {"input_tokens": 0, "output_tokens": 0}})
