/// Source-independent contract, also implementable by a closed catalog provider.
abstract interface class SemanticCatalogGenerator {
  Future<SemanticCatalog> generateCatalog(String context);
}

/// A structurally validated catalog. Semantic quality is not proven by parsing.
final class SemanticCatalog {
  SemanticCatalog._(this.context, List<SemanticPivot> pivots)
    : pivots = List.unmodifiable(pivots);

  /// Accepts the same data shape from AI or a future closed catalog source.
  /// Throws [FormatException] before exposing any incomplete catalog.
  factory SemanticCatalog.fromJson(Object? json) {
    final root = _object(json, const ['context', 'pivots']);
    final context = root['context'];
    if (context is! String || context.trim().isEmpty) throw _invalid;
    final rows = _list(root['pivots'], 10);
    final pivotNames = <String>{};
    final pivots = <SemanticPivot>[];
    for (var p = 0; p < rows.length; p++) {
      final row = _object(rows[p], const ['name', 'attractors']);
      final name = _name(row['name'], pivotNames);
      final values = _list(row['attractors'], 20);
      final attractorNames = <String>{};
      final attractors = <SemanticAttractor>[];
      for (var a = 0; a < values.length; a++) {
        attractors.add(
          SemanticAttractor._(_code('A', a), _name(values[a], attractorNames)),
        );
      }
      pivots.add(SemanticPivot._(_code('P', p), name, attractors));
    }
    return SemanticCatalog._(context, pivots);
  }

  final String context;
  final List<SemanticPivot> pivots;
}

final class SemanticPivot {
  SemanticPivot._(this.code, this.name, List<SemanticAttractor> attractors)
    : attractors = List.unmodifiable(attractors);

  final String code;
  final String name;

  /// Received order is retained; A01 is the first, A20 the last.
  final List<SemanticAttractor> attractors;
}

final class SemanticAttractor {
  const SemanticAttractor._(this.code, this.name);

  final String code;
  final String name;
}

const _invalid = FormatException('El catálogo semántico no cumple el formato.');

Map<String, dynamic> _object(Object? value, List<String> fields) {
  if (value is! Map<String, dynamic> ||
      value.length != fields.length ||
      !fields.every(value.containsKey)) {
    throw _invalid;
  }
  return value;
}

List<dynamic> _list(Object? value, int length) {
  if (value is! List || value.length != length) throw _invalid;
  return value;
}

String _name(Object? value, Set<String> names) {
  if (value is! String || value.trim().isEmpty) throw _invalid;
  final name = value.trim();
  // Only textual duplicates: case and whitespace, not semantic similarity.
  final normalized = name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (!names.add(normalized)) throw _invalid;
  return name;
}

String _code(String prefix, int index) =>
    '$prefix${(index + 1).toString().padLeft(2, '0')}';
