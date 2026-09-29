import 'dart:convert';
import 'dart:io';
import 'package:ai_apps_ai/ai_apps_ai.dart';

/// Piloto aislado de expansión semántica; no modifica los catálogos de QuizAI.
Future<void> main(List<String> args) async {
  final model = args.isNotEmpty ? args.first.trim() : '';
  if (model.isEmpty) {
    stderr.writeln('Uso: dart run tool/generar_pivotes.dart <modelo> [--ruta]');
    exitCode = 1;
    return;
  }
  final sessionFile = File('../../.ai-apps/dart-service.json');
  if (!await sessionFile.exists()) {
    stderr.writeln('El servicio de IA no está iniciado. Arráncalo con run.ps1.');
    exitCode = 1;
    return;
  }
  final session = jsonDecode(await sessionFile.readAsString());
  if (session is! Map || session['endpoint'] is! String ||
      session['token'] is! String) {
    stderr.writeln('Sesión del servicio de IA inválida.');
    exitCode = 1;
    return;
  }
  final endpoint = Uri.tryParse(session['endpoint'] as String);
  if (endpoint == null || endpoint.scheme != 'http' ||
      endpoint.host != '127.0.0.1') {
    stderr.writeln('Endpoint local del servicio de IA inválido.');
    exitCode = 1;
    return;
  }
  final client = AiAppsClient(
    endpoint: endpoint,
    authorization: session['token'] as String,
  );
  final watch = Stopwatch()..start();
  try {
    stdout.writeln('Modelo: ' + model);
    final result = await client.generate(
      application: 'quizai',
      model: model,
      input: _prompt,
      schemaName: 'quizai_semantic_expansion',
      schema: _schema(),
    ).timeout(const Duration(seconds: 90));
    final data = jsonDecode(result.text);
    if (data is! Map || data['table'] is! String) {
      throw const FormatException('Respuesta inválida: falta la tabla.');
    }
    stdout.writeln((data['table'] as String).trim());
    final usage = result.usage;
    final inputTokens = usage?['inputTokens'];
    final outputTokens = usage?['outputTokens'];
    final totalTokens = usage?['totalTokens'];
    final rates = _modelRates[model.toLowerCase()];
    final inputRate = rates?.inputUsdPerMillion;
    final outputRate = rates?.outputUsdPerMillion;
    String priceFor(Object? tokens, double? rate) =>
        tokens is int && rate != null
            ? (tokens * rate / 1000000).toStringAsFixed(6) + ' USD'
            : 'no disponible';
    final total = totalTokens is int
        ? totalTokens
        : inputTokens is int && outputTokens is int
            ? inputTokens + outputTokens
            : null;
    final totalPrice = inputTokens is int &&
            outputTokens is int &&
            inputRate != null &&
            outputRate != null
        ? ((inputTokens * inputRate + outputTokens * outputRate) / 1000000)
            .toStringAsFixed(6) + ' USD'
        : 'no disponible';
    stdout.writeln('Entrada: ${inputTokens is int ? inputTokens : 'no disponible'} tokens | ${priceFor(inputTokens, inputRate)}');
    stdout.writeln('Salida: ${outputTokens is int ? outputTokens : 'no disponible'} tokens | ${priceFor(outputTokens, outputRate)}');
    stdout.writeln('Total: ${total ?? 'no disponible'} tokens | $totalPrice');
    stdout.writeln('Tiempo: ${watch.elapsedMilliseconds} ms');
  } catch (error) {
    stderr.writeln('ERROR: ' + error.toString());
    exitCode = 1;
  } finally {
    client.close();
  }
}

// Tarifas USD por millón de tokens facilitadas para este proyecto.
typedef _ModelRates = ({double inputUsdPerMillion, double outputUsdPerMillion});

const Map<String, _ModelRates> _modelRates = {
  'gpt-5.6-terra': (inputUsdPerMillion: 2.0, outputUsdPerMillion: 12.0),
  'gpt-5.6-sol': (inputUsdPerMillion: 4.0, outputUsdPerMillion: 20.0),
  'gpt-5.6-luna': (inputUsdPerMillion: 0.20, outputUsdPerMillion: 1.20),
  'gpt-5.4-mini': (inputUsdPerMillion: 0.75, outputUsdPerMillion: 4.50),
};

const _prompt = r'''# PROMPT · EXPANSIÓN SEMÁNTICA

Sea una secuencia de conceptos:

$$
S=(x_0,x_1,\ldots,x_n)
$$

Cada nuevo elemento se obtiene mediante:

$$
\boxed{x_{n+1}\in F(x_{n-1},x_n\mid S)}
$$

Donde $F representa el conjunto de atractores semánticamente admisibles para la configuración actual, considerando el significado acumulado de la secuencia.


Devuelve exclusivamente la tabla completada en bloque md``` literal.

---

# TABLA

## Contexto: Conocimiento general

| Pivote | Atractor 1 | Atractor 2 | Atractor 3 | Atractor 4 | Atractor 5 |
|---|---|---|---|---|---|
| Ciencias naturales | Química | Orgánica | Hidrocarburos | Aromáticos | Benceno |
| Ciencias formales | | | | | |
| Ciencias sociales | | | | | |
| Historia | | | | | |
| Humanidades | | | | | |
| Tecnología e ingeniería | | | | | |
| Artes | | | | | |
| Salud y medicina | | | | | |

---''';

Map<String, Object?> _schema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['table'],
  'properties': {
    'table': {'type': 'string'},
  },
};
