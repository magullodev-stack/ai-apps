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
final.write_text("Fixed increment in isolated workspace. Offline executor.\n", encoding="utf-8")
emit({"type": "item.completed", "item": {"type": "agent_message", "text": final.read_text(encoding="utf-8")}})
emit({"type": "turn.completed", "usage": {"input_tokens": 0, "output_tokens": 0}})
