import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/semantic_catalog/semantic_catalog.dart';

import 'fixtures.dart';

void main() {
  test('conserva contexto, nombres y orden; deriva todos los códigos', () {
    const context = '  Historia y ciencia\ncon perspectiva local.  ';
    final catalog = SemanticCatalog.fromJson(catalogJson(context));
    expect(catalog.context, context);
    expect(catalog.pivots, hasLength(10));
    for (var p = 0; p < 10; p++) {
      final pivot = catalog.pivots[p];
      expect(pivot.code, 'P${(p + 1).toString().padLeft(2, '0')}');
      expect(pivot.name, 'Pivote ${p + 1}');
      expect(pivot.attractors, hasLength(20));
      for (var a = 0; a < 20; a++) {
        expect(
          pivot.attractors[a].code,
          'A${(a + 1).toString().padLeft(2, '0')}',
        );
        expect(pivot.attractors[a].name, 'Eje ${p + 1} ${20 - a}');
      }
    }
  });

  test('listas inmutables y aisladas de los datos de entrada', () {
    final data = catalogJson();
    final catalog = SemanticCatalog.fromJson(data);
    data['pivots'][0]['attractors'][0] = 'Modificado';
    data['pivots'].clear();
    expect(catalog.pivots, hasLength(10));
    expect(catalog.pivots.first.attractors.first.name, 'Eje 1 20');
    expect(() => catalog.pivots.clear(), throwsUnsupportedError);
    expect(
      () => catalog.pivots.first.attractors.clear(),
      throwsUnsupportedError,
    );
  });

  final invalidChanges = <String, void Function(Map<String, dynamic>)>{
    'sin contexto': (data) => data.remove('context'),
    'contexto vacío': (data) => data['context'] = ' \n\t ',
    'contexto no textual': (data) => data['context'] = 4,
    'sin pivotes': (data) => data.remove('pivots'),
    'pivotes nulos': (data) => data['pivots'] = null,
    'pivotes no lista': (data) => data['pivots'] = {},
    'nueve pivotes': (data) => data['pivots'].removeLast(),
    'once pivotes': (data) => data['pivots'].add(data['pivots'][0]),
    'pivote malformado': (data) => data['pivots'][0] = 'Pivote',
    'sin nombre': (data) => data['pivots'][0].remove('name'),
    'nombre vacío': (data) => data['pivots'][0]['name'] = ' \t ',
    'nombre no textual': (data) => data['pivots'][0]['name'] = false,
    'pivotes duplicados': (data) => data['pivots'][1]['name'] = 'Pivote 1',
    'pivotes duplicados normalizados': (data) =>
        data['pivots'][1]['name'] = '  PIVOTE\t  1  ',
    'sin atractores': (data) => data['pivots'][0].remove('attractors'),
    'atractores no lista': (data) => data['pivots'][0]['attractors'] = {},
    'diecinueve atractores': (data) =>
        data['pivots'][0]['attractors'].removeLast(),
    'veintiún atractores': (data) =>
        data['pivots'][0]['attractors'].add('Extra'),
    'atractor vacío': (data) => data['pivots'][0]['attractors'][0] = ' \n ',
    'atractor nulo': (data) => data['pivots'][0]['attractors'][0] = null,
    'atractor objeto': (data) =>
        data['pivots'][0]['attractors'][0] = {'name': 'Eje'},
    'atractores duplicados': (data) =>
        data['pivots'][0]['attractors'][1] = 'Eje 1 20',
    'atractores duplicados normalizados': (data) =>
        data['pivots'][0]['attractors'][19] = '  EJE\n 1\t20 ',
    'propiedad extra raíz': (data) => data['extra'] = true,
    'propiedad extra pivote': (data) => data['pivots'][0]['code'] = 'P01',
    'último pivote incompleto': (data) =>
        data['pivots'][9]['attractors'].clear(),
  };
  for (final entry in invalidChanges.entries) {
    test('rechaza ${entry.key}', () {
      final data = catalogJson();
      entry.value(data);
      expect(() => SemanticCatalog.fromJson(data), throwsFormatException);
    });
  }

  test('rechaza raíces malformadas', () {
    for (final value in [null, [], 'texto', 42, true]) {
      expect(() => SemanticCatalog.fromJson(value), throwsFormatException);
    }
  });

  test('un mismo nombre en campos distintos no implica duplicación local', () {
    final data = catalogJson();
    data['pivots'][1]['attractors'][0] = data['pivots'][0]['attractors'][0];
    expect(SemanticCatalog.fromJson(data).pivots, hasLength(10));
  });

  test(
    'el consumidor puede sustituir IA por un proveedor cerrado simulado',
    () async {
      final SemanticCatalogGenerator generator = _ClosedCatalogGenerator();
      final catalog = await generator.generateCatalog('Contexto cerrado');
      expect(catalog.context, 'Contexto cerrado');
      expect(catalog.pivots, hasLength(10));
    },
  );
}

class _ClosedCatalogGenerator implements SemanticCatalogGenerator {
  @override
  Future<SemanticCatalog> generateCatalog(String context) async =>
      SemanticCatalog.fromJson(catalogJson(context));
}
