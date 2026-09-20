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
        :root{font-family:system-ui,Arial,sans-serif;color:#172334;background:#f4f7fb}body{margin:0}main{max-width:1220px;margin:auto;padding:32px 20px 64px}h1{margin:0}p{color:#516071}
        section{background:white;border:1px solid #dce4ee;border-radius:16px;padding:22px;margin-top:20px}.head{display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap}
        select{font:inherit;padding:7px 12px;border:1px solid #aebccb;border-radius:8px;background:white}svg{width:100%;height:auto;display:block}svg text{font-size:15px;fill:#516071}
        .grid{stroke:#e4eaf0}.axis{stroke:#67798c;stroke-width:1.5}.individual{fill:none;stroke:#d43f42;stroke-width:2.5}.rolling{fill:none;stroke:#2870ae;stroke-width:2.5}
        .individual-point{fill:#d43f42}.rolling-point{fill:#2870ae}.legend{display:flex;gap:22px;flex-wrap:wrap}.key{display:inline-block;width:22px;height:3px;vertical-align:middle;margin-right:7px}
        .scroll{overflow-x:auto}table{border-collapse:collapse;width:100%;min-width:900px;font-variant-numeric:tabular-nums}th,td{padding:10px 12px;border-bottom:1px solid #e5eaf0;text-align:right;white-space:nowrap}th:first-child,td:first-child,th:nth-child(2),td:nth-child(2),th:nth-child(3),td:nth-child(3){text-align:left}th{font-size:.77rem;color:#536375}tr.total{background:#f3f7fc;font-weight:700}tr.model td{border-top:2px solid #cbd7e3}.tag{font-size:.72rem;background:#e6eef8;border-radius:8px;padding:2px 6px;margin-left:5px;font-weight:500}.note{font-size:.88rem}
    </style></head><body><main>""")
    append("<header><h1>MONIT-AI</h1><p>Histórico de costes de Quiz10 · ${history.tests.size} partidas registradas</p></header>")
    append("<section><div class=\"head\"><h2>Evolución del coste de IA</h2><form method=\"get\" action=\"/\"><label for=\"window\">Media móvil · partidas cerradas: </label><select id=\"window\" name=\"window\" onchange=\"this.form.submit()\">")
    listOf(10, 25, 50, 100).forEach { n -> append("<option value=\"$n\"${if (history.window == n) " selected" else ""}>$n</option>") }
    append("</select><noscript><button type=\"submit\">Aplicar</button></noscript></form></div>")
    append(renderCostChart(history))
    append("<div class=\"legend\"><span><i class=\"key\" style=\"background:#d43f42\"></i>Coste total por partida</span><span><i class=\"key\" style=\"background:#2870ae\"></i>Media móvil de partidas cerradas</span></div>")
    append("<p class=\"note\">Los huecos indican costes indeterminables. Las partidas en curso y de estado desconocido no entran en la media.</p></section>")
    append("<section><h2>Desglose por partida y modelo</h2><div class=\"scroll\"><table><thead><tr>")
    listOf("PARTIDA", "ESTADO", "MODELO", "TOKENS ENTRADA", "TOKENS SALIDA", "COSTE ENTRADA", "COSTE SALIDA", "COSTE TOTAL")
        .forEach { append("<th scope=\"col\">$it</th>") }
    append("</tr></thead><tbody>")
    history.tests.asReversed().forEach { appendGameRows(it) }
    append("</tbody></table></div><p class=\"note\">Provisional: consumo acumulado. Retrospectivo: tarifa aplicada a una llamada sin tarifa registrada. Los importes parciales e indeterminables se identifican por separado.</p></section></main></body></html>")
}

private fun StringBuilder.appendGameRows(game: Quiz10Test) {
    game.allCalls.groupBy { it.model ?: "Modelo desconocido" }.forEach { (model, calls) -> appendRow(game, model, calls, false) }
    appendRow(game, "TOTAL PARTIDA", game.allCalls, true)
}

private fun StringBuilder.appendRow(game: Quiz10Test, model: String, calls: List<AiUsageRecord>, total: Boolean) {
    val costs = calls.map { estimateCallCosts(it, game.ratesByModel) }
    val input = aggregateCost(costs.map { it.input })
    val output = aggregateCost(costs.map { it.output })
    val combined = if (total) game.totalCost else aggregateCost(costs.map { it.total })
    append("<tr class=\"${if (total) "total" else "model"}\"><td>#${game.position} · ${escape(game.workUnitId)}</td><td>${game.status}</td><td>${escape(model)}</td>")
    append("<td>${tokens(calls.map { it.inputTokens })}</td><td>${tokens(calls.map { it.outputTokens })}</td>")
    append("<td>${costText(input, game.status)}</td><td>${costText(output, game.status)}</td><td>${costText(combined, game.status)}</td></tr>")
}

private fun tokens(values: List<Long?>): String = when {
    values.isEmpty() || values.all { it == null } -> "—"
    else -> values.filterNotNull().sum().toString() + if (values.any { it == null }) " (parcial)" else ""
}

private fun costText(cost: AiUsageCostEstimate, status: Quiz10GameStatus): String {
    val amount = cost.amount?.setScale(6, RoundingMode.HALF_UP)?.toPlainString()
    val value = when (cost.determinability) {
        AiCostDeterminability.KNOWN -> "$amount ${escape(cost.currency ?: "")}".trim()
        AiCostDeterminability.PARTIAL -> "${amount?.let { "$it ${escape(cost.currency ?: "")}" } ?: "Indeterminable"} (parcial)"
        AiCostDeterminability.NOT_DETERMINABLE -> "Indeterminable"
    }
    val provisional = if (status == Quiz10GameStatus.IN_PROGRESS) "<span class=\"tag\">Provisional</span>" else ""
    val retrospective = if (cost.rateSource == AiCostRateSource.RETROSPECTIVE) "<span class=\"tag\">Retrospectivo</span>" else ""
    val missing = if (cost.missingRateModels.isEmpty()) "" else "<span class=\"tag\">Sin tarifa: ${escape(cost.missingRateModels.sorted().joinToString(", "))}</span>"
    return value + provisional + retrospective + missing
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
