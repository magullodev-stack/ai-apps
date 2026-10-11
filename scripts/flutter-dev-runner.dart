import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);

  final process = await Process.start(
    options.flutter,
    [
      'run',
      '--machine',
      if (options.noDds) '--no-dds',
      '-d',
      options.device,
      '--dart-define-from-file=' + options.definesFile,
    ],
    workingDirectory: options.workingDirectory,
    runInShell: Platform.isWindows,
  );

  final controller = _FlutterMachineController(process);
  final watchers = <StreamSubscription<FileSystemEvent>>[];
  Timer? debounce;
  var pendingReload = false;
  var relaunchRequested = false;

  void scheduleRelaunch(String path) {
    if (relaunchRequested) return;
    relaunchRequested = true;
    debounce?.cancel();
    stdout.writeln(
      'Cambio nativo/dependencias detectado: ' +
          _relativePath(options.workingDirectory, path) +
          '. Preparando reinicio completo...',
    );

    unawaited(() async {
      final normalized = path.replaceAll('\\', '/').toLowerCase();
      if (normalized.endsWith('/pubspec.yaml') ||
          normalized.endsWith('/pubspec.lock')) {
        final result = await Process.run(
          options.flutter,
          ['pub', 'get'],
          workingDirectory: options.workingDirectory,
          runInShell: Platform.isWindows,
        );

        if (result.stdout.toString().trim().isNotEmpty) {
          stdout.write(result.stdout);
        }
        if (result.stderr.toString().trim().isNotEmpty) {
          stderr.write(result.stderr);
        }
        if (result.exitCode != 0) {
          stderr.writeln('flutter pub get fallo; no se reinicia la app.');
          relaunchRequested = false;
          return;
        }
      }

      controller.requestRelaunch();
    }());
  }

  void scheduleReload(String path) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 650), () {
      if (!controller.isReady) {
        pendingReload = true;
        return;
      }
      pendingReload = false;
      stdout.writeln(
        'Cambio detectado: ' +
            _relativePath(options.workingDirectory, path),
      );
      unawaited(controller.reload());
    });
  }

  for (final root in options.watchRoots) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;

    watchers.add(
      directory.watch(recursive: true).listen((event) {
        if (_requiresRelaunch(event.path)) {
          scheduleRelaunch(event.path);
        } else if (_shouldReload(event.path)) {
          scheduleReload(event.path);
        }
      }),
    );
  }

  controller.onReady = () {
    stdout.writeln(
      'Hot reload automatico activo: los cambios sincronizados se '
      'reflejaran en el dispositivo.',
    );
    if (pendingReload) {
      pendingReload = false;
      unawaited(controller.reload());
    }
  };

  _configureKeyboard(controller);

  final code = await process.exitCode;
  debounce?.cancel();
  for (final watcher in watchers) {
    await watcher.cancel();
  }

  if (controller.relaunchRequested) {
    exitCode = 86;
  } else if (controller.stopRequested) {
    exitCode = 0;
  } else if (controller.lostConnection) {
    exitCode = 86;
  } else {
    exitCode = code;
  }
}

void _configureKeyboard(_FlutterMachineController controller) {
  if (!stdin.hasTerminal) return;

  try {
    stdin
      ..lineMode = false
      ..echoMode = false;

    stdin.listen((bytes) {
      for (final byte in bytes) {
        switch (byte) {
          case 114:
            unawaited(controller.reload(reason: 'manual'));
            break;
          case 82:
            unawaited(controller.restart());
            break;
          case 113:
            controller.stop();
            break;
        }
      }
    });
  } catch (_) {
    // El hot reload automatico no depende de la entrada interactiva.
  }
}

bool _requiresRelaunch(String path) {
  final normalized = path.replaceAll('\\', '/').toLowerCase();

  if (normalized.contains('/build/') ||
      normalized.contains('/.dart_tool/') ||
      normalized.contains('/.git/')) {
    return false;
  }

  final fileName = normalized.split('/').last;
  if (fileName == 'pubspec.yaml' || fileName == 'pubspec.lock') {
    return true;
  }

  if (normalized.contains('/android/')) {
    return fileName == 'androidmanifest.xml' ||
        fileName == 'google-services.json' ||
        fileName.endsWith('.gradle') ||
        fileName.endsWith('.gradle.kts') ||
        fileName.endsWith('.properties');
  }

  if (normalized.contains('/ios/')) {
    return fileName == 'info.plist' ||
        fileName == 'googleService-info.plist'.toLowerCase() ||
        fileName == 'podfile' ||
        fileName == 'podfile.lock' ||
        fileName.endsWith('.entitlements') ||
        fileName.endsWith('.pbxproj');
  }

  return false;
}

bool _shouldReload(String path) {
  final normalized = path.replaceAll('\\', '/').toLowerCase();

  if (normalized.contains('/build/') ||
      normalized.contains('/.dart_tool/') ||
      normalized.contains('/.git/')) {
    return false;
  }

  return normalized.endsWith('.dart') ||
      normalized.endsWith('.png') ||
      normalized.endsWith('.jpg') ||
      normalized.endsWith('.jpeg') ||
      normalized.endsWith('.webp') ||
      normalized.endsWith('.json') ||
      normalized.endsWith('.ttf') ||
      normalized.endsWith('.otf');
}

String _relativePath(String base, String path) {
  final normalizedBase = base.replaceAll('\\', '/');
  final normalizedPath = path.replaceAll('\\', '/');
  final prefix = normalizedBase + '/';
  if (normalizedPath.startsWith(prefix)) {
    return normalizedPath.substring(prefix.length);
  }
  return normalizedPath;
}

final class _FlutterMachineController {
  _FlutterMachineController(this.process) {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStdout);

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStderr);
  }

  final Process process;
  String? _appId;
  var _started = false;
  var _lostConnection = false;
  var _stopRequested = false;
  var _relaunchRequested = false;
  var _nextRequestId = 1;
  final _reloadRequests = <int>{};
  final _restartRequests = <int>{};
  void Function()? onReady;

  bool get isReady => _appId != null && _started;
  bool get lostConnection => _lostConnection;
  bool get stopRequested => _stopRequested;
  bool get relaunchRequested => _relaunchRequested;

  Future<void> reload({String reason = 'source-change'}) async {
    final appId = _appId;
    if (appId == null) return;

    final id = _nextRequestId++;
    _reloadRequests.add(id);
    _send(
      id: id,
      method: 'app.restart',
      params: {
        'appId': appId,
        'fullRestart': false,
        'pause': false,
        'reason': reason,
        'debounce': true,
      },
    );
  }

  Future<void> restart() async {
    final appId = _appId;
    if (appId == null) return;

    final id = _nextRequestId++;
    _restartRequests.add(id);
    _send(
      id: id,
      method: 'app.restart',
      params: {
        'appId': appId,
        'fullRestart': true,
        'pause': false,
        'reason': 'manual',
        'debounce': true,
      },
    );
  }

  void requestRelaunch() {
    _relaunchRequested = true;
    process.kill();
  }

  void stop() {
    _stopRequested = true;
    process.kill();
  }

  void _send({
    required int id,
    required String method,
    required Map<String, Object?> params,
  }) {
    process.stdin.writeln(
      jsonEncode([
        {
          'id': id,
          'method': method,
          'params': params,
        },
      ]),
    );
  }

  void _handleStdout(String line) {
    if (line.contains('Lost connection to device.')) {
      _lostConnection = true;
    }

    final decoded = _tryDecode(line);
    if (decoded == null) {
      if (line.trim().isNotEmpty) stdout.writeln(line);
      return;
    }

    for (final message in decoded) {
      final event = message['event'];
      final params = message['params'];

      if (event == 'app.start' && params is Map) {
        _appId = params['appId']?.toString();
        _started = false;
        stdout.writeln(
          'Flutter iniciando en ' +
              (params['deviceId']?.toString() ?? 'Android') +
              '...',
        );
        continue;
      }

      if (event == 'app.started') {
        _started = true;
        onReady?.call();
        continue;
      }

      if (event == 'app.stop') {
        _appId = null;
        _started = false;
        continue;
      }

      if (event == 'app.log' && params is Map) {
        final log = params['log'];
        if (log != null && log.toString().trim().isNotEmpty) {
          stdout.writeln(log);
        }
        continue;
      }

      if (event == 'app.progress' && params is Map) {
        final messageText = params['message'];
        if (messageText != null &&
            messageText.toString().trim().isNotEmpty &&
            params['finished'] != true) {
          stdout.writeln(messageText);
        }
        continue;
      }

      final idValue = message['id'];
      final id = idValue is int ? idValue : int.tryParse(idValue.toString());
      if (id == null) continue;

      if (_reloadRequests.remove(id)) {
        _printRestartResult(message, fullRestart: false);
      } else if (_restartRequests.remove(id)) {
        _printRestartResult(message, fullRestart: true);
      }
    }
  }

  void _handleStderr(String line) {
    if (line.contains('Lost connection to device.')) {
      _lostConnection = true;
    }
    if (line.trim().isNotEmpty) {
      stderr.writeln(line);
    }
  }

  void _printRestartResult(
    Map<String, dynamic> message, {
    required bool fullRestart,
  }) {
    final error = message['error'];
    if (error != null) {
      stderr.writeln(
        (fullRestart ? 'Hot restart' : 'Hot reload') +
            ' fallo: ' +
            error.toString(),
      );
      return;
    }

    final result = message['result'];
    if (result is Map && result['code'] != null && result['code'] != 0) {
      stderr.writeln(
        (fullRestart ? 'Hot restart' : 'Hot reload') +
            ' fallo: ' +
            (result['message'] ?? result['code']).toString(),
      );
      return;
    }

    stdout.writeln(
      fullRestart
          ? 'Hot restart completado.'
          : 'Hot reload automatico completado.',
    );
  }

  List<Map<String, dynamic>>? _tryDecode(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) return null;

    try {
      final value = jsonDecode(trimmed);
      if (value is! List) return null;
      return [
        for (final item in value)
          if (item is Map)
            item.map((key, value) => MapEntry(key.toString(), value)),
      ];
    } catch (_) {
      return null;
    }
  }
}

final class _Options {
  const _Options({
    required this.flutter,
    required this.device,
    required this.definesFile,
    required this.workingDirectory,
    required this.watchRoots,
    this.noDds = false,
  });

  final String flutter;
  final String device;
  final String definesFile;
  final String workingDirectory;
  final List<String> watchRoots;
  final bool noDds;

  static _Options parse(List<String> args) {
    final values = <String, String>{};
    final watchRoots = <String>[];
    var noDds = false;

    for (var i = 0; i < args.length; i++) {
      final name = args[i];
      if (name == '--no-dds') {
        noDds = true;
        continue;
      }
      if (name == '--watch') {
        if (i + 1 >= args.length) {
          throw const FormatException('Falta una ruta despues de --watch.');
        }
        watchRoots.add(args[++i]);
        continue;
      }

      if (!name.startsWith('--') || i + 1 >= args.length) {
        throw FormatException('Argumento no valido: ' + name);
      }
      values[name] = args[++i];
    }

    String requiredValue(String name) {
      final value = values[name];
      if (value == null || value.trim().isEmpty) {
        throw FormatException('Falta el argumento requerido ' + name + '.');
      }
      return value;
    }

    return _Options(
      flutter: requiredValue('--flutter'),
      device: requiredValue('--device'),
      definesFile: requiredValue('--defines-file'),
      workingDirectory: requiredValue('--working-directory'),
      watchRoots: List.unmodifiable(watchRoots),
      noDds: noDds,
    );
  }
}
