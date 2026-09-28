import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/semantic_catalog/algorithmic_semantic_catalog_generator.dart';
import 'package:quizai/semantic_catalog/wikidata_catalog_source.dart';

// Offline source fixtures: classes index local neighborhoods, but actual
// attractor labels come exclusively from documented fact predicates.
void main() {
  test('generates 10 by 20 axes, never labels of individual entities', () async {
    final generator = _generator();
    final catalog = await generator.generateCatalog(' Contexto ');
    expect(catalog.context, ' Contexto ');
    expect(catalog.pivots, hasLength(10));
    final names = catalog.pivots
        .expand((p) => p.attractors)
        .map((a) => a.name)
        .toList();
    expect(names, hasLength(200));
    expect(names.toSet(), hasLength(200));
    expect(names, everyElement(isNot(contains('Entidad'))));
    expect(names, everyElement(isNot(contains('Q1000'))));
    expect(names.first, contains(' · Ámbito '));
    expect(generator.report['status'], 'complete');
    expect(generator.report['validAttractors'], 200);
    final selected = generator.report['selected'] as List;
    expect((selected.first as Map)['attractors'], hasLength(20));
    expect(
      (((selected.first as Map)['attractors'] as List).first as Map)
          .containsKey('evidenceQids'),
      isTrue,
    );
  });

  test('does not manufacture the twentieth axis when evidence has 19', () async {
    final generator = _generator(axisCount: 19);
    await expectLater(
      generator.generateCatalog('Contexto'),
      throwsA(isA<CatalogUnavailable>()),
    );
    expect(generator.report['validPivots'], 0);
    expect(generator.report['validAttractors'], 0);
    expect(generator.report['status'], 'incomplete');
    final partial = generator.report['partialAxes'] as List;
    expect(partial, hasLength(10));
    expect((partial.first as Map)['attractors'], hasLength(19));
  });

  test('skips invalid non-QID bindings instead of aborting the graph', () async {
    final generator = _generator(includeInvalidRow: true);
    final catalog = await generator.generateCatalog('Contexto');
    expect(catalog.pivots, hasLength(10));
    expect(generator.report['invalidIdentifierRows'], greaterThan(0));
  });

  test('rejects an empty context before contacting the source', () async {
    var requests = 0;
    final generator = AlgorithmicSemanticCatalogGenerator(
      source: WikidataCatalogSource(
        readJson: (_) async {
          requests++;
          return {};
        },
      ),
    );
    await expectLater(generator.generateCatalog(' '), throwsArgumentError);
    expect(requests, 0);
  });

  test('rejects untrusted QIDs before interpolation in SPARQL', () async {
    final generator = AlgorithmicSemanticCatalogGenerator(
      source: WikidataCatalogSource(
        readJson: (_) async => {
          'search': [
            {'id': 'Q1 } UNION {', 'label': 'Contexto'},
          ],
        },
      ),
    );
    await expectLater(
      generator.generateCatalog('Contexto'),
      throwsFormatException,
    );
  });

  test('resets the report when a later request fails', () async {
    var fail = false;
    final generator = _generator(fail: () => fail);
    await generator.generateCatalog('Contexto');
    fail = true;
    await expectLater(
      generator.generateCatalog('Contexto'),
      throwsA(isA<SocketException>()),
    );
    expect(generator.report['status'], 'incomplete');
    expect(generator.report['selected'], isEmpty);
  });
}

const _predicates = [
  'P17', 'P19', 'P20', 'P27', 'P30',
  'P36', 'P39', 'P50', 'P101', 'P112',
  'P131', 'P136', 'P150', 'P155', 'P156',
  'P159', 'P170', 'P176', 'P186', 'P276',
];

AlgorithmicSemanticCatalogGenerator _generator({
  int axisCount = 20,
  bool includeInvalidRow = false,
  bool Function()? fail,
}) {
  return AlgorithmicSemanticCatalogGenerator(
    source: WikidataCatalogSource(
      readJson: (uri) async {
        if (fail?.call() ?? false) throw const SocketException('offline');
        final action = uri.queryParameters['action'];
        if (action == 'wbsearchentities') {
          return {
            'search': [
              {'id': 'Q1', 'label': 'Contexto'},
            ],
          };
        }
        if (action == 'wbgetentities') {
          final ids = uri.queryParameters['ids']!.split('|');
          return {
            'entities': {
              for (final id in ids)
                id: {
                  'claims': {
                    for (final property in _predicates.take(axisCount))
                      property: [
                        {
                          'rank': 'normal',
                          'mainsnak': {'snaktype': 'value'},
                        },
                      ],
                  },
                },
            },
          };
        }
        final query = uri.queryParameters['query']!;
        return {
          'results': {
            'bindings': query.contains('SELECT DISTINCT ?topic')
                ? <Map<String, dynamic>>[]
                : [
                    for (var p = 0; p < 10; p++)
                      for (var i = 0; i < 30; i++)
                        {
                          'item': _binding(
                            'http://www.wikidata.org/entity/Q${1000 + p * 30 + i}',
                          ),
                          'itemLabel': _binding('Entidad $p $i'),
                          'relation': _binding(
                            'http://www.wikidata.org/prop/direct/P361',
                          ),
                          'group': _binding(
                            'http://www.wikidata.org/entity/Q${501 + p}',
                          ),
                          'groupLabel': _binding('Ámbito $p'),
                          'kind': _binding(
                            'http://www.wikidata.org/prop/direct/P31',
                          ),
                        },
                    if (includeInvalidRow)
                      {
                        'item': _binding('not-an-entity'),
                        'itemLabel': _binding('Dato corrupto'),
                        'group': _binding(
                          'http://www.wikidata.org/entity/Q999',
                        ),
                        'groupLabel': _binding('Grupo inválido'),
                      },
                  ],
          },
        };
      },
    ),
  );
}

Map<String, String> _binding(String value) => {'value': value};
