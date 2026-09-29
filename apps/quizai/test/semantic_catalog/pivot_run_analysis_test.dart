import 'package:flutter_test/flutter_test.dart';
import '../../tool/generar_pivotes.dart';

const _sample = '''
| Pivote | Atractor 1 | Atractor 2 | Atractor 3 | Atractor 4 | Atractor 5 |
|---|---|---|---|---|---|
| Ciencias naturales | Química | Orgánica | Hidrocarburos | Aromáticos | Benceno |
| Ciencias formales | Matemáticas | Álgebra | Lineal | Matrices | Determinantes |
| Ciencias sociales | Economía | Macro | Inflación | Precios | IPC |
| Historia | Antigua | Grecia | Clásica | Guerras | Egospótamos |
| Humanidades | Filosofía | Ética | Normativa | Deontología | Principios |
| Tecnología e ingeniería | Informática | IA | Aprendizaje | Redes | Transformers |
| Artes | Música | Armonía | Acordes | Séptima | Dominante |
| Salud y medicina | Medicina | Neurología | Parkinson | Síntomas | Temblor |
''';

void main() {
  test('analiza ocho rutas y cinco atractores por ruta', () {
    final result = parseExpansionTable(_sample);
    expect(result.length, 8);
    expect(result['Historia']!.length, 5);
  });
  test('reconoce repeticiones exactas sin contar el ejemplo fijo', () {
    final table = parseExpansionTable(_sample);
    final result = compareExpansionTables([table, table]);
    expect(result, contains('7 de 14 generados'));
    expect(result, contains('| Historia | 1 | 1 | 1 | 1 | 1 | 1 |'));
  });
  test('detecta divergencia desde el segundo atractor', () {
    final a = parseExpansionTable(_sample);
    final b = parseExpansionTable(_sample.replaceFirst(
      'Matemáticas | Álgebra | Lineal | Matrices | Determinantes',
      'Matemáticas | Geometría | Euclidiana | Triángulos | Pitágoras',
    ));
    expect(
      compareExpansionTables([a, b]),
      contains('| Ciencias formales | 1 | 2 | 2 | 2 | 2 | 0 |'),
    );
  });
  test('rechaza alteraciones en el ejemplo y rutas incompletas', () {
    expect(
      () => parseExpansionTable(_sample.replaceFirst(
        'Orgánica | Hidrocarburos', 'Inorgánica | Hidrocarburos',
      )),
      throwsFormatException,
    );
    expect(
      () => parseExpansionTable(_sample.replaceFirst(
        'Matemáticas | Álgebra | Lineal | Matrices | Determinantes',
        'Matemáticas | Álgebra | Lineal | Matrices |',
      )),
      throwsFormatException,
    );
  });
}
