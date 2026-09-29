import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import '../../tool/generar_pivotes.dart';

List<ResponseItem> _batch() => [
  for (var i = 1; i <= 10; i++)
    (campo: 'Campo $i', respuesta: 'Respuesta $i'),
];

String _response(List<ResponseItem> items) => jsonEncode({
  'items': [
    for (final item in items)
      {'campo': item.campo, 'respuesta': item.respuesta},
  ],
});

void main() {
  test('el prompt define P y R sin introducir preguntas y conserva la dificultad creciente', () {
    final prompt = buildResponsePrompt(const <String>[]);
    expect(prompt, contains('Selecciona 10 campos de conocimiento aleatorios y distintos (P).'));
    expect(prompt, contains('Pᵢ: nombre de un campo de conocimiento.'));
    expect(prompt, contains('Rᵢ: término, nombre o expresión concreta e identificable de Pᵢ.'));
    expect(prompt, contains('Cada valor contiene únicamente su denominación.'));
    expect(prompt.toLowerCase(), isNot(contains('pregunta')));
    expect(prompt, contains('d(R₁) < d(R₂) < ... < d(R₁₀)'));
    expect(prompt, contains('id(Rᵢ) ∉ U ∪ {id(Rⱼ) : j < i}'));
    expect(prompt, contains('U:\n∅'));
    expect(prompt, isNot(contains('Markdown')));
    expect(prompt, isNot(contains('atractor')));
  });

  test('excluye opcionalmente los tres P frecuentes sin alterar el prompt base', () {
    const rule = 'Pᵢ ∉ {Historia, Geografía, Biología}';
    final original = buildResponsePrompt(const <String>[]);
    final restricted = buildResponsePrompt(
      const <String>[],
      excluirTop3: true,
    );
    expect(original, isNot(contains(rule)));
    expect(restricted, contains(rule));
    expect(restricted.replaceFirst('\n\n$rule', ''), original);
    expect(restricted, contains('U:\n∅'));
    expect(restricted, contains('d(R₁) < d(R₂) < ... < d(R₁₀)'));

    final withoutHistory = buildResponsePrompt(
      ['Respuesta previa'],
      sinU: true,
      excluirTop3: true,
    );
    expect(withoutHistory, contains(rule));
    expect(withoutHistory, isNot(contains('U:')));
    expect(withoutHistory, isNot(contains('Respuesta previa')));
  });

  test('excluye los seis pivotes de ambos packs sin modificar el resto del prompt', () {
    const topSix = 'Pᵢ ∉ {Historia, Geografía, Biología, Economía, Lingüística, Música}';
    final original = buildResponsePrompt(const <String>[]);
    final restricted = buildResponsePrompt(
      const <String>[],
      excluirTop6: true,
    );
    expect(restricted, contains(topSix));
    expect(restricted.replaceFirst('\n\n$topSix', ''), original);
    expect(restricted, contains('U:\n∅'));
    expect(restricted, contains('d(R₁) < d(R₂) < ... < d(R₁₀)'));

    final withoutHistory = buildResponsePrompt(
      ['Respuesta previa'],
      sinU: true,
      excluirTop6: true,
    );
    expect(withoutHistory, contains(topSix));
    expect(withoutHistory, isNot(contains('U:')));
    expect(withoutHistory, isNot(contains('Respuesta previa')));
    expect(
      () => buildResponsePrompt(
        const <String>[],
        excluirTop3: true,
        excluirTop6: true,
      ),
      throwsArgumentError,
    );
  });

  test('el prompt recibe el historial U de respuestas anteriores', () {
    final prompt = buildResponsePrompt([
      'Segunda ley de Newton',
      'Acero inoxidable AISI 304',
    ]);
    expect(
      prompt,
      contains('U:\n- Segunda ley de Newton\n- Acero inoxidable AISI 304'),
    );
  });

  test('sin U no envía historial ni exclusión entre llamadas', () {
    final empty = buildResponsePrompt(const <String>[], sinU: true);
    final populated = buildResponsePrompt(
      ['Segunda ley de Newton', 'AISI 304'],
      sinU: true,
    );
    expect(populated, empty);
    expect(populated, contains('d(R₁) < d(R₂) < ... < d(R₁₀)'));
    expect(populated, contains('id(Rᵢ) ∉ {id(Rⱼ) : j < i}'));
    expect(populated, isNot(contains('id(Rᵢ) ∉ U')));
    expect(populated, isNot(contains('U:')));
    expect(populated, isNot(contains('AISI 304')));
  });

  test('U solo arrastra las respuestas de las nueve llamadas previas del lote', () {
    final completed = <List<ResponseItem>>[];
    for (var call = 0; call < 100; call++) {
      final history = responseHistoryForCall(completed);
      expect(history, hasLength((call % historyBlockSize) * 10));
      if (call % historyBlockSize == 0) {
        expect(history, isEmpty);
        expect(buildResponsePrompt(history), contains('U:\n∅'));
      }
      if (call % historyBlockSize == 9) {
        expect(history.first, 'Respuesta ${call - 9}-0');
        expect(history.last, 'Respuesta ${call - 1}-9');
      }
      completed.add([
        for (var i = 0; i < 10; i++)
          (campo: 'Campo $i', respuesta: 'Respuesta $call-$i'),
      ]);
    }

    expect(responseHistoryForCall(completed), isEmpty);
    final report = compareResponseBatches(completed);
    expect(report, contains('Respuestas textualmente distintas: 1000 de 1000.'));
    expect(report, contains('Campos textualmente distintos: 10 de 1000 selecciones.'));
    expect(
      report,
      contains(
        'Campos nuevos descubiertos por bloque consecutivo de hasta 10 llamadas: '
        '10, 0, 0, 0, 0, 0, 0, 0, 0, 0.',
      ),
    );
  });

  test('U se reinicia cada diez llamadas también en 200 muestras', () {
    final completed = <List<ResponseItem>>[];
    for (var call = 0; call < 200; call++) {
      expect(
        responseHistoryForCall(completed),
        hasLength((call % historyBlockSize) * 10),
      );
      completed.add([
        for (var i = 0; i < 10; i++)
          (campo: 'Campo $i', respuesta: 'Respuesta $call-$i'),
      ]);
    }
    expect(responseHistoryForCall(completed), isEmpty);
    final report = formatExperimentReport(completed);
    expect(report, contains('Llamadas: 200. Selecciones: 2000.'));
    expect(report, contains('| B20 | 10 | 10 | 0 | 10 | 100 |'));
  });

  test('U evita repetir variantes textuales dentro del lote', () {
    final completed = [
      _batch(),
      [
        for (var i = 1; i <= 10; i++)
          (
            campo: 'Otro campo $i',
            respuesta: i == 1 ? ' respuesta 1 ' : 'Otra respuesta $i',
          ),
      ],
    ];
    final history = responseHistoryForCall(completed);
    expect(history, hasLength(19));
    expect(history.where((value) => value == 'Respuesta 1'), hasLength(1));
    expect(history, isNot(contains(' respuesta 1 ')));
  });

  test('el informe de experimento resume los lotes y conserva el global', () {
    final batches = [
      for (var call = 0; call < 11; call++)
        [
          for (var i = 0; i < 10; i++)
            (
              campo: call == 10 && i == 0 ? 'Campo nuevo' : 'Campo $i',
              respuesta: 'Respuesta $call-$i',
            ),
        ],
    ];
    final report = formatExperimentReport(batches);
    expect(report, contains('Llamadas: 11. Selecciones: 110.'));
    expect(report, contains('| B1 | 10 | 10 | 10 | 10 | 100 |'));
    expect(report, contains('| B2 | 1 | 10 | 1 | 11 | 10 |'));
    expect(report, contains('## Comparación global'));
    expect(report, contains('Respuestas textualmente distintas: 110 de 110.'));
  });

  test('el esquema se interpreta como 10 parejas campo-respuesta', () {
    final parsed = parseResponseItems(_response(_batch()));
    expect(parsed, hasLength(10));
    expect(parsed.first.campo, 'Campo 1');
    expect(parsed.last.respuesta, 'Respuesta 10');
  });

  test('rechaza respuestas con menos o más de diez filas', () {
    expect(
      () => parseResponseItems(_response(_batch().take(9).toList())),
      throwsFormatException,
    );
    expect(
      () => parseResponseItems(
        _response([..._batch(), (campo: 'Campo 11', respuesta: 'Respuesta 11')]),
      ),
      throwsFormatException,
    );
  });

  test('rechaza campos vacíos y respuestas sin items', () {
    expect(
      () => parseResponseItems('{}'),
      throwsFormatException,
    );
    expect(
      () => parseResponseItems(
        _response([
          (campo: ' ', respuesta: 'Respuesta 1'),
          ..._batch().skip(1),
        ]),
      ),
      throwsFormatException,
    );
  });

  test('Dart da formato a la tabla sin requerir Markdown en el prompt', () {
    final rendered = formatResponseTable([
      (campo: 'Química | física', respuesta: 'A|B'),
    ]);
    expect(rendered, contains('| Campo de conocimiento | Respuesta |'));
    expect(rendered, contains(r'| Química \| física | A\|B |'));
  });

  test('detecta repeticiones de respuestas entre llamadas', () {
    final first = _batch();
    final second = [
      for (var i = 1; i <= 10; i++)
        (
          campo: 'Otro campo $i',
          respuesta: i == 1 ? ' RESPUESTA 1 ' : 'Otra respuesta $i',
        ),
    ];
    final report = compareResponseBatches([first, second]);
    expect(report, contains('Respuestas textualmente distintas: 19 de 20.'));
    expect(report, contains('Repeticiones textuales: 1.'));
    expect(report, contains('Respuesta 1 — llamada 1, Campo 1; llamada 2, Otro campo 1'));
  });

  test('mide campos diferentes por llamada sin rechazar errores semánticos', () {
    final repeatedField = [
      for (var i = 1; i <= 10; i++)
        (campo: i == 10 ? ' Campo 1 ' : 'Campo $i', respuesta: 'Respuesta $i'),
    ];
    final report = compareResponseBatches([repeatedField]);
    expect(report, contains('Campos distintos por llamada: 9 de 10.'));
  });

  test('informa la frecuencia empírica de P y su sesgo de primera posición', () {
    final first = _batch();
    final second = [
      for (final item in first)
        (campo: item.campo, respuesta: 'Otra ${item.respuesta}'),
    ];
    final report = compareResponseBatches([first, second]);
    expect(report, contains('Campos textualmente distintos: 10 de 20 selecciones.'));
    expect(report, contains('| Campo 1 | 2 | 10.0% | 2 |'));
    expect(report, contains('| Campo 2 | 2 | 10.0% | 0 |'));
    expect(
      report,
      contains('Campos nuevos descubiertos por bloque consecutivo de hasta 10 llamadas: 10.'),
    );
  });

  test('distingue descubrimientos nuevos después de las primeras diez llamadas', () {
    final batches = [
      for (var call = 0; call < 11; call++)
        [
          for (var i = 1; i <= 10; i++)
            (
              campo: call == 10 && i == 1 ? 'Campo 11' : 'Campo $i',
              respuesta: 'Respuesta $call-$i',
            ),
        ],
    ];
    final report = compareResponseBatches(batches);
    expect(report, contains('Campos textualmente distintos: 11 de 110 selecciones.'));
    expect(
      report,
      contains('Campos nuevos descubiertos por bloque consecutivo de hasta 10 llamadas: 10, 1.'),
    );
  });

  test('no confunde diferencias textuales con identidades semánticas', () {
    final batch = [
      for (var i = 1; i <= 10; i++)
        (
          campo: 'Campo $i',
          respuesta: i == 1 ? 'AISI 304' : 'Respuesta $i',
        ),
    ];
    final another = [
      for (var i = 1; i <= 10; i++)
        (
          campo: 'Otro campo $i',
          respuesta: i == 1 ? 'Acero inoxidable AISI 304' : 'Otra respuesta $i',
        ),
    ];
    final report = compareResponseBatches([batch, another]);
    expect(report, contains('Respuestas textualmente distintas: 20 de 20.'));
    expect(report, contains('No se detectan equivalencias semánticas'));
  });
}
