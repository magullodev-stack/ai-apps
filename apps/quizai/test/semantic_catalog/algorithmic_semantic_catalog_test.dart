import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/semantic_catalog/algorithmic_semantic_catalog_generator.dart';
import 'package:quizai/semantic_catalog/wikidata_catalog_source.dart';

// Synthetic unit fixtures only; the CLI always uses the live HTTP source.
void main() {
  test(
    'returns the existing contract, graph ranking and 200 unique IDs',
    () async {
      final rows = _rows();
      rows[0]['links'] = _binding('999');
      final generator = _generator(rows.reversed.toList());
      final catalog = await generator.generateCatalog(' Contexto ');
      expect(catalog.context, ' Contexto ');
      expect(catalog.pivots, hasLength(10));
      expect(catalog.pivots.first.attractors.first.name, 'Concepto 0 0');
      expect(
        catalog.pivots.expand((p) => p.attractors).map((a) => a.name).toSet(),
        hasLength(200),
      );
      expect(generator.report['status'], 'complete');
      expect(generator.report['validAttractors'], 200);
    },
  );

  test(
    'does not pad a group with 19 members or return a partial catalog',
    () async {
      final generator = _generator(_rows()..removeLast());
      await expectLater(
        generator.generateCatalog('Contexto'),
        throwsA(isA<CatalogUnavailable>()),
      );
      expect(generator.report['validPivots'], 9);
      expect(generator.report['validAttractors'], 180);
      expect(generator.report['status'], 'incomplete');
    },
  );

  test(
    'deduplicates IDs, normalized labels and repeated relation rows globally',
    () async {
      final rows = _rows();
      rows[20]['itemLabel'] = _binding('  CONCEPTO   0 0 ');
      rows.add(Map.of(rows[0]));
      final generator = _generator(rows);
      await expectLater(
        generator.generateCatalog('Contexto'),
        throwsA(isA<CatalogUnavailable>()),
      );
      expect(generator.report['validAttractors'], 180);
    },
  );

  test('unlabelled QIDs cannot fill missing positions', () async {
    final rows = _rows();
    rows[0]['itemLabel'] = _binding('Q1000');
    final generator = _generator(rows);
    await expectLater(
      generator.generateCatalog('Contexto'),
      throwsA(isA<CatalogUnavailable>()),
    );
    expect(generator.report['validAttractors'], 180);
  });

  test('near-identical facets cannot count as differentiated pivots', () async {
    final rows = _rows();
    rows.removeRange(180, 200);
    for (final row in rows.take(40).toList()) {
      rows.add({
        ...row,
        'group': _binding('http://www.wikidata.org/entity/Q999'),
        'groupLabel': _binding('Grupo redundante'),
      });
    }
    final generator = _generator(rows);
    await expectLater(
      generator.generateCatalog('Contexto'),
      throwsA(isA<CatalogUnavailable>()),
    );
    expect(generator.report['validPivots'], 9);
  });

  test('empty context makes no requests', () async {
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

  test('unresolved and weak context matches fail explicitly', () async {
    for (final results in [
      <Map<String, dynamic>>[],
      [
        {'id': 'Q1', 'label': 'Otro tema'},
      ],
    ]) {
      final generator = AlgorithmicSemanticCatalogGenerator(
        source: WikidataCatalogSource(
          readJson: (_) async => {'search': results},
        ),
      );
      await expectLater(
        generator.generateCatalog('Contexto'),
        throwsA(isA<CatalogUnavailable>()),
      );
    }
  });

  test(
    'network failure propagates and does not retain previous success',
    () async {
      var fail = false;
      final generator = _generator(_rows(), fail: () => fail);
      await generator.generateCatalog('Contexto');
      fail = true;
      await expectLater(
        generator.generateCatalog('Contexto'),
        throwsA(isA<SocketException>()),
      );
      expect(generator.report['status'], 'incomplete');
      expect(generator.report['selected'], isEmpty);
    },
  );

  test('untrusted entity ID cannot be interpolated in SPARQL', () async {
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
}

AlgorithmicSemanticCatalogGenerator _generator(
  List<Map<String, dynamic>> rows, {
  bool Function()? fail,
}) => AlgorithmicSemanticCatalogGenerator(
  source: WikidataCatalogSource(
    readJson: (uri) async {
      if (fail?.call() ?? false) throw const SocketException('offline');
      if (uri.host == 'www.wikidata.org') {
        return {
          'search': [
            {'id': 'Q1', 'label': 'Contexto'},
          ],
        };
      }
      final query = uri.queryParameters['query']!;
      return {
        'results': {
          'bindings': query.contains('SELECT DISTINCT ?topic')
              ? <Map<String, dynamic>>[]
              : rows,
        },
      };
    },
  ),
);

Map<String, String> _binding(String value) => {'value': value};
List<Map<String, dynamic>> _rows() => [
  for (var p = 0; p < 10; p++)
    for (var a = 0; a < 20; a++)
      {
        'item': _binding(
          'http://www.wikidata.org/entity/Q${1000 + p * 20 + a}',
        ),
        'itemLabel': _binding('Concepto $p $a'),
        'relation': _binding('http://www.wikidata.org/prop/direct/P361'),
        'group': _binding('http://www.wikidata.org/entity/Q${100 + p}'),
        'groupLabel': _binding('Grupo $p'),
        'kind': _binding('http://www.wikidata.org/prop/direct/P31'),
        'links': _binding('$a'),
      },
];
