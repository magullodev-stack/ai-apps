import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../tool/evaluar_dimensiones.dart';

final _codes = [
  for (var i = 1; i <= 86; i++) 'D${i.toString().padLeft(2, '0')}',
];

Map<String, Object?> _response({
  String? flaggedCode,
  String? flaggedState,
  bool missingExplanation = false,
}) => {
  'evaluaciones': [
    for (final code in _codes)
      {
        'codigo': code,
        'estado': code == flaggedCode ? flaggedState : 'sin_objecion',
      },
  ],
  'alertas': [
    if (flaggedCode != null && !missingExplanation)
      {
        'codigo': flaggedCode,
        'motivo': 'La definición fuerza una respuesta artificial.',
        'ejemplo_fallido': 'Si se admite A, ¿qué se deduce?',
      },
  ],
};

void main() {
  test('conserva literalmente las 86 dimensiones de D01 a D86', () {
    final definitions = parseDimensions(
      File('tool/dimensiones_factuales_86.md').readAsStringSync(),
    );
    expect(definitions, hasLength(86));
    expect(definitions.keys.toList(), _codes);
    expect(definitions['D01'], 'Identificar la entidad a la que corresponde una caracterización determinada.');
    expect(definitions['D86'], 'Identificar el marco en el que determinadas condiciones hacen posible o pertinente una intervención.');
    final prompt = dimensionAuditPrompt(definitions.entries.toList());
    expect(prompt, contains('D01: ${definitions['D01']}'));
    expect(prompt, contains('D86: ${definitions['D86']}'));
    expect(prompt, contains('NO exijas que cada D funcione con cualquier pareja'));
  });

  test('acepta 86 dictámenes completos con una objeción justificada', () {
    final valid = parseDimensionEvaluation(
      jsonEncode(_response(flaggedCode: 'D40', flaggedState: 'riesgo')),
      _codes.toSet(),
    );
    expect(valid.status, hasLength(86));
    expect(valid.status['D40'], 'riesgo');
    expect(valid.status['D01'], 'sin_objecion');
    expect(valid.alerts.keys, ['D40']);
    final report = formatDimensionAuditReport([valid, valid]);
    expect(report, contains('| D40 | 0 | 2 | 0 | 2/2 |'));
    expect(report, contains('| D01 | 2 | 0 | 0 | 0/2 |'));
  });

  test('rechaza auditorías que no justifiquen una objeción', () {
    expect(
      () => parseDimensionEvaluation(
        jsonEncode(_response(
          flaggedCode: 'D40',
          flaggedState: 'problematica',
          missingExplanation: true,
        )),
        _codes.toSet(),
      ),
      throwsFormatException,
    );
  });

  test('rechaza una auditoría incompleta o con un código repetido', () {
    final missing = _response();
    (missing['evaluaciones'] as List).removeLast();
    expect(
      () => parseDimensionEvaluation(jsonEncode(missing), _codes.toSet()),
      throwsFormatException,
    );

    final duplicate = _response();
    (duplicate['evaluaciones'] as List)[85] = {
      'codigo': 'D01',
      'estado': 'sin_objecion',
    };
    expect(
      () => parseDimensionEvaluation(jsonEncode(duplicate), _codes.toSet()),
      throwsFormatException,
    );
  });
}
