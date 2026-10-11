"""Deterministic provider double; test feedback changes the next instruction."""


def decide(payload):
    history = payload["history"]
    if not history:
        return {"action": "execute", "assessment": "pending",
                "summary": "Build an integer counter. First fix increment, then extend and test it.",
                "instruction": "Fix increment so it adds one and run the counter tests."}
    last = history[-1]["response"]
    if last["status"] != "completed":
        return {"action": "execute", "assessment": "needs_revision",
                "summary": "Executor failed; inspect the partial patch and repair it before extending.",
                "instruction": "Repair the failed increment implementation and run the counter tests."}
    if len(history) == 1:
        assert last["changes"]["has_changes"]
        return {"action": "execute", "assessment": "accepted",
                "summary": "The increment patch adds one and the executor reports success. Extend the existing code.",
                "instruction": "Add decrement to the existing counter and a unittest for it. Preserve the first increment fix."}
    return {"action": "finish", "assessment": "accepted", "instruction": "",
            "summary": "Both iterations changed code; increment and decrement are implemented and tested."}
