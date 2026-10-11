"""ChatDev ModelProvider extension; the native agent retains model responsibility."""

import json
import os
from pathlib import Path

from bridge import invoke_codex
from lab import ROOT, write_json
from entity.messages import Message, MessageRole
from runtime.node.agent.providers.base import ModelProvider, ProviderRegistry
from runtime.node.agent.providers.response import ModelResponse
from utils.token_tracker import TokenUsage


class CodexPlanner(ModelProvider):
    def create_client(self):
        return self

    def call_model(self, client, conversation, timeline, tool_specs=None, **kwargs):
        if tool_specs:
            raise ValueError("The deliberating agent has no execution tools")
        artifacts = Path(self.params["artifacts_dir"])
        workspace = Path(self.params["workspace"])
        messages = [{"role": msg.role.value, "content": msg.text_content()} for msg in conversation]
        write_json(artifacts / "provider-input.json", messages)
        request = {"executor": "codex", "codex": self.params["executable"],
                   "model": None if self.model_name == "default" else self.model_name,
                   "timeout": self.params["timeout"]}
        result = invoke_codex(
            request, workspace, artifacts,
            "You are providing the model response for a native ChatDev agent. "
            "Follow its system role. Use only the supplied messages. Return the JSON "
            "decision directly; do not invoke tools or inspect files.\n\n"
            + json.dumps(messages, ensure_ascii=False),
            sandbox="read-only", schema=ROOT / "prompts/decision.schema.json",
            auth_env={key: os.environ["AGENT_LAB_PLANNER_" + key] for key in ("CODEX_HOME", "CODEX_API_KEY")
                      if "AGENT_LAB_PLANNER_" + key in os.environ},
        )
        if result["status"] != "completed":
            raise RuntimeError("ChatDev planner failed; inspect the private planner artifacts")
        return ModelResponse(message=Message(content=result["message"], role=MessageRole.ASSISTANT),
                             raw_response=result)

    def extract_token_usage(self, response):
        usage = response.get("usage", {})
        return TokenUsage(input_tokens=usage.get("input_tokens", 0), output_tokens=usage.get("output_tokens", 0))


class OfflinePlanner(CodexPlanner):
    def call_model(self, client, conversation, timeline, tool_specs=None, **kwargs):
        from tests.offline_planner import decide
        messages = [{"role": msg.role.value, "content": msg.text_content()} for msg in conversation]
        write_json(Path(self.params["artifacts_dir"]) / "provider-input.json", messages)
        payload = json.loads(conversation[-1].text_content())
        decision = decide(payload)
        return ModelResponse(message=Message(content=json.dumps(decision), role=MessageRole.ASSISTANT),
                             raw_response={"usage": {}, "offline": True})


def register():
    for name, provider, label in (("lab_codex", CodexPlanner, "Agent-lab Codex model"),
                                  ("lab_offline", OfflinePlanner, "Offline test double")):
        existing = ProviderRegistry.get_provider(name)
        if existing is None:
            ProviderRegistry.register(name, provider, label=label)
        elif existing is not provider:
            raise RuntimeError("Provider name already registered by another implementation")
