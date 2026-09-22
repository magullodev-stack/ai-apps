package dev.magullodev.aiapps.tools.monitor

import dev.magullodev.aiapps.ai.loadModelRates
import java.nio.file.Files
import java.nio.file.Path

fun main(args: Array<String>) {
    val defaultWindow = args.firstOrNull { it.startsWith("--window=") }?.substringAfter('=')?.toIntOrNull() ?: 50
    val server = startMonitorServer(8081, System.getenv(), defaultWindow)
    println("MONIT-AI: http://localhost:${server.address.port}")
}

internal fun monitorQuery(env: Map<String, String>): AiUsageQueryService =
    AiUsageQueryService(AiUsageRecordRepository(usageFiles(env)), loadModelRates(env))

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
