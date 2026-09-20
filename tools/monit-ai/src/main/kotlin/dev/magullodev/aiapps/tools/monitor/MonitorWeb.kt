package dev.magullodev.aiapps.tools.monitor

import com.sun.net.httpserver.HttpServer
import dev.magullodev.aiapps.core.ai.AiUsageRecord
import dev.magullodev.aiapps.tools.monitor.quiz10.Quiz10History
import dev.magullodev.aiapps.tools.monitor.quiz10.Quiz10GameStatus
import dev.magullodev.aiapps.tools.monitor.quiz10.Quiz10Test
import dev.magullodev.aiapps.tools.monitor.quiz10.aggregateCost
import java.math.BigDecimal
import java.math.RoundingMode
import java.net.InetSocketAddress
import java.nio.charset.StandardCharsets
import java.util.Locale

internal fun startMonitorServer(port: Int = 8081, env: Map<String, String> = System.getenv(), defaultWindow: Int = 50): HttpServer {
    require(defaultWindow in setOf(10, 25, 50, 100))
    val server = HttpServer.create(InetSocketAddress("127.0.0.1", port), 0)
    server.createContext("/") { exchange ->
        val (status, body) = try {
            when {
                exchange.requestMethod != "GET" -> 405 to "Method not allowed"
                exchange.requestURI.path != "/" -> 404 to "Not found"
                else -> {
                    val value = exchange.requestURI.rawQuery?.split('&')?.firstOrNull { it.startsWith("window=") }?.substringAfter('=')
                    val window = if (value == null) defaultWindow else value.toIntOrNull()
                    if (window !in setOf(10, 25, 50, 100)) 400 to "Invalid window"
                    else 200 to renderMonitorPage(monitorQuery(env).quiz10History(window!!))
                }
            }
        } catch (_: Exception) {
            500 to "Unable to read usage records"
        }
        val bytes = body.toByteArray(StandardCharsets.UTF_8)
        exchange.responseHeaders.set("Content-Type", if (status == 200) "text/html; charset=utf-8" else "text/plain; charset=utf-8")
        exchange.responseHeaders.set("Cache-Control", "no-store")
        exchange.sendResponseHeaders(status, bytes.size.toLong())
        exchange.responseBody.use { it.write(bytes) }
    }
    server.start()
    return server
}

internal fun renderMonitorPage(history: Quiz10History): String = buildString {
    append("""<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>MONIT-AI · Costes de Quiz10</title><style>
        :root{font-family:system-ui,Arial,sans-serif;color:#172334;background:#f4f7fb}body{margin:0}main{max-width:1220px;margin:auto;padding:32px 20px 64px}h1{margin:0 0 22px}p{color:#516071}
        details{background:white;border:1px solid #dce4ee;border-radius:14px}details.product{box-shadow:0 4px 18px #1723340a}summary{cursor:pointer;list-style:disclosure-closed;display:list-item;padding:18px 22px;font-weight:700}details[open]>summary{list-style:disclosure-open}summary::marker{color:#2870ae}
        .summary-line{display:inline-flex;justify-content:space-between;align-items:center;gap:16px;width:calc(100% - 22px);vertical-align:middle;flex-wrap:wrap}.summary-cost{font-size:.9rem;color:#516071}.summary-cost strong{font-size:1rem;color:#172334;margin-left:8px}.product-path{margin:0;padding:0 22px 12px;font-family:ui-monospace,monospace;font-size:.88rem}
        .product-body{padding:0 22px 22px}.chart-head{display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap}.chart-head h2{font-size:1.15rem}select{font:inherit;padding:7px 12px;border:1px solid #aebccb;border-radius:8px;background:white}
        svg{width:100%;height:auto;display:block}svg text{font-size:15px;fill:#516071}.grid{stroke:#e4eaf0}.axis{stroke:#67798c;stroke-width:1.5}.individual{fill:none;stroke:#d43f42;stroke-width:2.5}.rolling{fill:none;stroke:#2870ae;stroke-width:2.5}.individual-point{fill:#d43f42}.rolling-point{fill:#2870ae}
        .legend{display:flex;gap:22px;flex-wrap:wrap}.key{display:inline-block;width:22px;height:3px;vertical-align:middle;margin-right:7px}.note{font-size:.88rem}.executions{display:grid;gap:10px;margin-top:24px}.execution summary{padding:14px 18px}.execution .summary-cost{font-weight:400}.scroll{overflow-x:auto;padding:0 18px 18px}
        table{border-collapse:collapse;width:100%;min-width:720px;font-variant-numeric:tabular-nums}th,td{padding:10px 12px;border-bottom:1px solid #e5eaf0;text-align:right;white-space:nowrap}th:first-child,td:first-child{text-align:left}th{font-size:.77rem;color:#536375}.tag{font-size:.72rem;background:#e6eef8;border-radius:8px;padding:2px 6px;margin-left:5px;font-weight:500}
    </style></head><body><main><h1>MONIT-AI</h1>""")
    val productCost = aggregateCost(history.tests.map { it.totalCost })
    append("<details class=\"product\" open><summary><span class=\"summary-line\"><span>Quiz10</span><span class=\"summary-cost\">COSTE ACUMULADO <strong>${costText(productCost, history.tests.any { it.status == Quiz10GameStatus.IN_PROGRESS })}</strong></span></span></summary>")
    append("<p class=\"product-path\">systems/games/quiz10/</p><div class=\"product-body\">")
    append("<div class=\"chart-head\"><h2>Evolución del coste de IA</h2><form method=\"get\" action=\"/\"><label for=\"window\">Media móvil · partidas cerradas: </label><select id=\"window\" name=\"window\" onchange=\"this.form.submit()\">")
    listOf(10, 25, 50, 100).forEach { n -> append("<option value=\"$n\"${if (history.window == n) " selected" else ""}>$n</option>") }
    append("</select><noscript><button type=\"submit\">Aplicar</button></noscript></form></div>")
    append(renderCostChart(history))
    append("<div class=\"legend\"><span><i class=\"key\" style=\"background:#d43f42\"></i>Coste total por partida</span><span><i class=\"key\" style=\"background:#2870ae\"></i>Media móvil de partidas cerradas</span></div>")
    append("<p class=\"note\">Los huecos indican costes indeterminables. Las partidas en curso y de estado desconocido no entran en la media.</p>")
    append("<div class=\"executions\">")
    history.tests.asReversed().forEachIndexed { index, game -> appendExecution(game, index == 0) }
    append("</div><p class=\"note\">Provisional: consumo acumulado. Retrospectivo: tarifa aplicada a una llamada sin tarifa registrada. Los importes parciales e indeterminables se identifican por separado.</p></div></details></main></body></html>")
}

private fun StringBuilder.appendExecution(game: Quiz10Test, expanded: Boolean) {
    val status = when (game.status) {
        Quiz10GameStatus.COMPLETED -> "COMPLETADA"
        Quiz10GameStatus.FAILED -> "FALLIDA"
        Quiz10GameStatus.IN_PROGRESS -> "EN CURSO"
        Quiz10GameStatus.UNKNOWN -> "ESTADO DESCONOCIDO"
    }
    append("<details class=\"execution\"${if (expanded) " open" else ""}><summary><span class=\"summary-line\"><span>Partida #${game.position} · $status</span><span class=\"summary-cost\">COSTE TOTAL <strong>${costText(game.totalCost, game.status == Quiz10GameStatus.IN_PROGRESS)}</strong></span></span></summary>")
    append("<div class=\"scroll\"><table><thead><tr>")
    listOf("MODELO", "TOKENS ENTRADA", "TOKENS SALIDA", "COSTE ENTRADA", "COSTE SALIDA", "COSTE TOTAL")
        .forEach { append("<th scope=\"col\">$it</th>") }
    append("</tr></thead><tbody>")
    game.allCalls.groupBy { it.model ?: "Modelo desconocido" }.forEach { (model, calls) -> appendModelRow(game, model, calls) }
    append("</tbody></table></div></details>")
}

private fun StringBuilder.appendModelRow(game: Quiz10Test, model: String, calls: List<AiUsageRecord>) {
    val costs = calls.map { estimateCallCosts(it, game.ratesByModel) }
    val input = aggregateCost(costs.map { it.input })
    val output = aggregateCost(costs.map { it.output })
    val combined = aggregateCost(costs.map { it.total })
    val provisional = game.status == Quiz10GameStatus.IN_PROGRESS
    append("<tr><td>${escape(model)}</td><td>${tokens(calls.map { it.inputTokens })}</td><td>${tokens(calls.map { it.outputTokens })}</td>")
    append("<td>${costText(input, provisional)}</td><td>${costText(output, provisional)}</td><td>${costText(combined, provisional)}</td></tr>")
}

private fun tokens(values: List<Long?>): String = when {
    values.isEmpty() || values.all { it == null } -> "—"
    else -> values.filterNotNull().sum().toString() + if (values.any { it == null }) " (parcial)" else ""
}

private fun costText(cost: AiUsageCostEstimate, provisional: Boolean): String {
    val amount = cost.amount?.setScale(6, RoundingMode.HALF_UP)?.toPlainString()
    val value = when (cost.determinability) {
        AiCostDeterminability.KNOWN -> "$amount ${escape(cost.currency ?: "")}".trim()
        AiCostDeterminability.PARTIAL -> "${amount?.let { "$it ${escape(cost.currency ?: "")}" } ?: "Indeterminable"} (parcial)"
        AiCostDeterminability.NOT_DETERMINABLE -> "Indeterminable"
    }
    val provisionalTag = if (provisional) "<span class=\"tag\">Provisional</span>" else ""
    val retrospective = if (cost.rateSource == AiCostRateSource.RETROSPECTIVE) "<span class=\"tag\">Retrospectivo</span>" else ""
    val missing = if (cost.missingRateModels.isEmpty()) "" else "<span class=\"tag\">Sin tarifa: ${escape(cost.missingRateModels.sorted().joinToString(", "))}</span>"
    return value + provisionalTag + retrospective + missing
}

private fun renderCostChart(history: Quiz10History): String {
    val points = history.rolling
    fun known(cost: AiUsageCostEstimate): BigDecimal? = cost.amount?.takeIf {
        cost.determinability == AiCostDeterminability.KNOWN && cost.currency == "USD"
    }
    val max = points.flatMap { listOfNotNull(known(it.individualCost), known(it.cost)) }.maxOrNull() ?: BigDecimal.ZERO
    fun x(index: Int): Double = if (points.size <= 1) 520.0 else 80.0 + index * 880.0 / (points.size - 1)
    fun y(amount: BigDecimal): Double = if (max.signum() == 0) 310.0 else
        310.0 - amount.divide(max, 12, RoundingMode.HALF_UP).toDouble() * 270.0
    fun pathTags(values: List<BigDecimal?>, css: String): String = buildString {
        val segment = StringBuilder()
        values.forEachIndexed { index, value ->
            if (value == null) {
                if (segment.isNotEmpty()) { append("<path class=\"$css\" d=\"$segment\"/>"); segment.clear() }
            } else {
                segment.append(if (segment.isEmpty()) "M" else " L")
                segment.append("%.2f,%.2f".format(Locale.ROOT, x(index), y(value)))
            }
        }
        if (segment.isNotEmpty()) append("<path class=\"$css\" d=\"$segment\"/>")
    }
    val individual = points.map { known(it.individualCost) }
    val rolling = points.map { known(it.cost) }
    return buildString {
        append("<svg role=\"img\" aria-label=\"Evolución cronológica del coste total de IA por partida y media móvil de partidas cerradas\" viewBox=\"0 0 1000 380\" xmlns=\"http://www.w3.org/2000/svg\">")
        for (step in 0..4) {
            val value = max.multiply(BigDecimal(step)).divide(BigDecimal(4), 6, RoundingMode.HALF_UP)
            val yy = 310.0 - step * 67.5
            append("<line class=\"grid\" x1=\"80\" y1=\"$yy\" x2=\"960\" y2=\"$yy\"/>")
            append("<text x=\"70\" y=\"${yy + 5}\" text-anchor=\"end\">${value.toPlainString()}</text>")
        }
        append("<line class=\"axis\" x1=\"80\" y1=\"40\" x2=\"80\" y2=\"310\"/><line class=\"axis\" x1=\"80\" y1=\"310\" x2=\"960\" y2=\"310\"/>")
        append(pathTags(individual, "individual"))
        append(pathTags(rolling, "rolling"))
        individual.forEachIndexed { i, v -> if (v != null) append("<circle class=\"individual-point\" cx=\"${x(i)}\" cy=\"${y(v)}\" r=\"3\"/>") }
        rolling.forEachIndexed { i, v -> if (v != null) append("<circle class=\"rolling-point\" cx=\"${x(i)}\" cy=\"${y(v)}\" r=\"2\"/>") }
        if (points.isNotEmpty()) append("<text x=\"80\" y=\"335\">#${points.first().position}</text><text x=\"960\" y=\"335\" text-anchor=\"end\">#${points.last().position}</text>")
        append("<text x=\"520\" y=\"365\" text-anchor=\"middle\">Partidas · orden cronológico</text><text transform=\"translate(18 190) rotate(-90)\" text-anchor=\"middle\">Coste de IA (USD)</text></svg>")
    }
}

private fun escape(text: String): String = buildString {
    text.forEach { append(when (it) {
        '&' -> "&amp;"
        '<' -> "&lt;"
        '>' -> "&gt;"
        '"' -> "&quot;"
        '\'' -> "&#39;"
        else -> it.toString()
    }) }
}
