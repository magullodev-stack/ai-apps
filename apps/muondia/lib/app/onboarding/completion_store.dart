import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract class OnboardingCompletionStore {
  Future<bool> hasCompleted(String userId);
  Future<void> markCompleted(String userId);
}

/// Estado local por identificador de usuario, persistente tras reinicios.
/// Solo se escribe al terminar el recorrido, nunca al entrar o autenticarse.
class LocalOnboardingCompletionStore implements OnboardingCompletionStore {
  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File(
      directory.path + Platform.pathSeparator + 'muondia-onboarding.json',
    );
  }

  Future<Set<String>> _read() async {
    final file = await _file();
    if (!await file.exists()) return <String>{};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      throw const FormatException('Estado de onboarding inválido.');
    }
    return decoded.whereType<String>().toSet();
  }

  @override
  Future<bool> hasCompleted(String userId) async =>
      (await _read()).contains(userId);

  @override
  Future<void> markCompleted(String userId) async {
    final completed = await _read();
    completed.add(userId);
    final file = await _file();
    await file.writeAsString(jsonEncode(completed.toList()..sort()), flush: true);
  }
}
