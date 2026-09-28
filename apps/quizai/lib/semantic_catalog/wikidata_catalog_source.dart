import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef WikidataJsonReader = Future<Map<String, dynamic>> Function(Uri uri);

/// Read-only Wikidata access. No model, key, Flutter or third-party dependency.
final class WikidataCatalogSource {
  WikidataCatalogSource({WikidataJsonReader? readJson})
    : _readJson = readJson ?? _httpJson;

  final WikidataJsonReader _readJson;

  Future<List<Map<String, dynamic>>> search(String text) async {
    final data = await _readJson(
      Uri.https('www.wikidata.org', '/w/api.php', {
        'action': 'wbsearchentities',
        'search': text,
        'language': 'es',
        'uselang': 'es',
        'type': 'item',
        'limit': '10',
        'format': 'json',
      }),
    );
    if (data['error'] != null) {
      throw const FormatException('Wikidata rechazó la búsqueda.');
    }
    return (data['search'] as List).cast<Map<String, dynamic>>();
  }

  /// Fetches factual predicates for a bounded set of graph nodes.
  /// The values are evidence only; the catalog never prints entity labels
  /// from these statements as attractors.
  Future<Map<String, dynamic>> claims(List<String> ids) async {
    if (ids.isEmpty) return {};
    if (ids.length > 30 ||
        ids.any((id) => !RegExp(r'^Q[1-9][0-9]*$').hasMatch(id))) {
      throw const FormatException('Identificadores Wikidata inválidos.');
    }
    final data = await _readJson(
      Uri.https('www.wikidata.org', '/w/api.php', {
        'action': 'wbgetentities',
        'ids': ids.join('|'),
        'props': 'claims',
        'format': 'json',
      }),
    );
    if (data['error'] != null) {
      throw const FormatException('Wikidata rechazó la consulta de hechos.');
    }
    return (data['entities'] as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> query(String sparql) async {
    final data = await _readJson(
      Uri.https('query.wikidata.org', '/sparql', {
        'query': sparql,
        'format': 'json',
      }),
    );
    return ((data['results'] as Map)['bindings'] as List)
        .cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> _httpJson(Uri uri) async {
    for (var attempt = 0; ; attempt++) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20)
        ..userAgent =
            'QuizAI-AlgorithmicCatalog/1.0 '
            '(https://github.com/magullodev-stack/ai-apps)';
      try {
        final result = await (() async {
          final request = await client.getUrl(uri);
          request.headers.set('Accept', 'application/json');
          final response = await request.close();
          if (response.statusCode != 200) {
            throw HttpException(
              'Wikidata HTTP ${response.statusCode}',
              uri: Uri.https(uri.host, uri.path),
            );
          }
          final body = await utf8.decoder.bind(response).join();
          return jsonDecode(body) as Map<String, dynamic>;
        })().timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException(
            'Wikidata no respondió en 20 s: ${uri.host}${uri.path}',
          ),
        );
        return result;
      } on HttpException catch (error) {
        if (attempt >= 1 ||
            !RegExp(r'HTTP (429|502|503|504)').hasMatch(error.message)) {
          rethrow;
        }
      } finally {
        client.close(force: true);
      }
      await Future<void>.delayed(const Duration(seconds: 10));
    }
  }
}
