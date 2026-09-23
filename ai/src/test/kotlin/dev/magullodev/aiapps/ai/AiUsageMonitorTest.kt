package dev.magullodev.aiapps.ai

import java.nio.file.Files
import java.nio.file.Path
import kotlin.concurrent.thread
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class AiUsageMonitorTest {
    private fun usageFile(): Path {
        val root = Path.of("build", "tmp", "ai-usage-recording-tests")
        Files.createDirectories(root)
        return Files.createTempFile(root, "usage-", ".jsonl")
    }

    @Test
    fun recordsTechnicalCallsWithHistoricalRateSnapshotsAndNoSecrets() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(file, mapOf("terra" to ModelRate("USD", "2".toBigDecimal(), "8".toBigDecimal())))
        monitor.recordCall(AiUsageCallEvent("quiz10-web", AiUsageOperation.COVERAGE, "terra", 12,
            AiUsageCallResult.ERROR, "unit-1", 100, 20, 120, true, "HTTP_ERROR"))
        monitor.recordMetric(AiUsageMetricEvent("quiz10-web", "quiz10_game_started", emptyMap(), "unit-1"))
        monitor.recordAudit(AiUsageAuditEvent("quiz10-web", "review", "initial_review",
            AiUsageAuditResult.REJECTED, "unit-1", 2, reason = "api_key rejected"))
        val lines = Files.readAllLines(file)
        assertEquals(3, lines.size)
        assertContains(lines[0], "\"workUnitId\":\"unit-1\"")
        assertContains(lines[0], "\"inputCostPerMillion\":\"2\"")
        assertContains(lines[0], "\"result\":\"error\"")
        assertContains(lines[1], "quiz10_game_started")
        assertContains(lines[2], "[redacted] rejected")
        assertFalse(Files.readString(file).contains("api_key"))
    }

    @Test
    fun concurrentRecordingKeepsEveryCall() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(file, emptyMap())
        (1..4).map { worker -> thread {
            repeat(25) { index -> monitor.recordCall(AiUsageCallEvent("app", AiUsageOperation.OTHER,
                "model", 1, AiUsageCallResult.SUCCESS, "unit-$worker-$index", usageKnown = false)) }
        } }.forEach { it.join() }
        assertEquals(100, Files.readAllLines(file).size)
    }
}
