package dev.magullodev.aiapps.tools.monitor

import dev.magullodev.aiapps.tools.monitor.quiz10.formatQuiz10Game
import dev.magullodev.aiapps.tools.monitor.quiz10.formatQuiz10History
import dev.magullodev.aiapps.core.ai.loadModelRates
import java.nio.file.Files
import java.nio.file.Path

fun main(args: Array<String>) {
    println(runMonitor(args))
}

internal fun runMonitor(args: Array<String>, env: Map<String, String> = System.getenv()): String {
    val query = AiUsageQueryService(AiUsageRecordRepository(usageFiles(env)), loadModelRates(env))
    val filter = parseUsageFilterArgs(args)
    val window = args.firstOrNull { it.startsWith("--window=") }?.substringAfter('=')?.toIntOrNull() ?: 50
    return when {
        args.contains("--all") -> formatUsageSummary(query.summarize(filter))
        filter.workUnitId != null -> {
            val summary = formatUsageSummary(query.summarize(filter))
            val game = if ((filter.application == null || filter.application == "quiz10-web") &&
                filter.model == null && filter.operation == null)
                query.quiz10History(window).tests.firstOrNull { it.workUnitId == filter.workUnitId } else null
            if (game == null) summary else summary + "\n" + formatQuiz10Game(game)
        }
        filter.application == "quiz10-web" && filter.model == null && filter.operation == null -> formatQuiz10History(query.quiz10History(window))
        filter.application != null || filter.model != null || filter.operation != null -> formatUsageSummary(query.summarize(filter))
        else -> formatQuiz10History(query.quiz10History(window))
    }
}

internal fun usageFiles(env: Map<String, String>, root: Path = Path.of(System.getProperty("user.dir"))): List<Path> {
    val configured = env["AI_APPS_USAGE_FILE"]?.trim().orEmpty()
    if (configured.isNotEmpty()) return listOf(Path.of(configured))
    val primary = root.resolve(Path.of(".ai-apps", "usage", "ai-usage.jsonl"))
    val apps = root.resolve("apps")
    if (!Files.isDirectory(apps)) return listOf(primary)
    val legacy = Files.walk(apps, 4).use { paths ->
        paths.filter { it.endsWith(Path.of(".ai-apps", "usage", "ai-usage.jsonl")) }
            .sorted().toList()
    }
    return listOf(primary) + legacy.filter { it != primary }
}

private fun parseUsageFilterArgs(args: Array<String>): AiUsageFilter {
    fun value(prefix: String): String? = args.firstOrNull { it.startsWith(prefix) }
        ?.substringAfter('=')?.trim()?.ifEmpty { null }
    return AiUsageFilter(
        application = value("--app="),
        model = value("--model="),
        operation = value("--operation="),
        workUnitId = value("--work-unit="),
    )
}
