package dev.magullodev.quiz10.core.ai

import dev.magullodev.quiz10.core.config.EnvironmentConfig
import dev.magullodev.quiz10.core.contracts.Outcome
import dev.magullodev.quiz10.core.network.UrlConnectionHttpTransport
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.jupiter.api.Assumptions.assumeTrue
import kotlin.test.Test
import kotlin.test.assertIs
import kotlin.test.assertNotNull

class OpenAiResponsesSmokeTest {
    @Test
    fun plannerGeneratesStructuredJson() {
        assumeTrue(System.getenv("QUIZ10_AI_SMOKE") == "1")

        val config = assertIs<Outcome.Success<EnvironmentConfig>>(EnvironmentConfig.load()).value
        val client = OpenAiResponsesClient(config, UrlConnectionHttpTransport(5_000, 30_000))
        val schema = """
            {
              "type": "object",
              "properties": {
                "tema": {"type": "string"},
                "referente": {"type": "string"},
                "respuesta": {"type": "string"}
              },
              "required": ["tema", "referente", "respuesta"],
              "additionalProperties": false
            }
        """.trimIndent()
        val result = client.generate(
            StructuredGenerationRequest(
                GenerationProfile.PLANNER,
                "Devuelve tema Imperio romano, referente Augusto y respuesta 27 a. C.",
                "quiz10_smoke",
                schema,
            ),
        )

        val output = assertIs<Outcome.Success<StructuredGeneration>>(result).value
        val parsed = Json.parseToJsonElement(output.text).jsonObject
        assertNotNull(parsed["tema"])
        assertNotNull(parsed["referente"])
        assertNotNull(parsed["respuesta"])
    }
}
