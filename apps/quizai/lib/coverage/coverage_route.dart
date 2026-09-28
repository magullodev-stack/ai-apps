import 'dart:math';

import '../semantic_catalog/semantic_catalog.dart';
import 'factual_dimensions.dart';
import 'interrogative_roles.dart';

enum DistractorCompetitiveness {
  low('−'),
  medium('+'),
  high('++');

  const DistractorCompetitiveness(this.symbol);

  final String symbol;
}

final class CoverageRow {
  CoverageRow._({
    required this.number,
    required this.pivot,
    required this.attractor,
    required this.dimension,
    required this.role,
    required List<DistractorCompetitiveness> distractors,
  }) : distractors = List.unmodifiable(distractors);

  final int number;
  final SemanticPivot pivot;
  final SemanticAttractor attractor;
  final FactualDimension dimension;
  final InterrogativeRole role;

  /// Competitiveness for distractors 1, 2 and 3, in that order.
  final List<DistractorCompetitiveness> distractors;
}

final class CoverageRoute {
  CoverageRoute._(this.context, List<CoverageRow> rows)
    : rows = List.unmodifiable(rows);

  final String context;
  final List<CoverageRow> rows;
}

/// Compiles an already validated catalog without AI or mutation of its lists.
/// Dimensions and roles are drawn independently with replacement for each row.
CoverageRoute compileCoverageRoute(SemanticCatalog catalog, Random random) {
  final pivots = [...catalog.pivots]..shuffle(random);
  final rows = <CoverageRow>[];
  for (var i = 0; i < pivots.length; i++) {
    final pivot = pivots[i];
    rows.add(
      CoverageRow._(
        number: i + 1,
        pivot: pivot,
        attractor: pivot.attractors[2 * i + random.nextInt(2)],
        dimension: factualDimensions[random.nextInt(factualDimensions.length)],
        role: interrogativeRoles[random.nextInt(interrogativeRoles.length)],
        distractors: _competitiveness[i],
      ),
    );
  }
  return CoverageRoute._(catalog.context, rows);
}

const _competitiveness = <List<DistractorCompetitiveness>>[
  [
    DistractorCompetitiveness.low,
    DistractorCompetitiveness.low,
    DistractorCompetitiveness.low,
  ],
  [
    DistractorCompetitiveness.low,
    DistractorCompetitiveness.low,
    DistractorCompetitiveness.low,
  ],
  [
    DistractorCompetitiveness.medium,
    DistractorCompetitiveness.low,
    DistractorCompetitiveness.low,
  ],
  [
    DistractorCompetitiveness.medium,
    DistractorCompetitiveness.low,
    DistractorCompetitiveness.low,
  ],
  [
    DistractorCompetitiveness.medium,
    DistractorCompetitiveness.medium,
    DistractorCompetitiveness.low,
  ],
  [
    DistractorCompetitiveness.medium,
    DistractorCompetitiveness.medium,
    DistractorCompetitiveness.low,
  ],
  [
    DistractorCompetitiveness.medium,
    DistractorCompetitiveness.medium,
    DistractorCompetitiveness.medium,
  ],
  [
    DistractorCompetitiveness.high,
    DistractorCompetitiveness.medium,
    DistractorCompetitiveness.medium,
  ],
  [
    DistractorCompetitiveness.high,
    DistractorCompetitiveness.high,
    DistractorCompetitiveness.medium,
  ],
  [
    DistractorCompetitiveness.high,
    DistractorCompetitiveness.high,
    DistractorCompetitiveness.high,
  ],
];
