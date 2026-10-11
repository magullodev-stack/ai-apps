"""ChatDev model providers that read credentials from the process, not YAML."""
import os

from runtime.node.agent.providers.base import ProviderRegistry
from runtime.node.agent.providers.openai_provider import OpenAIProvider


class CreativeOpenAI(OpenAIProvider):
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
