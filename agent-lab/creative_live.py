"""Human-readable live events from native ChatDev tool calling."""
import json
import os
from pathlib import Path
import sys
from datetime import datetime, timezone

RATES = {
    "gpt-5.6-luna": (0.20, 1.20),
    "gpt-5.6-terra": (2.0, 12.0),
    "gpt-5.6-sol": (4.0, 20.0),
    "gpt-5.4-mini": (0.75, 4.50),
    "gpt-5-nano": (0.05, 0.40),
}
LABELS = {"chispa": "Chispa", "caos": "Caos", "materia": "Materia"}


def publish(kind, **values):
    room_path = os.environ.get("AGENTLAB_ROOM")
    if not room_path:
        return
    room = Path(room_path)
    if not (room / "room.json").is_file():
        return
    event = {"timestamp": datetime.now(timezone.utc).isoformat(),
             "kind": kind, **values}
    with (room / "studio-events.jsonl").open("a", encoding="utf-8") as log:
        log.write(json.dumps(event, ensure_ascii=False) + "\n")

    if kind == "model":
        agent = LABELS.get(values.get("agent"), values.get("agent", "Agente"))
        speech = values.get("speech", "").strip()
        action = values.get("action", "none")
        usage = values.get("usage") or {}
        incoming, outgoing = usage.get("input"), usage.get("output")
        rates = RATES.get(values.get("model", "").lower())
        if isinstance(incoming, int) and isinstance(outgoing, int):
            if rates:
                amount = (incoming * rates[0] + outgoing * rates[1]) / 1_000_000
                cost = " · aprox. US$" + format(amount, ".6f")
            else:
                cost = ""
            detail = f" [{incoming} entrada + {outgoing} salida{cost}]"
        else:
            detail = " [tokens no disponibles]"
        console = "\n" + agent + ": " + speech + detail
        if action != "none":
            target = values.get("path", "")
            console += "\n    → pide " + action + (" (" + target + ")" if target else "")
        document = "\n### " + agent + "\n\n" + speech + "\n\n" + detail.strip() + "\n"
    else:
        name = values.get("name", "herramienta")
        outcome = values.get("result", "")[:260].replace("\n", " ")
        console = "    ✓ " + name + ": " + outcome
        document = "\n- " + name + ": " + outcome + "\n"

    print(console, file=sys.__stdout__, flush=True)
    with (room / "conversacion.md").open("a", encoding="utf-8") as transcript:
        transcript.write(document)
