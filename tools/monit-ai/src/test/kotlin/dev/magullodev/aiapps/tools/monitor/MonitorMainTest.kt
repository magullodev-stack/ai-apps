package dev.magullodev.aiapps.tools.monitor

import dev.magullodev.aiapps.core.ai.AiUsageCallEvent
import dev.magullodev.aiapps.core.ai.AiUsageCallResult
import dev.magullodev.aiapps.core.ai.AiUsageMetricEvent
import dev.magullodev.aiapps.core.ai.AiUsageOperation
import dev.magullodev.aiapps.core.ai.FileAiUsageMonitor
import dev.magullodev.aiapps.core.ai.ModelRate
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.file.Files
import java.nio.file.Path
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class MonitorMainTest {
    private fun usageFile(): Path {
        val root = Path.of("build", "tmp", "monitor-main-tests")
        Files.createDirectories(root)
        return Files.createTempFile(root, "usage-", ".jsonl")
    }

    private fun page(port: Int, query: String = ""): HttpResponse<String> = HttpClient.newHttpClient().send(
        HttpRequest.newBuilder(URI.create("http://127.0.0.1:$port/$query")).GET().build(),
        HttpResponse.BodyHandlers.ofString(),
    )

    @Test
    fun servesSvgAndEconomicTableWithAllModelsAndRetries() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(file, mapOf(
            "terra" to ModelRate("USD", "1000000".toBigDecimal(), "2000000".toBigDecimal()),
            "luna" to ModelRate("USD", "3000000".toBigDecimal(), "4000000".toBigDecimal()),
        ))
        monitor.recordMetric(AiUsageMetricEvent("quiz10-web", "quiz10_game_started", emptyMap(), "game-1"))
        monitor.recordCall(AiUsageCallEvent("quiz10-web", AiUsageOperation.COVERAGE, "terra", 1,
            AiUsageCallResult.SUCCESS, "game-1", 2, 3, 5, true))
        monitor.recordCall(AiUsageCallEvent("quiz10-web", AiUsageOperation.REVIEW, "terra", 1,
            AiUsageCallResult.ERROR, "game-1", 1, 1, 2, true))
        monitor.recordCall(AiUsageCallEvent("quiz10-web", AiUsageOperation.LUNA, "luna", 1,
            AiUsageCallResult.SUCCESS, "game-1", 2, 1, 3, true))
        monitor.recordMetric(AiUsageMetricEvent("quiz10-web", "quiz10_game_completed", emptyMap(), "game-1"))
        val env = mapOf("AI_APPS_USAGE_FILE" to file.toString())
        val server = startMonitorServer(0, env)
        try {
            val response = page(server.address.port)
            assertEquals(200, response.statusCode())
            val html = response.body()
            assertContains(html, "<svg")
            assertContains(html, "class=\"individual\"")
            assertContains(html, "class=\"rolling\"")
            assertContains(html, "Coste de IA (USD)")
            assertContains(html, "Coste total por partida")
            assertContains(html, "Media móvil de partidas cerradas")
            assertContains(html, "<th scope=\"col\">COSTE ENTRADA</th>")
            assertContains(html, "<th scope=\"col\">COSTE SALIDA</th>")
            assertContains(html, "<td>terra</td><td>3</td><td>4</td><td>3.000000 USD</td><td>8.000000 USD</td><td>11.000000 USD</td>")
            assertContains(html, "<td>luna</td><td>2</td><td>1</td><td>6.000000 USD</td><td>4.000000 USD</td><td>10.000000 USD</td>")
            assertContains(html, "<details class=\"product\" open>")
            assertContains(html, "systems/games/quiz10/")
            assertContains(html, "Partida #1 · COMPLETADA")
            assertContains(html, "COSTE TOTAL <strong>21.000000 USD</strong>")
            assertEquals(1, "<details class=\"execution\"".toRegex().findAll(html).count())
            assertEquals(2, "<tr><td>".toRegex().findAll(html).count())
            assertFalse(html.contains("TOTAL PARTIDA"))
            assertFalse(html.contains("game-1"))
            assertContains(html, "<option value=\"50\" selected>")
            assertContains(page(server.address.port, "?window=10").body(), "<option value=\"10\" selected>")
            assertFalse(html.contains("<pre>"))
        } finally { server.stop(0) }
    }

    @Test
    fun pageReadsNewRecordsOnEveryRequest() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(file, mapOf("terra" to ModelRate("USD", "1000000".toBigDecimal(), "0".toBigDecimal())))
        val server = startMonitorServer(0, mapOf("AI_APPS_USAGE_FILE" to file.toString()))
        try {
            assertFalse(page(server.address.port).body().contains("<details class=\"execution\""))
            monitor.recordCall(AiUsageCallEvent("quiz10-web", AiUsageOperation.COVERAGE, "terra", 1,
                AiUsageCallResult.SUCCESS, "new-game", 2, 0, 2, true))
            val updated = page(server.address.port).body()
            assertContains(updated, "Partida #1 · ESTADO DESCONOCIDO")
            assertFalse(updated.contains("new-game"))
            assertContains(updated, "2.000000 USD")
        } finally { server.stop(0) }
    }

    @Test
    fun retrospectivePricingAndMissingCostsAreIdentified() {
        val file = usageFile()
        val pricing = Files.createTempFile(file.parent, "rates-", ".json")
        Files.writeString(pricing, """{"currency":"USD","models":{"terra":{"inputCostPerMillion":"1000000","outputCostPerMillion":"2000000"}}}""")
        val monitor = FileAiUsageMonitor(file, emptyMap())
        monitor.recordCall(AiUsageCallEvent("quiz10-web", AiUsageOperation.COVERAGE, "terra", 1,
            AiUsageCallResult.SUCCESS, "retrospective", 10, 5, 15, true))
        monitor.recordCall(AiUsageCallEvent("quiz10-web", AiUsageOperation.LUNA, "unknown-model", 1,
            AiUsageCallResult.SUCCESS, "missing", 2, 3, 5, true))
        val env = mapOf("AI_APPS_USAGE_FILE" to file.toString(), "AI_APPS_PRICING_FILE" to pricing.toString())
        val server = startMonitorServer(0, env)
        try {
            val html = page(server.address.port).body()
            assertContains(html, "10.000000 USD")
            assertContains(html, "20.000000 USD")
            assertContains(html, "Retrospectivo")
            assertContains(html, "Indeterminable")
            assertContains(html, "Sin tarifa: unknown-model")
            assertFalse(html.contains("NaN"))
        } finally { server.stop(0) }
    }

    @Test
    fun discoversRootAndLegacyApplicationFilesWithoutMovingThem() {
        val rootBase = Path.of("build", "tmp", "monitor-discovery-tests")
        Files.createDirectories(rootBase)
        val root = Files.createTempDirectory(rootBase, "root-")
        val rootFile = root.resolve(Path.of(".ai-apps", "usage", "ai-usage.jsonl"))
        val legacyFile = root.resolve(Path.of("apps", "another-app", ".ai-apps", "usage", "ai-usage.jsonl"))
        FileAiUsageMonitor(rootFile, emptyMap()).recordMetric(AiUsageMetricEvent("quiz10-web", "quiz10_game_started", emptyMap(), "root-game"))
        FileAiUsageMonitor(legacyFile, emptyMap()).recordCall(AiUsageCallEvent(
            "another-app", AiUsageOperation.OTHER, "model", 1, AiUsageCallResult.SUCCESS, "legacy-job", usageKnown = false))
        val files = usageFiles(emptyMap(), root)
        assertEquals(2, files.size)
        assertEquals(2, AiUsageRecordRepository(files).readAll().size)
        assertEquals(listOf(legacyFile), usageFiles(mapOf("AI_APPS_USAGE_FILE" to legacyFile.toString()), root))
    }
}
