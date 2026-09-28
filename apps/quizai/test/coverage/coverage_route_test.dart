import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/coverage/coverage_route.dart';
import 'package:quizai/coverage/factual_dimensions.dart';
import 'package:quizai/coverage/interrogative_roles.dart';
import 'package:quizai/semantic_catalog/pivot_catalog.dart';


void main() {
  test('compila diez filas reproducibles con cobertura y competitividad', () {
    final catalog = PivotCatalog.fromJson({
      'context': 'Contexto de cobertura',
      'pivots': [for (var i = 1; i <= 10; i++) 'Pivote $i'],
    });
    final originalPivots = [...catalog.pivots];
    final route = compileCoverageRoute(catalog, Random(42));
    final replay = compileCoverageRoute(catalog, Random(42));

    expect(route.context, catalog.context);
    expect(route.rows, hasLength(10));
    expect(route.rows.map((row) => row.pivot).toSet(), originalPivots.toSet());
    expect(
      route.rows.map((row) => row.pivot),
      isNot(orderedEquals(originalPivots)),
    );
    expect(catalog.pivots, orderedEquals(originalPivots));
    expect(factualDimensions, hasLength(18));
    expect(interrogativeRoles, hasLength(5));
    expect(
      route.rows.map((row) => row.distractors.map((d) => d.symbol).toList()),
      [
        ['−', '−', '−'],
        ['−', '−', '−'],
        ['+', '−', '−'],
        ['+', '−', '−'],
        ['+', '+', '−'],
        ['+', '+', '−'],
        ['+', '+', '+'],
        ['++', '+', '+'],
        ['++', '++', '+'],
        ['++', '++', '++'],
      ],
    );
    for (var i = 0; i < 10; i++) {
      final row = route.rows[i];
      expect(row.number, i + 1);
      expect(factualDimensions, contains(row.dimension));
      expect(interrogativeRoles, contains(row.role));
      expect(row.pivot, same(replay.rows[i].pivot));
      expect(row.dimension, same(replay.rows[i].dimension));
      expect(row.role, same(replay.rows[i].role));
      expect(() => row.distractors.clear(), throwsUnsupportedError);
    }
    expect(() => route.rows.clear(), throwsUnsupportedError);
  });
}
