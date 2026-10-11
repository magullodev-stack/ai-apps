"""ChatDev model providers that read credentials from the process, not YAML."""
import os

from openai import BadRequestError
from runtime.node.agent.providers.base import ProviderRegistry
from runtime.node.agent.providers.openai_provider import OpenAIProvider


class CreativeOpenAI(OpenAIProvider):
    def _build_request_payload(self, timeline, tool_specs, raw_params):
        if not self.model_name.startswith("gpt-5"):
            return super()._build_request_payload(timeline, tool_specs, raw_params)

        # ChatDev's generic defaults were written for non-reasoning models.
        # Send the minimal valid Responses request to GPT-5 Nano.
        messages = [self._serialize_timeline_item(message) for message in timeline]
        messages = [message for message in messages if message is not None]
        if not messages:
            raise ValueError("ChatDev no ha proporcionado mensajes al modelo")
        return {"model": self.model_name, "input": messages,
                "max_output_tokens": 1536}

    def call_model(self, client, conversation, timeline, tool_specs=None, **kwargs):
        try:
            return super().call_model(client, conversation, timeline, tool_specs, **kwargs)
        except BadRequestError as exc:
            body = getattr(exc, "body", None)
            if not isinstance(body, dict):
                try:
                    body = exc.response.json()
                except (ValueError, AttributeError):
                    body = {}
            details = body.get("error", body) if isinstance(body, dict) else {}
            if not isinstance(details, dict):
                details = {}
            info = "; ".join(str(details[k])[:450] for k in ("message", "type", "code", "param")
                             if details.get(k))
            if not info:
                info = str(exc)
            raise RuntimeError("OpenAI rechazó la solicitud (HTTP 400): " + info[:550]) from None

    def create_client(self):
        self.api_key = os.environ.get("OPENAI_API_KEY", "")
        if not self.api_key:
            raise RuntimeError("OPENAI_API_KEY is required for the creative room")
        return super().create_client()


def register():
    if ProviderRegistry.get_provider("lab_creative_openai") is None:
        ProviderRegistry.register("lab_creative_openai", CreativeOpenAI)
    try:
        from runtime.node.agent.providers.gemini_provider import GeminiProvider
    except ImportError:
        return

    class CreativeGemini(GeminiProvider):
        def create_client(self):
            self.api_key = os.environ.get("GEMINI_API_KEY", "")
            if not self.api_key:
                raise RuntimeError("GEMINI_API_KEY is required for the creative room")
            return super().create_client()

    if ProviderRegistry.get_provider("lab_creative_gemini") is None:
        ProviderRegistry.register("lab_creative_gemini", CreativeGemini)
