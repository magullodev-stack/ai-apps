"""ChatDev model providers that read credentials from the process, not YAML."""
import os

from openai import BadRequestError
from runtime.node.agent.providers.base import ProviderRegistry
from runtime.node.agent.providers.openai_provider import OpenAIProvider
from runtime.node.agent.providers.base import ModelProvider
from entity.messages import ToolCallPayload
import json
import uuid
from runtime.node.agent.providers.response import ModelResponse
from entity.messages import Message, MessageRole
from utils.token_tracker import TokenUsage


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



class CreativeShared(ModelProvider):
    """Native ChatDev provider backed by the already-running AI-APPS Dart service."""

    def create_client(self):
        return None

    def call_model(self, client, conversation, timeline, tool_specs=None, **kwargs):
        from shared_ai import generate, generate_action
        prompt = "\n\n".join(
            f"{message.role.value.upper()}: {message.text_content()}"
            for message in conversation if message.text_content().strip()
        )[-28500:]
        available = {spec.name for spec in (tool_specs or [])}
        if available:
            actions = ", ".join(sorted(available))
            instruction = (
                "Eres un agente de ChatDev con herramientas REALES sobre un proyecto Flutter aislado. "
                "Puedes utilizarlas libremente y después observar su resultado. "
                "Selecciona tool='none' cuando prefieras simplemente conversar. "
                "Herramientas disponibles: " + actions + ". "
                "room_write requiere path y content (código Dart completo); "
                "room_read requiere path; room_list usa path como directorio; "
                "las demás no requieren argumentos. "
                "No digas que has creado o abierto algo si no lo has hecho con una herramienta. "
                "Después de una llamada recibirás el resultado de la herramienta. "
                "Texto natural en speech; acción en tool, path y content. "
                "Si debes construir, escribe código con room_write, y puedes ejecutarlo con room_launch. "
                "Prioriza una creación visual, interactiva y sorprendente. "
                "No redactes auditorías ni planes de trabajo.\n\n"
            )
            answer, usage = generate_action(self.model_name, instruction + prompt)
            tool = answer["tool"]
            if tool != "none" and tool not in available:
                tool = "none"
            options = {}
            if tool == "room_write":
                options = {"path": answer["path"], "content": answer["content"]}
            elif tool == "room_read":
                options = {"path": answer["path"]}
            elif tool == "room_list":
                options = {"directory": answer["path"] or "lib"}
            calls = [ToolCallPayload(id=uuid.uuid4().hex,
                                     function_name=tool,
                                     arguments=json.dumps(options, ensure_ascii=False))
                     ] if tool != "none" else []
            message = Message(content=answer["speech"], role=MessageRole.ASSISTANT,
                              tool_calls=calls)
        else:
            reply, usage = generate(self.model_name, prompt)
            message = Message(content=reply, role=MessageRole.ASSISTANT)
        from creative_live import publish
        publish("model",
                agent=getattr(self.config, "node_id", "voice"),
                model=self.model_name,
                speech=(answer["speech"] if available else reply)[:2400],
                action=(answer["tool"] if available else "none"),
                path=(answer["path"][:180] if available and answer["tool"] in
                      ("room_write", "room_read", "room_list") else ""),
                usage={"input": usage.get("inputTokens"), "output": usage.get("outputTokens")})
        tracker = getattr(self.config, "token_tracker", None)
        if tracker and isinstance(usage, dict):
            incoming = usage.get("inputTokens")
            outgoing = usage.get("outputTokens")
            if isinstance(incoming, int) and isinstance(outgoing, int):
                tokens = TokenUsage(
                    input_tokens=incoming, output_tokens=outgoing,
                    total_tokens=incoming + outgoing
                )
                tracker.record_usage(
                    getattr(self.config, "node_id", "voice"), self.model_name,
                    tokens, provider="ai-apps-shared"
                )
        return ModelResponse(message=message, raw_response={"usage": usage})

    def extract_token_usage(self, response):
        usage = response.get("usage", {}) if isinstance(response, dict) else {}
        return TokenUsage(
            input_tokens=usage.get("inputTokens", 0),
            output_tokens=usage.get("outputTokens", 0),
            total_tokens=usage.get("totalTokens", 0),
        )

def register():
    if ProviderRegistry.get_provider("lab_creative_shared") is None:
        ProviderRegistry.register("lab_creative_shared", CreativeShared)
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
