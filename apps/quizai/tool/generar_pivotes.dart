import 'dart:convert';
import 'dart:io';

import 'package:ai_apps_ai/ai_apps_ai.dart';
import 'package:ai_apps_service/ai_service.dart';

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

  final key = Platform.environment['AI_APPS_AI_API_KEY'] ?? '';
  final service = AiService(apiKey: key, token: 'prueba-local-pivotes');
  AiAppsClient? client;
  final watch = Stopwatch()..start();
  try {
    final server = await service.start();
    client = AiAppsClient(
      endpoint: Uri.parse('http://127.0.0.1:' + server.port.toString()),
      authorization: 'prueba-local-pivotes',
    );
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
    stdout.writeln('Tiempo: ' + watch.elapsedMilliseconds.toString() + ' ms');
  } catch (error) {
    stderr.writeln('ERROR: ' + error.toString());
    exitCode = 1;
  } finally {
    client?.close();
    await service.close();
  }
}

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
