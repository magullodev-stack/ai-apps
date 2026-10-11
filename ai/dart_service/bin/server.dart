import 'dart:convert';
import 'dart:io';

import '../lib/ai_service.dart';

Future<void> main() async {
  final env = Platform.environment;
  final key = env['AI_APPS_AI_API_KEY'] ?? env['OPENAI_API_KEY'] ?? '';
  final token = env['AI_APPS_GAME_TOKEN'] ?? '';
  final readyPath = env['AI_APPS_READY_FILE'];
  if (key.trim().isEmpty || token.trim().isEmpty || readyPath == null) {
    stderr.writeln(
        'Falta la configuración privada del servicio. Usa scripts/run-android.ps1.');
    exitCode = 1;
    return;
  }
  try {
    final service = AiService(apiKey: key, token: token);
    final requestedPort = int.tryParse(env['AI_APPS_SERVICE_PORT'] ?? '') ?? 0;
    if (requestedPort < 0 || requestedPort > 65535) {
      throw const FormatException('Invalid service port');
    }
    final server = await service.start(port: requestedPort);
    final file = File(readyPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
        jsonEncode({
          'service': 'ai-apps-dart',
          'pid': pid,
          'endpoint': 'http://127.0.0.1:${server.port}',
          'token': token,
        }),
        flush: true);
    stdout.writeln('AI-APPS Dart disponible en 127.0.0.1:${server.port}');
  } catch (_) {
    stderr.writeln('No se pudo iniciar el servicio Dart.');
    exitCode = 1;
  }
}
