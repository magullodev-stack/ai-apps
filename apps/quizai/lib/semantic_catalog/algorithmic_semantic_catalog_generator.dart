import 'dart:math' as math;

import 'semantic_catalog.dart';
import 'wikidata_catalog_source.dart';

/// Conservative, bounded graph retrieval; failure never exposes a catalog.
/// Labels come from Wikidata (Spanish, then English), never from a model.
final class AlgorithmicSemanticCatalogGenerator
    implements SemanticCatalogGenerator {
  AlgorithmicSemanticCatalogGenerator({WikidataCatalogSource? source, this.log})
    : source = source ?? WikidataCatalogSource();

  final WikidataCatalogSource source;
  final void Function(String)? log;
  Map<String, dynamic> report = {};

  @override
  Future<SemanticCatalog> generateCatalog(String context) async {
    report = {
      'source': 'https://www.wikidata.org/',
      'context': context,
      'status': 'incomplete',
      'ordering':
          'Menor distancia al contexto; más relaciones contextuales distintas; '
          'QID ascendente.',
      'limits': {'topics': 40, 'rowsPerAnchor': 4000},
      'grouping':
          'Tipos (P31) y ocupaciones (P106); primero grupos viables menores; '
          'se descartan grupos con solapamiento >= 65% del grupo menor.',
      'anchors': <Map<String, dynamic>>[],
      'invalidIdentifierRows': 0,
      'groups': <Map<String, dynamic>>[],
      'selected': <Map<String, dynamic>>[],
    };
    if (context.trim().isEmpty) {
      throw ArgumentError('El contexto está vacío.');
    }
    final matches = await source.search(context.trim());
    if (matches.isEmpty) {
      throw const CatalogUnavailable('Wikidata no resolvió el contexto.');
    }
    // Exact label/alias first, then token overlap; API order breaks ties.
    // No dropping words from a free context to silently change its meaning.
    double score(Map<String, dynamic> row) {
      final label = ((row['match'] as Map?)?['text'] ?? row['label']) as String;
      if (_normalize(label) == _normalize(context)) return 2;
      final a = _tokens(label), b = _tokens(context);
      return a.intersection(b).length / a.union(b).length;
    }

    var resolved = matches.first;
    for (final row in matches.skip(1)) {
      if (score(row) > score(resolved)) resolved = row;
    }
    if (score(resolved) < 0.6) {
      throw const CatalogUnavailable(
        'No hay una coincidencia léxica suficientemente próxima al contexto.',
      );
    }
    final root = _qid(resolved['id'] as String);
    report['resolution'] = resolved;
    log?.call('Contexto resuelto: ${resolved['label']} ($root).');

    // Descend only: no parent-class expansion into unrelated subject areas.
    // P1269 links a history/aspect to its actual subject, e.g. a civilization.
    log?.call('Recuperando ámbitos del contexto...');
    final topics = await source.query('''
SELECT DISTINCT ?topic ?topicLabel ?subject ?subjectLabel WHERE {
  wd:$root (^wdt:P279|^wdt:P361|^wdt:P1269)? ?topic .
  OPTIONAL { ?topic wdt:P1269 ?subject }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "es,en". }
} ORDER BY ?topic ?subject LIMIT 41
''');
    report['topicsTruncated'] = topics.length > 40;
    report['topicExpansion'] = topics.take(40).toList();
    final anchors = <String, _Anchor>{
      root: _Anchor(root, resolved['label'] as String, 0),
    };
    for (final row in topics.take(40)) {
      final topic = _id(row, 'topic');
      anchors.putIfAbsent(
        topic,
        () => _Anchor(topic, _value(row, 'topicLabel'), topic == root ? 0 : 1),
      );
      if (row['subject'] != null) {
        final subject = _id(row, 'subject');
        final distance = topic == root ? 1 : 2;
        if (!anchors.containsKey(subject) ||
            distance < anchors[subject]!.distance) {
          anchors[subject] = _Anchor(
            subject,
            _value(row, 'subjectLabel'),
            distance,
          );
        }
      }
    }

    final groups = <String, _Group>{};
    final concepts = <String, _Concept>{};
    for (final anchor in anchors.values) {
      log?.call('Recuperando relaciones: ${anchor.label} (${anchor.id}).');
      // Each item must carry a contextual edge, independently of its class.
      // Types/occupations define facets, not arbitrary chunks of 20 items.
      final rows = await source.query('''
SELECT DISTINCT ?item ?itemLabel ?relation ?group ?groupLabel ?kind WHERE {
  VALUES ?relation { wdt:P361 wdt:P1269 wdt:P2348 wdt:P921
                     wdt:P101 wdt:P17 wdt:P27 wdt:P495 }
  ?item ?relation wd:${anchor.id} .
  VALUES ?kind { wdt:P31 wdt:P106 }
  ?item ?kind ?group .
  FILTER(?item != wd:$root)
  FILTER(?group != wd:Q5)
  SERVICE wikibase:label { bd:serviceParam wikibase:language "es,en". }
} LIMIT 4001
''');
      (report['anchors'] as List).add({
        'id': anchor.id,
        'label': anchor.label,
        'distance': anchor.distance,
        'rows': math.min(rows.length, 4000),
        'truncated': rows.length > 4000,
      });
      if (rows.length > 4000) {
        log?.call(
          'Límite de 4000 filas alcanzado para ${anchor.label}; '
          'la selección utiliza una muestra acotada.',
        );
      }
      for (final row in rows.take(4000)) {
        // Wikidata can return non-item subjects or malformed identifiers.
        // Skip those individual bindings instead of aborting the catalog.
        final itemId = _value(row, 'item').split('/').last;
        final groupIdValue = _value(row, 'group').split('/').last;
        if (!_isQid(itemId) || !_isQid(groupIdValue)) {
          report['invalidIdentifierRows'] =
              (report['invalidIdentifierRows'] as int? ?? 0) + 1;
          continue;
        }
        final id = itemId, groupId = groupIdValue;
        final label = _value(row, 'itemLabel');
        final groupLabel = _value(row, 'groupLabel');
        if (!_hasLabel(label, id) || !_hasLabel(groupLabel, groupId)) continue;
        if (anchors.containsKey(id)) continue;
        final concept = concepts.putIfAbsent(
          id,
          () => _Concept(id, label, int.tryParse(_value(row, 'links')) ?? 0),
        );
        concept.distance = math.min(concept.distance, anchor.distance + 1);
        concept.evidence.add(
          '${anchor.id}/${_value(row, 'relation').split('/').last}',
        );
        final group = groups.putIfAbsent(
          groupId,
          () => _Group(groupId, groupLabel),
        );
        group.members[id] = concept;
        group.kinds.add(_value(row, 'kind').split('/').last);
      }
    }
    report['candidateCount'] = concepts.length;

    // Prefer specific (smaller) viable facets; reject near-identical facets by
    // overlap relative to the smaller facet. Global QID AND normalized-label uniqueness is stricter
    // than SemanticCatalog's per-pivot validation. Greedy selection is bounded
    // and may fail even when a larger graph could admit a complete catalog.
    final viable = groups.values.where((g) => g.members.length >= 20).toList()
      ..sort((a, b) {
        final size = a.members.length.compareTo(b.members.length);
        return size != 0 ? size : a.id.compareTo(b.id);
      });
    report['groups'] = [
      for (final g
          in (groups.values.toList()
            ..sort((a, b) => b.members.length.compareTo(a.members.length))))
        {'id': g.id, 'label': g.label, 'candidates': g.members.length},
    ];
    final selectedGroups = <_Group>[];
    final usedIds = <String>{}, usedNames = <String>{}, pivotNames = <String>{};
    final pivots = <Map<String, dynamic>>[];
    for (final group in viable) {
      if (pivotNames.contains(_normalize(group.label))) continue;
      if (selectedGroups.any((other) {
        final a = group.members.keys.toSet(), b = other.members.keys.toSet();
        return a.intersection(b).length / math.min(a.length, b.length) >= 0.65;
      })) {
        continue;
      }
      final members = group.members.values.toList()..sort(_compareConcepts);
      final chosen = <_Concept>[];
      final localNames = <String>{};
      for (final item in members) {
        if (usedIds.contains(item.id) ||
            usedNames.contains(_normalize(item.label))) {
          continue;
        }
        if (!localNames.add(_normalize(item.label))) continue;
        chosen.add(item);
        if (chosen.length == 20) break;
      }
      if (chosen.length != 20) continue;
      selectedGroups.add(group);
      pivotNames.add(_normalize(group.label));
      usedIds.addAll(chosen.map((c) => c.id));
      usedNames.addAll(chosen.map((c) => _normalize(c.label)));
      pivots.add({
        'name': group.label,
        'attractors': [for (final c in chosen) c.label],
      });
      (report['selected'] as List).add({
        'id': group.id,
        'name': group.label,
        'membershipProperties': group.kinds.toList()..sort(),
        'attractors': [
          for (final c in chosen)
            {
              'id': c.id,
              'name': c.label,
              'distance': c.distance,
              'contextEdges': c.evidence.toList()..sort(),
              'sitelinks': c.links,
            },
        ],
      });
      if (pivots.length == 10) break;
    }
    report['partialCatalog'] = {'context': context, 'pivots': pivots};
    report['validPivots'] = pivots.length;
    report['validAttractors'] = usedIds.length;
    if (pivots.length != 10) {
      throw CatalogUnavailable(
        'Cobertura insuficiente: ${pivots.length}/10 pivotes completos y '
        '${usedIds.length}/200 atractores distintos; ${concepts.length} conceptos '
        'recuperados. No se completan posiciones artificialmente.',
      );
    }
    final catalog = SemanticCatalog.fromJson(report['partialCatalog']);
    report['status'] = 'complete';
    report.remove('partialCatalog');
    return catalog;
  }
}

final class CatalogUnavailable implements Exception {
  const CatalogUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

final class _Anchor {
  const _Anchor(this.id, this.label, this.distance);
  final String id, label;
  final int distance;
}

final class _Group {
  _Group(this.id, this.label);
  final String id, label;
  final members = <String, _Concept>{};
  final kinds = <String>{};
}

final class _Concept {
  _Concept(this.id, this.label, this.links);
  final String id, label;
  final int links;
  int distance = 999;
  final evidence = <String>{};
}

int _compareConcepts(_Concept a, _Concept b) {
  var result = a.distance.compareTo(b.distance);
  if (result == 0) result = b.evidence.length.compareTo(a.evidence.length);
  if (result == 0) result = b.links.compareTo(a.links);
  return result == 0 ? a.id.compareTo(b.id) : result;
}

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
Set<String> _tokens(String value) =>
    _normalize(value)
        .split(RegExp(r'[^a-záéíóúüñ0-9]+'))
        .where((s) => s.isNotEmpty)
        .toSet();
bool _hasLabel(String label, String id) =>
    label.trim().isNotEmpty && label != id;
String _value(Map<String, dynamic> row, String key) =>
    (row[key] as Map?)?['value'] as String? ?? '';
String _id(Map<String, dynamic> row, String key) =>
    _qid(_value(row, key).split('/').last);
bool _isQid(String value) => RegExp(r'^Q[1-9][0-9]*
  if (!RegExp(r'^Q[1-9][0-9]*$').hasMatch(value)) {
    throw const FormatException('QID de Wikidata inválido.');
  }
  return value;
}
).hasMatch(value);

String _qid(String value) {
  if (!RegExp(r'^Q[1-9][0-9]*$').hasMatch(value)) {
    throw const FormatException('QID de Wikidata inválido.');
  }
  return value;
}
