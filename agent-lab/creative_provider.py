"""AI-APPS shared Dart service provider for ChatDev creative agents."""
import json
import uuid

from entity.messages import Message, MessageRole, ToolCallPayload
from runtime.node.agent.providers.base import ModelProvider, ProviderRegistry
from runtime.node.agent.providers.response import ModelResponse
from utils.token_tracker import TokenUsage


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
                "room_read y room_write admiten lib/main.dart o main.dart. "
                "room_list admite '.' (raíz) o 'lib' y muestra rutas utilizables. "
                "Si una herramienta falla, utiliza su mensaje antes de reintentar. "
                "Las demás no requieren argumentos. "
                "No digas que has creado o abierto algo si no lo has hecho con una herramienta. "
                "Después de una llamada recibirás el resultado de la herramienta. "
                "Texto natural en speech; acción en tool, path y content. "
                "Si eliges escribir código, puedes usar room_write y luego room_launch para probarlo. "
                "La decisión de construir o conversar es tuya.\n\n"
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
