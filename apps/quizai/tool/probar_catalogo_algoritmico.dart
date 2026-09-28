import 'dart:convert';
import 'dart:io';

/// Experimento aislado: solo P01-P10. No modifica el contrato 10x20.
Future<void> main() async {
  stdout.write('Contexto: ');
  final context = stdin.readLineSync(encoding: utf8)?.trim() ?? '';
  if (context.isEmpty) {
    stderr.writeln('Introduce un contexto.');
    exitCode = 1;
    return;
  }
  final clock = Stopwatch()..start();
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);
  try {
    final result = await _search(client, context);
    if (result.isEmpty) throw StateError('Contexto no localizado.');
    final root = result.first;
    final sections = await _sections(client, root);
    final candidates = <_Candidate>[];
    for (final section in sections) {
      if (_irrelevant(section.name)) continue;
      if (section.level > 3) continue;
      // Prefer primary sections; nested headings have lower thematic scope.
      final score = section.level == 2 ? 100.0 : 45.0;
      candidates.add(_Candidate(section.name, score, 'sección de $root'));
    }

    // A second, small source of candidate concepts: linked article titles
    // from the root article. Unlike the previous generator, this does not
    // fetch the claims of thousands of individual entities.
    final links = await _links(client, root);
    for (final title in links) {
      if (_irrelevant(title)) continue;
      candidates.add(_Candidate(title, 20, 'enlace de $root'));
    }

    // Order by local editorial prominence and context match, not by P31.
    final normalizedContext = _norm(context);
    final words = normalizedContext
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet();
    for (final candidate in candidates) {
      final text = _norm(candidate.name);
      if (text == normalizedContext || text == _norm(root)) {
        candidate.score = -1000;
        continue;
      }
      final overlap = words.where((w) => text.contains(w)).length;
      candidate.score += overlap * 3;
      if (RegExp(r'\d{3,}|\([^)]*\)').hasMatch(candidate.name)) {
        candidate.score -= 25;
      }
      if (candidate.name.length > 65) candidate.score -= 25;
    }
    candidates.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      return cmp != 0 ? cmp : a.name.compareTo(b.name);
    });

    final chosen = <_Candidate>[];
    final seen = <String>{};
    for (final candidate in candidates) {
      if (candidate.score < 0 || !seen.add(_norm(candidate.name))) continue;
      chosen.add(candidate);
      if (chosen.length == 10) break;
    }

    stdout.writeln('\nPIVOTES CANDIDATOS: $context');
    stdout.writeln('Artículo de partida: $root\n');
    for (var i = 0; i < chosen.length; i++) {
      stdout.writeln(
        'P${(i + 1).toString().padLeft(2, '0')} — ${chosen[i].name}',
      );
    }
    clock.stop();
    stdout.writeln(
      '\nTiempo: ${(clock.elapsedMilliseconds / 1000).toStringAsFixed(3)} s',
    );
    stdout.writeln('Pivotes: ${chosen.length}/10');
    stdout.writeln(
      'AVISO: candidatos editoriales, no atractores semánticos validados.',
    );
    final rootDir = File.fromUri(Platform.script).parent.parent.parent.parent;
    final file = File(
      '${rootDir.path}/.ai-apps/pivotes_algoritmicos.experimento.json',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert({
        'context': context,
        'source': root,
        'elapsedMilliseconds': clock.elapsedMilliseconds,
        'validated': false,
        'pivots': [
          for (final pivot in chosen)
            {
              'name': pivot.name,
              'source': pivot.source,
              'score': pivot.score,
            },
        ],
      })}\n',
    );
  } catch (error) {
    stderr.writeln('ERROR: $error');
    exitCode = 1;
  } finally {
    client.close(force: true);
  }
}

final class _Candidate {
  _Candidate(this.name, this.score, this.source);
  final String name;
  double score;
  final String source;
}

String _norm(String s) => s
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ');

bool _irrelevant(String s) {
  final text = _norm(s);
  if (text.length < 4 || text.length > 90) return true;
  if (RegExp(r'^\d|^anexo:|^categoría:|^archivo:').hasMatch(text)) return true;
  return const {
    'referencias',
    'bibliografía',
    'notas',
    'enlaces externos',
    'véase también',
    'galería',
    'fuentes',
    'historia',
    'definición',
    'introducción',
    'descripción',
  }.contains(text);
}

Future<Map<String, dynamic>> _api(
  HttpClient client,
  Map<String, String> params,
) async {
  final uri = Uri.https('es.wikipedia.org', '/w/api.php', {
    ...params,
    'format': 'json',
    'formatversion': '2',
  });
  final request = await client.getUrl(uri);
  request.headers.set(HttpHeaders.userAgentHeader, 'QuizAI-pivot-experiment/0.1');
  final response = await request.close().timeout(const Duration(seconds: 5));
  if (response.statusCode != 200) {
    throw HttpException('Wikipedia HTTP ${response.statusCode}');
  }
  final text = await utf8.decoder.bind(response).join().timeout(
    const Duration(seconds: 5),
  );
  return jsonDecode(text) as Map<String, dynamic>;
}

Future<List<String>> _search(HttpClient client, String context) async {
  final data = await _api(client, {
    'action': 'query',
    'list': 'search',
    'srsearch': context,
    'srlimit': '3',
  });
  final matches = (data['query'] as Map?)?['search'] as List? ?? [];
  final titles = [
    for (final match in matches)
      if (match is Map && match['title'] is String)
        match['title'] as String,
  ];
  titles.sort((a, b) {
    if (_norm(a) == _norm(context)) return -1;
    if (_norm(b) == _norm(context)) return 1;
    return 0;
  });
  return titles;
}

Future<List<({String name, int level})>> _sections(
  HttpClient client,
  String title,
) async {
  final data = await _api(client, {
    'action': 'parse',
    'page': title,
    'prop': 'sections',
  });
  final rows = (data['parse'] as Map?)?['sections'] as List? ?? [];
  return [
    for (final row in rows)
      if (row is Map && row['line'] is String)
        (
          name: (row['line'] as String)
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll('&amp;', '&')
              .trim(),
          level: int.tryParse('${row['level']}') ?? 99,
        ),
  ];
}

Future<List<String>> _links(HttpClient client, String title) async {
  final data = await _api(client, {
    'action': 'parse',
    'page': title,
    'prop': 'links',
  });
  final rows = (data['parse'] as Map?)?['links'] as List? ?? [];
  return [
    for (final row in rows)
      if (row is Map &&
          row['ns'] == 0 &&
          (row['exists'] == true || row['exists'] == '') &&
          (row['title'] is String || row['*'] is String))
        (row['title'] ?? row['*']) as String,
  ];
}
