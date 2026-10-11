"""ChatDev ModelProvider extension; the native agent retains model responsibility."""

import json
import os
from pathlib import Path

from bridge import invoke_codex
from lab import ROOT, write_json
from vision import provider_images, validate_observation
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
        messages = [msg.to_dict(include_data=False) for msg in conversation]
        write_json(artifacts / "provider-input.json", messages)
        request = {"executor": "codex", "codex": self.params["executable"],
                   "model": None if self.model_name == "default" else self.model_name,
                   "timeout": self.params["timeout"]}
        receipt = {"status": "reception_failed"}
        try:
            images, expected = provider_images(conversation, artifacts)
            receipt.update({"image_id": expected["image_id"] if expected else None,
                            "attachments": [str(path) for path in images]})
            result = invoke_codex(
                request, workspace, artifacts,
                "You are providing the model response for a native ChatDev agent. "
                "Follow its system role. Use only the supplied messages and actual attached images. "
                "Image blocks below refer to the binary images attached to this prompt. "
                "Return the JSON decision directly; do not invoke tools or inspect files.\n\n"
                + json.dumps(messages, ensure_ascii=False),
                sandbox="read-only", schema=ROOT / "prompts" / ("visual-decision.schema.json" if images else "decision.schema.json"),
                images=images,
                auth_env={key: os.environ["AGENT_LAB_PLANNER_" + key] for key in ("CODEX_HOME", "CODEX_API_KEY")
                          if "AGENT_LAB_PLANNER_" + key in os.environ},
            )
            if result["status"] != "completed":
                raise RuntimeError("ChatDev planner failed; inspect the private planner artifacts")
            if images:
                receipt["evaluation"] = validate_observation(json.loads(result["message"]), expected)
                receipt["status"] = "model_reported_observed"
            else:
                receipt["status"] = "text_only"
        except Exception as exc:
            receipt.update(error_type=type(exc).__name__, error=str(exc))
            raise
        finally:
            write_json(artifacts / "visual-reception.json", receipt)
        return ModelResponse(message=Message(content=result["message"], role=MessageRole.ASSISTANT),
                             raw_response=result)

    def extract_token_usage(self, response):
        usage = response.get("usage", {})
        return TokenUsage(input_tokens=usage.get("input_tokens", 0), output_tokens=usage.get("output_tokens", 0))


class OfflinePlanner(CodexPlanner):
    def call_model(self, client, conversation, timeline, tool_specs=None, **kwargs):
        from tests.offline_planner import decide
        messages = [msg.to_dict(include_data=False) for msg in conversation]
        write_json(Path(self.params["artifacts_dir"]) / "provider-input.json", messages)
        from entity.messages import MessageBlockType
        payload = json.loads("\n".join(block.text for block in conversation[-1].blocks()
                                      if block.type is MessageBlockType.TEXT and block.text))
        artifacts = Path(self.params["artifacts_dir"])
        images, expected = provider_images(conversation, artifacts)
        write_json(artifacts / "visual-reception.json", {"status": "offline_not_evaluated", "offline": True,
                                                       "image_id": expected["image_id"] if expected else None,
                                                       "attachments": [str(path) for path in images]})
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
