import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import '../../tool/generar_pivotes.dart';

const _sample = '''
| Pivote | Atractor 1 | Atractor 2 | Atractor 3 | Atractor 4 | Atractor 5 |
|---|---|---|---|---|---|
| Ciencias naturales | Química | Orgánica | Hidrocarburos | Aromáticos | Benceno |
| Ciencias formales | Matemáticas | Álgebra | Lineal | Matrices | Determinantes |
| Ciencias sociales | Economía | Macro | Inflación | Precios | IPC |
| Historia | Antigua | Grecia | Clásica | Guerras | Egospótamos |
| Humanidades | Filosofía | Ética | Normativa | Deontología | Principios |
| Tecnología e ingeniería | Informática | IA | Aprendizaje | Redes | Transformers |
| Artes | Música | Armonía | Acordes | Séptima | Dominante |
| Salud y medicina | Medicina | Neurología | Parkinson | Síntomas | Temblor |
''';

const _selectedA1 = <String, String>{
  'Ciencias naturales': 'Química',
  'Ciencias formales': 'Matemáticas',
  'Ciencias sociales': 'Economía',
  'Historia': 'Antigua',
  'Humanidades': 'Filosofía',
  'Tecnología e ingeniería': 'Informática',
  'Artes': 'Música',
  'Salud y medicina': 'Medicina',
};

void main() {
  test('selecciona A1 oficiales al azar y agota cada lista antes de repetir', () {
    final plan = planInitialAttractors(10, random: Random(43));
    expect(plan, hasLength(10));
    expect(initialAttractorsByPivot, hasLength(8));
    for (final entry in initialAttractorsByPivot.entries) {
      final choices = entry.value;
      expect(choices, isNotEmpty);
      expect(
        plan.every((sample) => choices.contains(sample[entry.key])),
        isTrue,
      );
      expect(
        plan.take(choices.length).map((sample) => sample[entry.key]).toSet(),
        hasLength(choices.length),
      );
    }
    expect(
      initialAttractorsByPivot['Salud y medicina'],
      ['Medicina', 'Salud pública', 'Ciencias biomédicas'],
    );
  });

  test('construye el prompt con ocho A1 y sin ejemplo completo', () {
    final prompt = buildExpansionPrompt(_selectedA1);
    expect(prompt, contains('| Ciencias naturales | Química | | | | |'));
    expect(prompt, contains('| Salud y medicina | Medicina | | | | |'));
    expect(prompt, contains('Completa los atractores A2, A3, A4 y A5'));
    expect(prompt, contains(r'\operatorname{Secciones}(x_n^{(p)}\mid S_n^{(p)})'));
    expect(prompt, contains(r'\operatorname{Referentes}(x_5^{(p)}\mid S_5^{(p)})'));
    expect(prompt, contains('subapartados contenidos en el apartado actual'));
    expect(prompt, contains(r'x_{n+1}^{(p)} &\not\equiv_S x_i^{(p)}'));
    expect(prompt, contains(r'x_6^{(p)} &\in \operatorname{Referentes}'));
    expect(prompt, contains('no campos generales'));
    expect(prompt, isNot(contains(r'\rho(S_{n+1}^{(p)})')));
    expect(prompt, contains(r'\operatorname{id}(x_6^{(p)}) &\notin U'));
    expect(prompt, contains(r'\operatorname{id}(x_6^{(p)}) &\ne \operatorname{id}(x_6^{(q)})'));
    expect(prompt, contains(r'n=2,3,4'));
    expect(prompt, contains(r'n=2,\ldots,5'));
    expect(prompt, contains('## U · Referentes A5 ya utilizados\n∅'));
    expect(prompt, isNot(contains('Orgánica')));
    expect(
      () => buildExpansionPrompt({..._selectedA1}..remove('Artes')),
      throwsArgumentError,
    );
  });

  test('incorpora en U los A5 de llamadas anteriores', () {
    final prompt = buildExpansionPrompt(
      _selectedA1,
      usedReferents: ['Axioma de elección', 'Fosa de las Marianas'],
    );
    expect(prompt, contains('## U · Referentes A5 ya utilizados'));
    expect(prompt, contains('- Axioma de elección\n- Fosa de las Marianas'));
    expect(prompt, contains('| Ciencias naturales | Química | | | | |'));
  });

  test('detecta A5 repetidos entre pivotes en una misma llamada', () {
    final table = parseExpansionTable(_sample.replaceFirst(
      'Química | Orgánica | Hidrocarburos | Aromáticos | Benceno',
      'Química | Orgánica | Hidrocarburos | Aromáticos | IPC',
    ), _selectedA1);
    final report = compareExpansionTables([table], [_selectedA1]);
    expect(report, contains('Referentes A5 textualmente distintos: 7 de 8.'));
    expect(report, contains('A5 repetidos textualmente entre filas o llamadas:'));
    expect(report, contains('llamada 1, Ciencias naturales'));
    expect(report, contains('llamada 1, Ciencias sociales'));
  });

  test('analiza ocho rutas de cinco atractores y conserva cada A1', () {
    final result = parseExpansionTable(_sample, _selectedA1);
    expect(result.length, 8);
    expect(result['Historia']!.length, 5);
  });

  test('compara los ocho pivotes y detecta repeticiones exactas', () {
    final table = parseExpansionTable(_sample, _selectedA1);
    final result = compareExpansionTables(
      [table, table],
      [_selectedA1, _selectedA1],
    );
    expect(result, contains('8 de 16 generados'));
    expect(result, contains('| Historia | 1 | 1 | 1 | 1 | 1 | 0 | 1 |'));
  });

  test('atribuye a Luna la divergencia desde A2 con un mismo A1', () {
    final a = parseExpansionTable(_sample, _selectedA1);
    final b = parseExpansionTable(_sample.replaceFirst(
      'Matemáticas | Álgebra | Lineal | Matrices | Determinantes',
      'Matemáticas | Geometría | Euclidiana | Triángulos | Pitágoras',
    ), _selectedA1);
    expect(
      compareExpansionTables([a, b], [_selectedA1, _selectedA1]),
      contains('| Ciencias formales | 1 | 2 | 2 | 2 | 2 | 1 | 0 |'),
    );
  });

  test('no atribuye a Luna la diversidad de dos A1 de Dart', () {
    final otherA1 = {..._selectedA1, 'Ciencias naturales': 'Física'};
    final a = parseExpansionTable(_sample, _selectedA1);
    final b = parseExpansionTable(_sample.replaceFirst(
      'Ciencias naturales | Química | Orgánica | Hidrocarburos | Aromáticos | Benceno',
      'Ciencias naturales | Física | Mecánica | Clásica | Movimiento | Aceleración',
    ), otherA1);
    expect(
      compareExpansionTables([a, b], [_selectedA1, otherA1]),
      contains('| Ciencias naturales | 2 | 2 | 2 | 2 | 2 | 0 | 0 |'),
    );
  });

  test('rechaza cambios en A1, aunque sean candidatos de la lista', () {
    expect(
      () => parseExpansionTable(_sample.replaceFirst(
        '| Salud y medicina | Medicina |',
        '| Salud y medicina | Salud pública |',
      ), _selectedA1),
      throwsFormatException,
    );
    expect(
      () => parseExpansionTable(_sample.replaceFirst(
        'Matemáticas | Álgebra | Lineal | Matrices | Determinantes',
        'Matemáticas | Álgebra | Lineal | Matrices |',
      ), _selectedA1),
      throwsFormatException,
    );
  });
}
