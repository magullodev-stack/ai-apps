import 'dart:convert';
import 'dart:io';

/// Calls an AI-APPS server; never put the OpenAI API key in a mobile app.
class AiAppsClient {
  AiAppsClient({
    required this.endpoint,
    required this.authorization,
    HttpClient? httpClient,
  }) : _http = httpClient ?? HttpClient();

  final Uri endpoint;
  final String authorization;
  final HttpClient _http;

  Future<AiGeneration> generate({
    required String application,
    required String model,
    required String input,
    required String schemaName,
    required Map<String, Object?> schema,
  }) async {
    final request = await _http.postUrl(endpoint.resolve('/v1/generate'));
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authorization',
    );
    request.write(
      jsonEncode({
        'application': application,
        'model': model,
        'input': input,
        'schemaName': schemaName,
        'schema': schema,
      }),
    );
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      Map<String, dynamic>? diagnostic;
      String? code;
      try {
        final payload = jsonDecode(text);
        if (payload is Map<String, dynamic>) {
          code = payload['error'] is String ? payload['error'] as String : null;
          if (payload['diagnostic'] is Map<String, dynamic>) {
            diagnostic = payload['diagnostic'] as Map<String, dynamic>;
          }
        }
      } on FormatException {
        // A proxy may return non-JSON errors.
      }
      throw AiAppsException(
        response.statusCode,
        code: code,
        diagnostic: diagnostic,
      );
    }
    final payload = jsonDecode(text) as Map<String, dynamic>;
    return AiGeneration(
      text: payload['text'] as String,
      usage: payload['usage'] as Map<String, dynamic>?,
    );
  }

  void close() => _http.close();
}

class AiGeneration {
  const AiGeneration({required this.text, this.usage});
  final String text;
  final Map<String, dynamic>? usage;
}

class AiAppsException implements Exception {
  const AiAppsException(this.statusCode, {this.code, this.diagnostic});
  final int statusCode;
  final String? code;
  final Map<String, dynamic>? diagnostic;
  @override
  String toString() =>
      'AI-APPS request failed (HTTP $statusCode)'
      '${code == null ? '' : ': $code'}'
      '${diagnostic == null ? '' : ' ${jsonEncode(diagnostic)}'}';
}
