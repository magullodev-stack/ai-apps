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
          'Afinidad local eje-pivote-contexto por evidencia y distancia de los conceptos; propiedad como desempate.',
      'limits': {'topics': 40, 'rowsPerChunk': 500, 'chunksPerAnchor': 4},
      'grouping':
          'Núcleos contextuales tipados por P31; ejes inferidos de predicados documentados sobre sus miembros.',
      'anchors': <Map<String, dynamic>>[],
      'invalidIdentifierRows': 0,
      'failedChunks': 0,
      'groups': <Map<String, dynamic>>[],
      'selected': <Map<String, dynamic>>[],
      'partialAxes': <Map<String, dynamic>>[],
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
      // Retrieve bounded chunks instead of one expensive global join.
      // A failed chunk does not discard data from other relations.
      const relationPairs = <String>[
        'P361 P1269', 'P2348 P921',
        'P101 P17', 'P27 P495',
      ];
      final rows = <Map<String, dynamic>>[];
      var failedChunks = 0;
      for (final pair in relationPairs) {
        final values = pair.split(' ').map((p) => 'wdt:$p').join(' ');
        log?.call('  Consultando relaciones $pair de ${anchor.label}...');
        try {
          final chunk = await source.query('''
SELECT DISTINCT ?item ?itemLabel ?relation ?group ?groupLabel ?kind WHERE {
  VALUES ?relation { $values }
  ?item ?relation wd:${anchor.id} .
  ?item wdt:P31 ?group .
  BIND(wdt:P31 AS ?kind)
  FILTER(?item != wd:$root)
  FILTER(?group != wd:Q5)
  SERVICE wikibase:label { bd:serviceParam wikibase:language "es,en". }
} LIMIT 501
''');
          rows.addAll(chunk.take(500));
        } on Exception catch (error) {
          failedChunks++;
          log?.call('  Consulta $pair omitida: $error');
        }
      }
      (report['anchors'] as List).add({
        'id': anchor.id,
        'label': anchor.label,
        'distance': anchor.distance,
        'rows': rows.length,
        'failedChunks': failedChunks,
      });
      report['failedChunks'] =
          (report['failedChunks'] as int? ?? 0) + failedChunks;
      log?.call('  ${anchor.label}: ${rows.length} filas recuperadas.');
      for (final row in rows) {
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

    // Classes index candidate neighborhoods only. They are never emitted
    // as attractors, and candidate lists must not leak into the ten-pivot UI.
    final viable = groups.values.where((g) => g.members.length >= 10).toList()
      ..sort((a, b) => b.members.length.compareTo(a.members.length));
    final namedCandidates = viable.take(50).toList();
    final spanishLabels = await source.spanishLabels(
      namedCandidates.map((g) => g.id).toList(),
    );
    final candidates = namedCandidates
        .where((g) =>
            spanishLabels.containsKey(g.id) &&
            !_isUnrelatedBiographicalClass(spanishLabels[g.id]!, context))
        .toList()
      ..sort((a, b) {
        final left = _contextualPivotScore(
          spanishLabels[a.id]!,
          context,
          a.members.length,
        );
        final right = _contextualPivotScore(
          spanishLabels[b.id]!,
          context,
          b.members.length,
        );
        final result = right.compareTo(left);
        return result != 0 ? result : a.id.compareTo(b.id);
      });
    report['groups'] = [
      for (final group in namedCandidates)
        {
          'id': group.id,
          'spanishName': spanishLabels[group.id],
          'members': group.members.length,
        },
    ];
    report['excludedWithoutSpanishLabel'] =
        namedCandidates.length - spanishLabels.length;

    final selectedGroups = <_Group>[];
    final selectedAxisFields = <Set<String>>[];
    final pivotNames = <String>{};
    final pivots = <Map<String, dynamic>>[];
    final partialAxes = report['partialAxes'] as List;
    final diagnostics = <Map<String, dynamic>>[];
    var totalAxes = 0;
    var observedAxes = 0;

    // We *select ten pivots*, not 24. Their attractor windows may contain
    // fewer than twenty axes; the strict 10x20 contract remains unchanged.
    for (final group in candidates.take(24)) {
      if (partialAxes.length == 10) break;
      final pivotName = spanishLabels[group.id]!;
      if (pivotNames.contains(_normalize(pivotName))) continue;
      if (selectedGroups.any((other) {
        final a = group.members.keys.toSet();
        final b = other.members.keys.toSet();
        return a.intersection(b).length / math.min(a.length, b.length) >= 0.65;
      })) {
        continue;
      }

      final members = group.members.values.toList()..sort(_compareConcepts);
      final sampled = members.take(30).toList();
      log?.call('Analizando ejes: $pivotName (${sampled.length} conceptos).');
      Map<String, dynamic> facts;
      try {
        facts = await source.claims(sampled.map((e) => e.id).toList());
      } on Exception catch (error) {
        log?.call('  Sin hechos para $pivotName: $error');
        diagnostics.add({'pivot': pivotName, 'error': '$error'});
        continue;
      }

      final axes = <String, _SemanticAxis>{};
      for (final concept in sampled) {
        final entity = facts[concept.id];
        if (entity is! Map) continue;
        final claims = entity['claims'];
        if (claims is! Map) continue;
        for (final entry in claims.entries) {
          final property = entry.key.toString();
          final stem = _semanticPredicates[property];
          if (stem == null || entry.value is! List) continue;
          final statements = entry.value as List;
          final evidenced = statements.any((statement) =>
              statement is Map &&
              statement['rank'] != 'deprecated' &&
              statement['mainsnak'] is Map &&
              (statement['mainsnak'] as Map)['snaktype'] == 'value');
          if (!evidenced) continue;
          final axis = axes.putIfAbsent(
            property,
            () => _SemanticAxis(property, stem),
          );
          if (axis.evidence.add(concept.id)) {
            axis.proximity +=
                1.0 / (1 + concept.distance) +
                0.10 * concept.evidence.length;
          }
        }
      }

      final ranked = axes.values.toList()
        ..sort((a, b) {
          var cmp = b.proximity.compareTo(a.proximity);
          if (cmp != 0) return cmp;
          cmp = b.evidence.length.compareTo(a.evidence.length);
          return cmp != 0 ? cmp : a.property.compareTo(b.property);
        });

      // No pivot suffix. Axes are unique inside each pivot, while an axis
      // may recur in a different thematic field with different evidence.
      final chosen = <_SemanticAxis>[];
      final localNames = <String>{};
      for (final axis in ranked) {
        final name = _normalize(axis.name);
        if (!localNames.add(name)) continue;
        chosen.add(axis);
        if (chosen.length == 20) break;
      }
      diagnostics.add({
        'pivot': pivotName,
        'memberCount': group.members.length,
        'sampledNodes': sampled.length,
        'candidateAxes': ranked.length,
        'availableAfterDeduplication': chosen.length,
      });
      if (chosen.isEmpty) continue;
      final field = chosen.map((axis) => _normalize(axis.name)).toSet();
      if (selectedAxisFields.any((existing) =>
          existing.intersection(field).length /
              math.min(existing.length, field.length) >=
          0.85)) {
        // A near-identical field is not another local exploration pivot.
        continue;
      }

      selectedGroups.add(group);
      selectedAxisFields.add(field);
      pivotNames.add(_normalize(pivotName));
      observedAxes += chosen.length;
      partialAxes.add({
        'name': pivotName,
        'attractors': [for (final axis in chosen) axis.name],
      });
      if (chosen.length != 20) {
        log?.call(
          '  $pivotName: ${chosen.length} ejes documentados; '
          'no se completan los restantes artificialmente.',
        );
        continue;
      }
      pivots.add({
        'name': pivotName,
        'attractors': [for (final axis in chosen) axis.name],
      });
      totalAxes += chosen.length;
      (report['selected'] as List).add({
        'name': pivotName,
        'id': group.id,
        'attractors': [
          for (final axis in chosen)
            {
              'name': axis.name,
              'predicate': axis.property,
              'contextualProximity': axis.proximity,
              'evidenceQids': axis.evidence.toList()..sort(),
            },
        ],
      });
      log?.call('  Pivote completo: $pivotName (20 ejes).');
    }
    report['diagnostics'] = diagnostics;
    report['observedPivots'] = partialAxes.length;
    report['observedAxes'] = observedAxes;
    report['partialCatalog'] = {'context': context, 'pivots': pivots};
    report['validPivots'] = pivots.length;
    report['validAttractors'] = totalAxes;
    if (pivots.length != 10) {
      throw CatalogUnavailable(
        'Cobertura insuficiente: ${pivots.length}/10 pivotes completos y '
        '${totalAxes}/200 atractores distintos; ${concepts.length} conceptos '
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

// This safeguard is domain-neutral: biographical ontology classes are
// not thematic pivots unless the requested context itself concerns people.
bool _isUnrelatedBiographicalClass(String label, String context) {
  final aboutPeople = RegExp(
    r'persona|humano|personaje|biograf|genealog|ficci[oó]n|legend',
    caseSensitive: false,
  ).hasMatch(context);
  if (aboutPeople) return false;
  return RegExp(
    r'ser humano|human being|prosopogr[aá]f|fantasma|'
    r'personaje|fictional human|fictici[oa]|'
    r'cognomen|car[aá]cter unicode',
    caseSensitive: false,
  ).hasMatch(label);
}

double _contextualPivotScore(String label, String context, int members) {
  final contextWords =
      _tokens(context).where((word) => word.length >= 4).toList();
  final pivotWords =
      _tokens(label).where((word) => word.length >= 4).toList();
  final localMatch = pivotWords.where((word) =>
      contextWords.any((term) =>
          term.substring(0, 4) == word.substring(0, 4))).length;
  return localMatch * 100 + math.log(members + 1);
}

final class _SemanticAxis {
  _SemanticAxis(this.property, this.name);

  final String property;
  final String name;
  final evidence = <String>{};
  double proximity = 0;
}

/// Relations are semantic *evidence types*, not the 44 factual dimensions.
/// Each visible axis needs at least one non-deprecated Wikidata statement.
const _semanticPredicates = <String, String>{
  'P17': 'Ámbito político-territorial',
  'P19': 'Origen geográfico',
  'P20': 'Lugar de finalización biográfica',
  'P21': 'Distribución por género',
  'P22': 'Relaciones de ascendencia paterna',
  'P25': 'Relaciones de ascendencia materna',
  'P26': 'Vínculos conyugales',
  'P27': 'Régimen de ciudadanía',
  'P30': 'Alcance continental',
  'P36': 'Centralidad administrativa',
  'P39': 'Ejercicio de cargos',
  'P40': 'Relaciones de descendencia',
  'P47': 'Configuración de fronteras',
  'P50': 'Autoría y transmisión escrita',
  'P54': 'Adscripción colectiva',
  'P69': 'Formación y aprendizaje',
  'P101': 'Ámbitos de actividad',
  'P102': 'Adscripción política',
  'P103': 'Transmisión lingüística',
  'P106': 'Especialización de funciones',
  'P108': 'Relaciones de trabajo',
  'P110': 'Producción ilustrativa',
  'P112': 'Procesos fundacionales',
  'P123': 'Publicación y difusión',
  'P127': 'Relaciones de propiedad',
  'P131': 'Dependencia territorial',
  'P136': 'Formas y géneros culturales',
  'P137': 'Modos de operación',
  'P138': 'Origen de las denominaciones',
  'P140': 'Prácticas religiosas',
  'P141': 'Integración administrativa',
  'P150': 'Subdivisiones territoriales',
  'P155': 'Antecedentes y sucesiones',
  'P156': 'Continuidad y transformación',
  'P159': 'Centros de coordinación',
  'P161': 'Interpretación y representación',
  'P162': 'Producción y organización',
  'P166': 'Reconocimiento y distinciones',
  'P170': 'Creación y autoría material',
  'P176': 'Manufactura y producción',
  'P178': 'Desarrollo técnico',
  'P180': 'Representaciones simbólicas',
  'P186': 'Materiales y recursos',
  'P195': 'Conservación y colecciones',
  'P206': 'Relaciones hidrográficas',
  'P209': 'Liderazgo institucional',
  'P241': 'Servicio y adscripción militar',
  'P264': 'Edición y distribución',
  'P276': 'Localización espacial',
  'P279': 'Jerarquía conceptual',
  'P286': 'Uso de tecnologías',
  'P287': 'Diseño y desarrollo',
  'P289': 'Medios de navegación',
  'P355': 'Articulación organizativa',
  'P361': 'Relaciones entre partes y conjuntos',
  'P366': 'Usos y funciones',
  'P371': 'Institucionalización y funcionamiento',
  'P407': 'Lenguas de transmisión',
  'P449': 'Medios de difusión',
  'P463': 'Participación en organizaciones',
  'P466': 'Ocupación y utilización',
  'P495': 'Procedencia cultural y territorial',
  'P496': 'Identificación científica',
  'P509': 'Causas de mortalidad',
  'P527': 'Composición y componentes',
  'P551': 'Residencia y asentamientos',
  'P569': 'Cronología biográfica inicial',
  'P570': 'Cronología biográfica final',
  'P571': 'Formación y aparición',
  'P576': 'Desaparición y disolución',
  'P580': 'Inicio de periodos y procesos',
  'P582': 'Finalización de periodos y procesos',
  'P585': 'Datación de acontecimientos',
  'P607': 'Participación en conflictos',
  'P625': 'Distribución geográfica',
  'P637': 'Producción e inspiración',
  'P641': 'Prácticas deportivas',
  'P674': 'Representación de personajes',
  'P676': 'Composición musical',
  'P706': 'Situación geomorfológica',
  'P710': 'Agentes participantes',
  'P734': 'Organización familiar',
  'P737': 'Influencias y precedentes',
  'P740': 'Lugares de formación',
  'P749': 'Organización jerárquica',
  'P793': 'Acontecimientos significativos',
  'P800': 'Producción destacada',
  'P807': 'Resultados de conflictos',
  'P828': 'Relaciones causales',
  'P840': 'Ambientación y representación',
  'P915': 'Escenarios espaciales',
  'P921': 'Temas y ámbitos de estudio',
  'P937': 'Ámbitos laborales',
  'P941': 'Factores inspiradores',
  'P971': 'Entidades de agrupación',
  'P1001': 'Ámbito jurisdiccional',
  'P1037': 'Funciones de dirección',
  'P1056': 'Resultados de producción',
  'P1196': 'Circunstancias de fallecimiento',
  'P1269': 'Dimensiones históricas y temáticas',
  'P1317': 'Estamentos e instituciones',
  'P1344': 'Participación en eventos',
  'P1412': 'Diversidad lingüística',
  'P1435': 'Protección patrimonial',
  'P1448': 'Denominaciones oficiales',
  'P1532': 'Territorios de influencia',
  'P1542': 'Relaciones causales posteriores',
  'P1875': 'Representaciones artísticas',
  'P2348': 'Vinculación con épocas',
  'P2541': 'Zona de actuación',
  'P2579': 'Ámbitos de investigación',
  'P2770': 'Procedencia de la herencia',
  'P2868': 'Funciones del sujeto',
  'P3018': 'Términos de vigencia',
  'P3612': 'Organización de grupos',
  'P5274': 'Configuración jerárquica',
};

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
bool _isQid(String value) => RegExp(r'^Q[1-9][0-9]*$').hasMatch(value);

String _qid(String value) {
  if (!RegExp(r'^Q[1-9][0-9]*$').hasMatch(value)) {
    throw const FormatException('QID de Wikidata inválido.');
  }
  return value;
}
