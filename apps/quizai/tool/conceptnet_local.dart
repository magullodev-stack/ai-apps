import 'dart:convert';
import 'dart:io';

/// Índice local sin dependencias. Ejecutar desde apps/quizai.
const useful = <String>{
  '/r/RelatedTo', '/r/IsA', '/r/PartOf', '/r/HasA',
  '/r/UsedFor', '/r/CapableOf', '/r/AtLocation',
  '/r/HasProperty', '/r/Causes', '/r/HasPrerequisite',
  '/r/MotivatedByGoal', '/r/CreatedBy', '/r/ReceivesAction',
  '/r/DistinctFrom', '/r/Synonym',
};
const count = 128;

Future<void> main(List<String> args) async {
  final dir = Directory('../../.ai-apps/conceptnet/index');
  final input = File('../../.ai-apps/conceptnet/conceptnet-assertions-5.7.0.csv.gz');
  if (args.isEmpty) {
    stdout.writeln('Uso: dart run tool/conceptnet_local.dart build');
    stdout.writeln('     dart run tool/conceptnet_local.dart query es ejército');
    return;
  }
  if (args[0] == 'build') {
    if (!await input.exists()) {
      stderr.writeln('Archivo no encontrado: ' + input.path);
      exitCode = 1;
      return;
    }
    await dir.create(recursive: true);
    final sinks = <IOSink>[
      for (var i = 0; i < count; i++)
        File(dir.path + '/b' + i.toString().padLeft(3, '0') + '.tsv').openWrite(),
    ];
    var total = 0;
    var kept = 0;
    final clock = Stopwatch()..start();
    try {
      final stream = input.openRead().transform(gzip.decoder)
          .transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in stream) {
        total++;
        final parts = line.split('\t');
        if (parts.length < 5 || !useful.contains(parts[1])) continue;
        final a = parts[2], b = parts[3];
        final lang = _lang(a);
        if (lang == null || lang != _lang(b)) continue;
        final metadata = jsonDecode(parts[4]) as Map;
        final weight = (metadata['weight'] as num?)?.toDouble() ?? 1.0;
        _write(sinks, a, b, parts[1], weight, 'out');
        _write(sinks, b, a, parts[1], weight, 'in');
        kept++;
        if (total % 1000000 == 0) {
          stdout.writeln('Procesadas ' + total.toString() + ' líneas');
        }
      }
    } finally {
      await Future.wait(sinks.map((s) => s.close()));
    }
    clock.stop();
    stdout.writeln('Índice creado: ' + kept.toString() +
        ' relaciones, ' + clock.elapsed.inSeconds.toString() + ' segundos.');
    return;
  }
  if (args[0] == 'query' && args.length >= 3) {
    final node = '/c/' + args[1].toLowerCase() + '/' +
        args.skip(2).join('_').toLowerCase().replaceAll(' ', '_');
    final file = File(dir.path + '/b' +
        _hash(node).toString().padLeft(3, '0') + '.tsv');
    if (!await file.exists()) {
      stderr.writeln('Falta el índice. Ejecuta build primero.');
      exitCode = 1;
      return;
    }
    final hits = <({String label, String relation, double weight, String direction})>[];
    await for (final line in file.openRead().transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final p = line.split('\t');
      if (p.length != 5 || (p[0] != node && !p[0].startsWith(node + '/'))) continue;
      final segments = p[1].split('/');
      if (segments.length < 4) continue;
      hits.add((
        label: _safeDecode(segments[3]).replaceAll('_', ' '),
        relation: p[2].substring(3),
        weight: double.tryParse(p[3]) ?? 0,
        direction: p[4],
      ));
    }
    hits.sort((a, b) => b.weight.compareTo(a.weight));
    stdout.writeln(node + ': ' + hits.length.toString() + ' relaciones');
    for (final hit in hits.take(40)) {
      stdout.writeln(hit.weight.toStringAsFixed(2) + ' ' +
          hit.direction + ' ' + hit.relation + ' → ' + hit.label);
    }
    return;
  }
  stderr.writeln('Comando desconocido.');
  exitCode = 1;
}

String? _lang(String uri) {
  if (uri.startsWith('/c/es/')) return 'es';
  if (uri.startsWith('/c/en/')) return 'en';
  return null;
}

int _hash(String value) {
  var hash = 2166136261;
  for (final unit in value.codeUnits) {
    hash = ((hash ^ unit) * 16777619) & 0xffffffff;
  }
  return hash % count;
}

void _write(List<IOSink> sinks, String a, String b, String rel,
    double weight, String direction) {
  sinks[_hash(a)].writeln(
      a + '\t' + b + '\t' + rel + '\t' + weight.toString() + '\t' + direction);
}

String _safeDecode(String value) {
  try {
    return Uri.decodeComponent(value);
  } on FormatException {
    return value;
  } on ArgumentError {
    return value;
  }
}
