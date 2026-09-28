import 'dart:convert';

import 'package:ai_apps_ai/ai_apps_ai.dart';

/// Un tema y sus diez elementos inmediatos; no despliega un tercer nivel.
final class PivotCatalog {
  PivotCatalog.fromJson(Object? value)
      : context = _context(value),
        pivots = List.unmodifiable(_pivots(value));

  final String context;
  final List<PivotItem> pivots;

  static String _context(Object? value) {
    if (value is! Map<String, dynamic> ||
        value.length != 2 ||
        value['context'] is! String ||
        (value['context'] as String).trim().isEmpty) {
      throw const FormatException('Catálogo de pivotes inválido.');
    }
    return value['context'] as String;
  }

  static List<PivotItem> _pivots(Object? value) {
    final items = (value as Map<String, dynamic>)['pivots'];
    if (items is! List || items.length != 10) {
      throw const FormatException('Se requieren diez pivotes.');
    }
    final names = <String>{};
    return [
      for (var i = 0; i < items.length; i++)
        if (items[i] is String &&
            (items[i] as String).trim().isNotEmpty &&
            names.add((items[i] as String).trim().toLowerCase()))
          PivotItem(
            'P' + (i + 1).toString().padLeft(2, '0'),
            (items[i] as String).trim(),
          )
        else
          throw const FormatException('Pivotes vacíos o duplicados.'),
    ];
  }
}

final class PivotItem {
  const PivotItem(this.code, this.name);
  final String code;
  final String name;
}

abstract interface class PivotCatalogGenerator {
  Future<PivotCatalog> generateCatalog(String context);
}

final class AiPivotCatalogGenerator implements PivotCatalogGenerator {
  AiPivotCatalogGenerator({required this.client, required this.model});

  final AiAppsClient client;
  final String model;

  @override
  Future<PivotCatalog> generateCatalog(String context) async {
    if (context.trim().isEmpty) {
      throw ArgumentError.value(context, 'context', 'El contexto está vacío.');
    }
    if (model.trim().isEmpty || client.authorization.trim().isEmpty) {
      throw StateError('Falta la configuración de generación de pivotes.');
    }
    final result = await client.generate(
      application: 'quizai',
      model: model,
      input: pivotPrompt(context),
      schemaName: 'quizai_pivots',
      schema: pivotSchema(),
    ).timeout(const Duration(seconds: 90));
    final data = jsonDecode(result.text);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de pivotes inválida.');
    }
    // La fuente de verdad del contexto es la entrada del usuario.
    return PivotCatalog.fromJson({
      'context': context,
      'pivots': data['pivots'],
    });
  }
}

String pivotPrompt(String context) => r'''# PROMPT — Generador de Pivotes

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

Map<String, Object?> pivotSchema() => {
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
