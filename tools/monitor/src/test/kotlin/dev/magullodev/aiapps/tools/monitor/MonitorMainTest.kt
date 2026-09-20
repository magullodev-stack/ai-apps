package dev.magullodev.aiapps.tools.monitor

import dev.magullodev.aiapps.core.ai.AiUsageCallEvent
import dev.magullodev.aiapps.core.ai.AiUsageCallResult
import dev.magullodev.aiapps.core.ai.AiUsageMetricEvent
import dev.magullodev.aiapps.core.ai.AiUsageOperation
import dev.magullodev.aiapps.core.ai.FileAiUsageMonitor
import dev.magullodev.aiapps.core.ai.ModelRate
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

    @Test
    fun standaloneDefaultAndFiltersReadExistingRecords() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(file, mapOf("terra" to ModelRate("USD", "1000000".toBigDecimal(), "0".toBigDecimal())))
        monitor.recordMetric(AiUsageMetricEvent("quiz10-web", "quiz10_game_started", emptyMap(), "game-1"))
        monitor.recordCall(AiUsageCallEvent("quiz10-web", AiUsageOperation.COVERAGE, "terra", 2,
            AiUsageCallResult.SUCCESS, "game-1", 2, 0, 2, true))
        monitor.recordCall(AiUsageCallEvent("quiz10-web", AiUsageOperation.LUNA, "terra", 3,
            AiUsageCallResult.SUCCESS, "game-1", 3, 0, 3, true))
        monitor.recordCall(AiUsageCallEvent("batch-jobs", AiUsageOperation.OTHER, "terra", 1,
            AiUsageCallResult.SUCCESS, "job-1", 7, 0, 7, true))
        val env = mapOf("AI_APPS_USAGE_FILE" to file.toString())
        val default = runMonitor(emptyArray(), env)
        assertContains(default, "Total game cost chart")
        assertContains(default, "# | ESTADO | COSTE TOTAL")
        assertContains(default, "#1 | IN_PROGRESS | 5.000000 USD~")
        assertFalse(default.contains("game-1"))
        assertFalse(default.contains("TOTAL PARTIDA"))
        assertFalse(default.contains("Comparison"))
        assertFalse(default.contains("tokens"))
        assertFalse(default.contains("audit"))
        assertEquals(default, runMonitor(arrayOf("--app=quiz10-web"), env))
        assertEquals(runMonitor(arrayOf("--window=25"), env),
            runMonitor(arrayOf("--app=quiz10-web", "--window=25"), env))
        val global = runMonitor(arrayOf("--all"), env)
        assertContains(global, "app=quiz10-web workUnit=game-1")
        assertContains(global, "app=batch-jobs workUnit=job-1")
        assertEquals(2, AiUsageQueryService(AiUsageRecordRepository(file)).summarize().byExecution.size)
        val scoped = runMonitor(arrayOf("--work-unit=game-1"), env)
        assertContains(scoped, "status=IN_PROGRESS")
        assertContains(scoped, "terra | luna")
        assertContains(scoped, "TOTAL PARTIDA (acumulado provisional): 5.000000 USD")
        assertFalse(scoped.contains("job-1"))
        assertContains(runMonitor(arrayOf("--app=batch-jobs"), env), "batch-jobs")
        assertContains(runMonitor(arrayOf("--model=terra"), env), "By model:")
        assertContains(runMonitor(arrayOf("--operation=coverage"), env), "coverage")
    }

    @Test
    fun discoversRootAndLegacyApplicationFilesWithoutMovingThem() {
        val rootBase = Path.of("build", "tmp", "monitor-discovery-tests")
        Files.createDirectories(rootBase)
        val root = Files.createTempDirectory(rootBase, "root-")
        val rootFile = root.resolve(Path.of(".ai-apps", "usage", "ai-usage.jsonl"))
        val legacyFile = root.resolve(Path.of("apps", "another-app", ".ai-apps", "usage", "ai-usage.jsonl"))
        val monitor = FileAiUsageMonitor(rootFile, emptyMap())
        monitor.recordMetric(AiUsageMetricEvent("quiz10-web", "quiz10_game_started", emptyMap(), "root-game"))
        FileAiUsageMonitor(legacyFile, emptyMap()).recordCall(AiUsageCallEvent(
            "another-app", AiUsageOperation.OTHER, "model", 1, AiUsageCallResult.SUCCESS, "legacy-job", usageKnown = false))
        val files = usageFiles(emptyMap(), root)
        assertEquals(2, files.size)
        val records = AiUsageRecordRepository(files).readAll()
        assertEquals(2, records.size)
        assertEquals(setOf("quiz10-web", "another-app"), records.map { it.application }.toSet())
        assertEquals(listOf(legacyFile), usageFiles(mapOf("AI_APPS_USAGE_FILE" to legacyFile.toString()), root))
    }

    @Test
    fun explicitPricingFileRepricesOnlyRecordsWithoutSnapshots() {
        val file = usageFile()
        val pricing = Files.createTempFile(file.parent, "rates-", ".json")
        Files.writeString(pricing, """{"currency":"USD","models":{"terra":{"inputCostPerMillion":"1000000","outputCostPerMillion":"2000000"}}}""")
        val monitor = FileAiUsageMonitor(file, emptyMap())
        monitor.recordCall(AiUsageCallEvent("quiz10-web", AiUsageOperation.COVERAGE, "terra", 1,
            AiUsageCallResult.SUCCESS, "historical-game", 10, 5, 15, true))
        val env = mapOf("AI_APPS_USAGE_FILE" to file.toString(), "AI_APPS_PRICING_FILE" to pricing.toString())
        val detail = runMonitor(arrayOf("--app=quiz10-web", "--work-unit=historical-game"), env)
        assertContains(detail, "TOTAL PARTIDA: 20.000000 USD (retrospective estimate)")
        assertContains(detail, "terra | coverage | 10 | 5 | 20.000000 USD (retrospective estimate)")
        val global = runMonitor(arrayOf("--all", "--work-unit=historical-game"), env)
        assertContains(global, "Rates: includes retrospective estimates from AI_APPS_PRICING_FILE")
    }

    @Test
    fun distinctApplicationsWithSameWorkUnitStaySeparate() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(file, emptyMap())
        for (application in listOf("quiz10-web", "another-app")) {
            monitor.recordCall(AiUsageCallEvent(application, AiUsageOperation.OTHER, "model", 1,
                AiUsageCallResult.SUCCESS, "shared-id", usageKnown = false))
        }
        val summary = AiUsageQueryService(AiUsageRecordRepository(file)).summarize()
        assertEquals(2, summary.byExecution.size)
        assertContains(formatUsageSummary(summary), "app=another-app workUnit=shared-id")
        assertContains(formatUsageSummary(summary), "app=quiz10-web workUnit=shared-id")
    }
}
