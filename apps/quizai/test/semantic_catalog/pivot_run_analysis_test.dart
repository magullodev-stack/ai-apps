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
  test('el prompt pide respuestas inequívocas y dificultad creciente', () {
    final prompt = buildResponsePrompt(const <String>[]);
    expect(prompt, contains('Selecciona 10 campos de conocimiento aleatorios y distintos (P).'));
    expect(prompt, contains('un término, nombre o expresión (R)'));
    expect(prompt, contains('respuesta inequívoca a una pregunta de conocimiento'));
    expect(prompt, contains('d(R₁) < d(R₂) < ... < d(R₁₀)'));
    expect(prompt, contains('id(Rᵢ) ∉ U ∪ {id(Rⱼ) : j < i}'));
    expect(prompt, contains('U:\n∅'));
    expect(prompt, isNot(contains('Markdown')));
    expect(prompt, isNot(contains('atractor')));
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

  test('detecta repeticiones de respuestaes entre llamadas', () {
    final first = _batch();
    final second = [
      for (var i = 1; i <= 10; i++)
        (
          campo: 'Otro campo $i',
          respuesta: i == 1 ? ' ATRACTOR 1 ' : 'Otro respuesta $i',
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
          respuesta: i == 1 ? 'Acero inoxidable AISI 304' : 'Otro respuesta $i',
        ),
    ];
    final report = compareResponseBatches([batch, another]);
    expect(report, contains('Respuestas textualmente distintas: 20 de 20.'));
    expect(report, contains('No se detectan equivalencias semánticas'));
  });
}
