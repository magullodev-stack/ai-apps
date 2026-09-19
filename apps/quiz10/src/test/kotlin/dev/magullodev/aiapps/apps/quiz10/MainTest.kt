package dev.magullodev.aiapps.apps.quiz10

import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRouteItem
import kotlin.test.Test
import kotlin.test.assertEquals

class MainTest {
    private fun coverageJson(): String =
        """
            {"items":[
              {"area":"A1","group":"G1","referent":"R1","knowledge":"K1","answer":"ANS1"},
              {"area":"A2","group":"G2","referent":"R2","knowledge":"K2","answer":"ANS2"},
              {"area":"A1","group":"G3","referent":"R3","knowledge":"K3","answer":"ANS3"},
              {"area":"A2","group":"G1","referent":"R4","knowledge":"K4","answer":"ANS4"},
              {"area":"A1","group":"G2","referent":"R5","knowledge":"K5","answer":"ANS5"},
              {"area":"A2","group":"G3","referent":"R6","knowledge":"K6","answer":"ANS6"},
              {"area":"A1","group":"G1","referent":"R7","knowledge":"K7","answer":"ANS7"},
              {"area":"A2","group":"G2","referent":"R8","knowledge":"K8","answer":"ANS8"},
              {"area":"A1","group":"G3","referent":"R9","knowledge":"K9","answer":"ANS9"},
              {"area":"A2","group":"G1","referent":"R10","knowledge":"K10","answer":"ANS10"}
            ]}
        """.trimIndent()

    @Test
    fun createQuizPreparerUsesTerraCoverageOnly() {
        val requestedProfiles = mutableListOf<AiProfile>()
        var coverageCalls = 0

        val preparer = createQuizPreparer { request ->
            requestedProfiles += request.profile
            when (request.schemaName) {
                "quiz10_coverage_route" -> {
                    coverageCalls += 1
                    Outcome.Success(StructuredGeneration(coverageJson(), null))
                }
                else -> Outcome.Failure(AiError.TransportFailure)
            }
        }

        preparer.prepare("Historia")

        assertEquals(1, coverageCalls)
        assertEquals(listOf(AiProfile.TERRA), requestedProfiles)
    }

    @Test
    fun createTurnGeneratorUsesLunaProfile() {
        val requestedProfiles = mutableListOf<AiProfile>()
        val generator = createTurnGenerator { request ->
            requestedProfiles += request.profile
            Outcome.Success(
                StructuredGeneration(
                    """
                        {
                          "question":"Q",
                          "correctExplanation":"CE",
                          "distractors":[
                            {"text":"D1","explanation":"E1"},
                            {"text":"D2","explanation":"E2"},
                            {"text":"D3","explanation":"E3"}
                          ]
                        }
                    """.trimIndent(),
                    null,
                ),
            )
        }

        generator(
            CoverageRouteItem(
                difficulty = CoverageDifficulty.EASY,
                area = "A",
                group = "G",
                referent = "R",
                knowledge = "K",
                answer = "ANS",
            ),
            0,
        )

        assertEquals(listOf(AiProfile.LUNA), requestedProfiles)
    }
}
