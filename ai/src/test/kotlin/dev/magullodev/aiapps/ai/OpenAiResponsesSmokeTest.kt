package dev.magullodev.aiapps.ai

import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.UrlConnectionHttpTransport
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assumptions.assumeTrue
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class OpenAiResponsesSmokeTest {
    @Test
    fun generatesStructuredJsonWithLuna() = generatesStructuredJson(AiProfile.LUNA)

    @Test
    fun generatesStructuredJsonWithMini() = generatesStructuredJson(AiProfile.MINI)

    @Test
    fun generatesStructuredJsonWithTerra() = generatesStructuredJson(AiProfile.TERRA)

    private fun generatesStructuredJson(profile: AiProfile) {
        assumeTrue(System.getenv("AI_APPS_AI_SMOKE") == "1")

        val config = assertIs<Outcome.Success<EnvironmentConfig>>(EnvironmentConfig.load()).value
        val client = OpenAiResponsesClient(config, UrlConnectionHttpTransport(5_000, 30_000))
        val schema = """
            {
              "type": "object",
              "properties": {
                "message": {"type": "string"}
              },
              "required": ["message"],
              "additionalProperties": false
            }
        """.trimIndent()
        val result = client.generate(
            StructuredGenerationRequest(
                profile,
                "Return a JSON object with message set to hello.",
                "structured_smoke",
                schema,
            ),
        )

        val output = assertIs<Outcome.Success<StructuredGeneration>>(result).value
        val parsed = Json.parseToJsonElement(output.text).jsonObject
        assertEquals("hello", parsed["message"]?.jsonPrimitive?.content)
    }
}
