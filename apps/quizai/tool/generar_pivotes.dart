import 'dart:convert';
import 'dart:io';

import 'package:ai_apps_ai/ai_apps_ai.dart';

/// Generación de pivotes con un modelo configurable.
Future<void> main(List<String> args) async {
  final model = args.isNotEmpty ? args.first.trim() : '';
  if (model.isEmpty) {
    stderr.writeln('Uso: dart run tool/generar_pivotes.dart <modelo>');
    exitCode = 1;
    return;
  }
  stdout.write('Contexto: ');
  final context = stdin.readLineSync(encoding: utf8)?.trim() ?? '';
  if (context.isEmpty) {
    stderr.writeln('Escribe un contexto.');
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
      input: _prompt(context),
      schemaName: 'quizai_pivots',
      schema: _schema(),
    ).timeout(const Duration(seconds: 90));
    final data = jsonDecode(result.text);
    if (data is! Map || data['context'] != context || data['pivots'] is! List) {
      throw const FormatException('Respuesta inválida: contexto o pivotes.');
    }
    final pivots = data['pivots'] as List;
    if (pivots.length != 10 ||
        pivots.any((p) => p is! String || p.trim().isEmpty) ||
        pivots.map((p) => (p as String).trim().toLowerCase()).toSet().length != 10) {
      throw const FormatException('Se requieren exactamente 10 pivotes únicos.');
    }
    for (var i = 0; i < pivots.length; i++) {
      stdout.writeln('P' + (i + 1).toString().padLeft(2, '0') + ' ' + pivots[i].toString());
    }
    final usage = result.usage;
    final inputTokens = usage?['inputTokens'];
    final outputTokens = usage?['outputTokens'];
    stdout.writeln('Tokens de entrada: ${inputTokens is int ? inputTokens : 'no disponibles'}');
    stdout.writeln('Tokens de salida: ${outputTokens is int ? outputTokens : 'no disponibles'}');
    final rates = _modelRates[model.toLowerCase()];
    final inputRate = rates?.inputUsdPerMillion;
    final outputRate = rates?.outputUsdPerMillion;
    if (inputTokens is int &&
        outputTokens is int &&
        inputRate != null &&
        outputRate != null &&
        inputRate >= 0 &&
        outputRate >= 0) {
      final price = (inputTokens * inputRate + outputTokens * outputRate) / 1000000;
      stdout.writeln('Precio estimado (USD): ' + price.toStringAsFixed(6));
    } else {
      stdout.writeln('Precio: no disponible (faltan tarifas verificadas para ' +
          model + ').');
    }
    stdout.writeln('Tiempo: ' + watch.elapsedMilliseconds.toString() + ' ms');
  } catch (error) {
    stderr.writeln('ERROR: ' + error.toString());
    exitCode = 1;
  } finally {
    client.close();
  }
}

// Tarifas USD por millón de tokens facilitadas por el usuario.
// Añadir nuevos modelos aquí cuando se conozcan sus tarifas.
typedef _ModelRates = ({double inputUsdPerMillion, double outputUsdPerMillion});

const Map<String, _ModelRates> _modelRates = {
  'gpt-5.6-terra': (inputUsdPerMillion: 2.0, outputUsdPerMillion: 12.0),
  'gpt-5.6-luna': (inputUsdPerMillion: 0.20, outputUsdPerMillion: 1.20),
  'gpt-5.4-mini': (inputUsdPerMillion: 0.75, outputUsdPerMillion: 4.50),
};

String _prompt(String context) => r'''# PROMPT — Generador de Pivotes

Dado un CONTEXTO [C], genera un conjunto ordenado de 10 PIVOTES de exploración:

\[
P(C)=\{P_1,\ldots,P_{10}\}
\]

Cada pivote debe satisfacer:

\[
\begin{aligned}
&\operatorname{Relevancia}(P_i,C)>0\\
&\operatorname{Profundidad}(P_i,C)\geq 20\\
&\operatorname{Especificidad}(P_i,C)>0
\end{aligned}
\]

Sujeto a:

\[
\forall i\neq j:
\quad P_i\neq P_j
\quad\land\quad
\operatorname{Solapamiento}(P_i,P_j)\approx 0
\]

\[
P_i\notin
\{
\text{entidades},
\text{nombres propios},
\text{ejemplos},
\text{tipos},
\text{componentes},
\text{datos particulares}
\}
\]

La selección debe maximizar:

\[
P^*=
\underset{|P|=10}{\arg\max}
\left[
\operatorname{Cobertura}(P,C)
+
\operatorname{Diversidad}(P)
+
\operatorname{Profundidad}(P,C)
\right]
\]

\[
\forall P_i:\quad \operatorname{Palabras}(P_i)\leq 3
\]

Devuelve exclusivamente los diez nombres de los pivotes en el orden seleccionado.
CONTEXTO [C]: ''' + context;

Map<String, Object?> _schema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['context', 'pivots'],
  'properties': {
    'context': {'type': 'string'},
    'pivots': {
      'type': 'array',
      'items': {'type': 'string'},
    },
  },
};
