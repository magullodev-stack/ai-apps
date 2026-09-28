import 'semantic_catalog.dart';
import 'wikidata_catalog_source.dart';

/// Experimental, deterministic catalog built from graph relations rather than
/// P31/P106 membership lists. Never invents missing axes.
final class RelationalSemanticCatalogGenerator
    implements SemanticCatalogGenerator {
  RelationalSemanticCatalogGenerator({WikidataCatalogSource? source})
      : source = source ?? WikidataCatalogSource();

  final WikidataCatalogSource source;
  Map<String, Object?> report = {};

  @override
  Future<SemanticCatalog> generateCatalog(String context) async {
    report = {'context': context, 'status': 'incomplete'};
    if (context.trim().isEmpty) {
      throw ArgumentError('El contexto está vacío.');
    }

    final matches = await source.search(context.trim());
    final exact = matches.where((row) =>
        _norm('${row['label'] ?? ''}') == _norm(context) ||
        _norm('${(row['match'] as Map?)?['text'] ?? ''}') ==
            _norm(context));
    if (exact.isEmpty) {
      throw const FormatException(
          'El contexto no tiene una correspondencia inequívoca en Wikidata.');
    }
    final root = _qid('${exact.first['id']}');

    // A pivot is a topic with an explicit contextual link to the root.
    // A subject's Wikidata occupation or P31 category is NOT a pivot.
    final topics = await source.query('''
SELECT DISTINCT ?topic ?topicLabel WHERE {
  VALUES ?contextProperty { wdt:P361 wdt:P1269 wdt:P921 wdt:P2348 }
  ?topic ?contextProperty wd:$root .
  ?topic wikibase:sitelinks ?links .
  FILTER(?links >= 2)
  SERVICE wikibase:label { bd:serviceParam wikibase:language "es,en". }
} LIMIT 250
''');
    final pivotCandidates = <_Topic>[
      _Topic(root, '${exact.first['label']}'),
      for (final row in topics)
        if (_entityId(row, 'topic') != root &&
            _validLabel(_label(row, 'topicLabel')))
          _Topic(_entityId(row, 'topic'), _label(row, 'topicLabel')),
    ];
    final distinctTopics = <String, _Topic>{};
    for (final topic in pivotCandidates) {
      distinctTopics.putIfAbsent(topic.id, () => topic);
    }

    // The input to axis selection is a set of *relation patterns*:
    // (property, semantic type of its object). Entity names are evidence,
    // never attractor labels. E.g. (P607 conflict, military conflict) is
    // one candidate field regardless of the number of battles involved.
    final pivots = <Map<String, Object>>[];
    final usedAxes = <String>{};
    final diagnostics = <Map<String, Object?>>[];
    for (final topic in distinctTopics.values.take(40)) {
      final rows = await source.query('''
SELECT DISTINCT ?entity ?property ?valueType ?valueTypeLabel WHERE {
  VALUES ?relation { wdt:P361 wdt:P1269 wdt:P921 wdt:P2348 }
  ?entity ?relation wd:${topic.id} .
  VALUES ?p { wdt:P17 wdt:P27 wdt:P30 wdt:P36 wdt:P47
              wdt:P101 wdt:P131 wdt:P136 wdt:P150 wdt:P155
              wdt:P156 wdt:P279 wdt:P361 wdt:P463 wdt:P607
              wdt:P710 wdt:P793 wdt:P921 wdt:P1269 wdt:P2348 }
  ?entity ?p ?value .
  ?property wikibase:directClaim ?p .
  ?value wdt:P31 ?valueType .
  FILTER(?valueType != wd:Q5)
  FILTER(?p != wdt:P31 && ?p != wdt:P106)
  FILTER(isIRI(?value))
  SERVICE wikibase:label { bd:serviceParam wikibase:language "es,en". }
} LIMIT 4000
''');
      final axes = <String, _Axis>{};
      for (final row in rows) {
        final property = _propertyId(row, 'property');
        final type = _entityId(row, 'valueType');
        final typeLabel = _label(row, 'valueTypeLabel');
        if (!_validLabel(typeLabel)) continue;
        if (_excludedType(typeLabel)) continue;
        final label = _axisName(property, typeLabel);
        if (label == null) continue;
        final key = _norm(label);
        final axis = axes.putIfAbsent(key, () => _Axis(label));
        axis.entities.add(_entityId(row, 'entity'));
        axis.properties.add(property);
        axis.types.add(type);
      }
      // Evidence-based order: distinct entities supporting a pattern,
      // followed by diversity of types/properties, then lexical tie-break.
      final ranked = axes.values.toList()
        ..sort((a, b) {
          var cmp = b.entities.length.compareTo(a.entities.length);
          if (cmp != 0) return cmp;
          cmp = b.types.length.compareTo(a.types.length);
          if (cmp != 0) return cmp;
          return a.name.compareTo(b.name);
        });
      final chosen = <_Axis>[];
      for (final axis in ranked) {
        if (usedAxes.contains(_norm(axis.name))) continue;
        chosen.add(axis);
        if (chosen.length == 20) break;
      }
      diagnostics.add({
        'topic': topic.name,
        'qid': topic.id,
        'facts': rows.length,
        'candidateAxes': ranked.length,
        'selectedAxes': chosen.length,
      });
      if (chosen.length != 20) continue;
      for (final axis in chosen) {
        usedAxes.add(_norm(axis.name));
      }
      pivots.add({
        'name': topic.name,
        'attractors': [for (final axis in chosen) axis.name],
      });
      if (pivots.length == 10) break;
    }
    report = {
      'context': context,
      'status': pivots.length == 10 ? 'complete' : 'incomplete',
      'pivots': pivots,
      'diagnostics': diagnostics,
      'distinctAxes': usedAxes.length,
    };
    if (pivots.length != 10) {
      throw FormatException(
        'Solo ${pivots.length}/10 pivotes con 20 ejes distintos; '
        '${usedAxes.length}/200 atractores. No se rellenan ejes.',
      );
    }
    return SemanticCatalog.fromJson({'context': context, 'pivots': pivots});
  }
}

/// Explicit relation vocabulary. No response is generated from person names,
/// places, object names or source articles. The label of a Wikidata *type*
/// refines the exploration axis; P106 and person-as-type are excluded above.
String? _axisName(String property, String typeLabel) {
  final kind = _norm(typeLabel);
  if (kind.length < 4 || kind.length > 65) return null;
  const templates = <String, String>{
    'P17': 'Ámbito territorial',
    'P27': 'Vínculos de ciudadanía',
    'P30': 'Ámbito continental',
    'P36': 'Organización de capitales',
    'P47': 'Relaciones fronterizas',
    'P101': 'Ámbitos de actividad',
    'P131': 'Organización territorial',
    'P136': 'Manifestaciones culturales',
    'P150': 'Divisiones administrativas',
    'P155': 'Procesos de sucesión',
    'P156': 'Procesos de continuidad',
    'P279': 'Clasificación conceptual',
    'P361': 'Relaciones entre partes y conjuntos',
    'P463': 'Participación en organizaciones',
    'P607': 'Participación en conflictos',
    'P710': 'Participación en acontecimientos',
    'P793': 'Acontecimientos significativos',
    'P921': 'Ámbitos temáticos',
    'P1269': 'Dimensiones históricas',
    'P2348': 'Procesos de época',
  };
  final stem = templates[property];
  if (stem == null) return null;
  return '$stem: $kind';
}

bool _excludedType(String label) {
  final value = _norm(label);
  return const {
    'humano', 'human', 'persona', 'person', 'ser humano',
    'nombre propio', 'given name', 'apellido', 'surname',
    'nombre de pila', 'individuo', 'individual',
  }.contains(value);
}

String _norm(String value) => value.trim().toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ');
bool _validLabel(String value) => value.trim().isNotEmpty &&
    !RegExp(r'^Q[1-9][0-9]*$').hasMatch(value);
String _label(Map<String, dynamic> row, String name) =>
    (row[name] as Map?)?['value'] as String? ?? '';
String _qid(String id) {
  if (!RegExp(r'^Q[1-9][0-9]*$').hasMatch(id)) {
    throw const FormatException('QID inválido.');
  }
  return id;
}
String _propertyId(Map<String, dynamic> row, String name) {
  final id = _label(row, name).split('/').last;
  if (!RegExp(r'^P[1-9][0-9]*$').hasMatch(id)) {
    throw const FormatException('PID inválido.');
  }
  return id;
}

String _entityId(Map<String, dynamic> row, String name) =>
    _qid(_label(row, name).split('/').last);

final class _Topic {
  const _Topic(this.id, this.name);
  final String id;
  final String name;
}

final class _Axis {
  _Axis(this.name);
  final String name;
  final entities = <String>{};
  final properties = <String>{};
  final types = <String>{};
}
