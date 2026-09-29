import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import '../../tool/generar_pivotes.dart';

List<AttractorItem> _batch() => [
  for (var i = 1; i <= 10; i++)
    (campo: 'Campo $i', atractor: 'Atractor $i'),
];

String _response(List<AttractorItem> items) => jsonEncode({
  'items': [
    for (final item in items)
      {'campo': item.campo, 'atractor': item.atractor},
  ],
});

void main() {
  test('el prompt pide selección directa y dificultad creciente', () {
    final prompt = buildAttractorPrompt(const <String>[]);
    expect(prompt, contains('Selecciona 10 campos de conocimiento variados'));
    expect(prompt, contains('d(A_1)&<d(A_2)<'));
    expect(prompt, contains(r'\cdots<d(A_{10})'));
    expect(prompt, contains(r'\operatorname{id}(A_i)&\notin U'));
    expect(prompt, contains('U · Atractores ya utilizados:\n∅'));
    expect(prompt, isNot(contains('Markdown')));
    expect(prompt, isNot(contains('definición breve')));
    expect(prompt, isNot(contains('Atractor 5')));
  });

  test('el prompt recibe el historial U de llamadas anteriores', () {
    final prompt = buildAttractorPrompt([
      'Segunda ley de Newton',
      'Acero inoxidable AISI 304',
    ]);
    expect(
      prompt,
      contains(
        'U · Atractores ya utilizados:\n'
        '- Segunda ley de Newton\n'
        '- Acero inoxidable AISI 304',
      ),
    );
  });

  test('el esquema se interpreta como 10 parejas campo-atractor', () {
    final parsed = parseAttractorItems(_response(_batch()));
    expect(parsed, hasLength(10));
    expect(parsed.first.campo, 'Campo 1');
    expect(parsed.last.atractor, 'Atractor 10');
  });

  test('rechaza respuestas con menos o más de diez filas', () {
    expect(
      () => parseAttractorItems(_response(_batch().take(9).toList())),
      throwsFormatException,
    );
    expect(
      () => parseAttractorItems(
        _response([..._batch(), (campo: 'Campo 11', atractor: 'Atractor 11')]),
      ),
      throwsFormatException,
    );
  });

  test('rechaza campos vacíos y respuestas sin items', () {
    expect(
      () => parseAttractorItems('{}'),
      throwsFormatException,
    );
    expect(
      () => parseAttractorItems(
        _response([
          (campo: ' ', atractor: 'Atractor 1'),
          ..._batch().skip(1),
        ]),
      ),
      throwsFormatException,
    );
  });

  test('Dart da formato a la tabla sin requerir Markdown en el prompt', () {
    final rendered = formatAttractorTable([
      (campo: 'Química | física', atractor: 'A|B'),
    ]);
    expect(rendered, contains('| Campo de conocimiento | Atractor |'));
    expect(rendered, contains(r'| Química \| física | A\|B |'));
  });

  test('detecta repeticiones de atractores entre llamadas', () {
    final first = _batch();
    final second = [
      for (var i = 1; i <= 10; i++)
        (
          campo: 'Otro campo $i',
          atractor: i == 1 ? ' ATRACTOR 1 ' : 'Otro atractor $i',
        ),
    ];
    final report = compareAttractorBatches([first, second]);
    expect(report, contains('Atractores textualmente distintos: 19 de 20.'));
    expect(report, contains('Repeticiones textuales: 1.'));
    expect(report, contains('Atractor 1 — llamada 1, Campo 1; llamada 2, Otro campo 1'));
  });

  test('mide campos diferentes por llamada sin rechazar errores semánticos', () {
    final repeatedField = [
      for (var i = 1; i <= 10; i++)
        (campo: i == 10 ? ' Campo 1 ' : 'Campo $i', atractor: 'Atractor $i'),
    ];
    final report = compareAttractorBatches([repeatedField]);
    expect(report, contains('Campos distintos por llamada: 9 de 10.'));
  });

  test('no confunde diferencias textuales con identidades semánticas', () {
    final batch = [
      for (var i = 1; i <= 10; i++)
        (
          campo: 'Campo $i',
          atractor: i == 1 ? 'AISI 304' : 'Atractor $i',
        ),
    ];
    final another = [
      for (var i = 1; i <= 10; i++)
        (
          campo: 'Otro campo $i',
          atractor: i == 1 ? 'Acero inoxidable AISI 304' : 'Otro atractor $i',
        ),
    ];
    final report = compareAttractorBatches([batch, another]);
    expect(report, contains('Atractores textualmente distintos: 20 de 20.'));
    expect(report, contains('No se detectan equivalencias semánticas'));
  });
}
