import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/semantic_catalog/pivot_catalog.dart';

void main() {
  test('acepta exactamente diez pivotes sin atractores adicionales', () {
    final catalog = PivotCatalog.fromJson({
      'context': 'Historia de Roma',
      'pivots': [for (var i = 1; i <= 10; i++) 'Tema $i'],
    });
    expect(catalog.context, 'Historia de Roma');
    expect(catalog.pivots, hasLength(10));
    expect(catalog.pivots.first.code, 'P01');
    expect(catalog.pivots.last.code, 'P10');
    expect(() => catalog.pivots.clear(), throwsUnsupportedError);
  });

  test('rechaza listas incompletas y duplicados', () {
    expect(
      () => PivotCatalog.fromJson({
        'context': 'Historia de Roma',
        'pivots': ['Tema 1'],
      }),
      throwsFormatException,
    );
    expect(
      () => PivotCatalog.fromJson({
        'context': 'Historia de Roma',
        'pivots': [for (var i = 1; i <= 9; i++) 'Tema $i', ' TEMA 1 '],
      }),
      throwsFormatException,
    );
  });
}
