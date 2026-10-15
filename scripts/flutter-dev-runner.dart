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

  final controller = FlutterMachineController(process);
  final watchers = <StreamSubscription<FileSystemEvent>>[];
  Timer? debounce;
  // Las sustituciones de JSON en Windows pueden perder eventos del watcher.
  // Comparar contenido, no solo fechas, sin exponer credenciales.
  final googleConfig = File(
    options.workingDirectory +
        Platform.pathSeparator +
        'android' +
        Platform.pathSeparator +
        'app' +
        Platform.pathSeparator +
        'google-services.json',
  );
  var googleConfigSignature = _configurationSignature(googleConfig);
  String? pendingSignature;
  var stableChecks = 0;
  var pendingReload = false;
  var pendingImageRestart = false;
  var relaunchRequested = false;
  // Evita que una sustitución atómica de un PNG ya existente se confunda
  // con un recurso nuevo que exige reempaquetado.
  final knownImageAssets = <String>{};
  final assetDirectory = Directory(
    options.workingDirectory + Platform.pathSeparator + 'assets',
  );
  if (assetDirectory.existsSync()) {
    for (final entity in assetDirectory.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && _isImageAsset(entity.path)) {
        knownImageAssets.add(_normalizedPath(entity.path));
      }
    }
  }

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
    // Las imágenes conservan su ImageCache tras Hot Reload. Requerir un
    // Hot Restart del isolate, no un relanzamiento nativo/Gradle.
    pendingImageRestart |= _isImageAsset(path);
    debounce?.cancel();
    debounce = Timer(
      Duration(milliseconds: pendingImageRestart ? 1200 : 650),
      () {
        if (!controller.isReady) {
          pendingReload = true;
          return;
        }
        pendingReload = false;
        final restartImages = pendingImageRestart;
        pendingImageRestart = false;
        stdout.writeln(
          'Cambio detectado: ' +
              _relativePath(options.workingDirectory, path),
        );
        if (restartImages) {
          unawaited(controller.restart());
        } else {
          unawaited(controller.reload());
        }
      },
    );
  }

  for (final root in options.watchRoots) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;

    watchers.add(
      directory.watch(recursive: true).listen((event) {
        // La primera incorporación de una imagen requiere empaquetarla.
        // Los cambios de imágenes existentes solo precisan Hot Restart.
        final isNewImage = event is FileSystemCreateEvent &&
            _isNewBundledImage(event.path) &&
            knownImageAssets.add(_normalizedPath(event.path));
        if (_requiresRelaunch(event.path) || isNewImage) {
          scheduleRelaunch(event.path);
        } else if (_shouldReload(event.path)) {
          scheduleReload(event.path);
        }
      }),
    );
  }

  final googleMonitor = Timer.periodic(const Duration(seconds: 2), (_) {
    final current = _configurationSignature(googleConfig);
    if (current == googleConfigSignature) {
      pendingSignature = null;
      stableChecks = 0;
      return;
    }
    if (pendingSignature == current) {
      stableChecks++;
    } else {
      pendingSignature = current;
      stableChecks = 1;
    }
    // No relanzar mientras se copia parcialmente el archivo.
    if (stableChecks >= 2) {
      googleConfigSignature = current;
      pendingSignature = null;
      stableChecks = 0;
      if (!relaunchRequested) scheduleRelaunch(googleConfig.path);
    }
  });

  controller.onReady = () {
    stdout.writeln(
      'Hot reload automatico activo: los cambios sincronizados se '
      'reflejaran en el dispositivo.',
    );
    if (pendingReload) {
      pendingReload = false;
      final restartImages = pendingImageRestart;
      pendingImageRestart = false;
      if (restartImages) {
        unawaited(controller.restart());
      } else {
        unawaited(controller.reload());
      }
    }
  };

  _configureKeyboard(controller);

  final code = await process.exitCode;
  controller.dispose();
  googleMonitor.cancel();
  debounce?.cancel();
  for (final watcher in watchers) {
    await watcher.cancel();
  }

  if (controller.relaunchRequested) {
    // Mantener compatibilidad con el lanzador persistente anterior que
    // todavía puede estar ejecutándose durante la sincronización de dev.
    exitCode = 86;
  } else if (controller.stopRequested) {
    exitCode = 0;
  } else if (controller.lostConnection) {
    exitCode = 88;
  } else {
    exitCode = code;
  }
}

void _configureKeyboard(FlutterMachineController controller) {
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

String _configurationSignature(File file) {
  try {
    if (!file.existsSync()) return 'absent';
    final bytes = file.readAsBytesSync();
    var hash = 2166136261;
    for (final byte in bytes) {
      hash = ((hash ^ byte) * 16777619) & 0xFFFFFFFF;
    }
    return '${bytes.length}:${hash.toRadixString(16)}';
  } on FileSystemException {
    return 'unreadable';
  }
}

bool _requiresRelaunch(String path) {
  final normalized = path.replaceAll('\\', '/').toLowerCase();

  if (normalized.contains('/build/') ||
      normalized.contains('/.dart_tool/') ||
      normalized.contains('/.git/') ||
      normalized.contains('/android/.gradle/') ||
      normalized.endsWith('/android/.gradle') ||
      normalized.endsWith('/android/local.properties')) {
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
        fileName.endsWith('.properties') ||
        (normalized.contains('/android/app/src/') &&
            (fileName.endsWith('.kt') ||
                fileName.endsWith('.java') ||
                fileName.endsWith('.xml')));
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
      normalized.contains('/.git/') ||
      normalized.contains('/android/.gradle/')) {
    return false;
  }

  return normalized.endsWith('.dart') ||
      _isImageAsset(normalized) ||
      normalized.endsWith('.json') ||
      normalized.endsWith('.ttf') ||
      normalized.endsWith('.otf');
}

bool _isImageAsset(String path) {
  final normalized = path.replaceAll('\\', '/').toLowerCase();
  return normalized.endsWith('.png') ||
      normalized.endsWith('.jpg') ||
      normalized.endsWith('.jpeg') ||
      normalized.endsWith('.webp');
}

String _normalizedPath(String path) =>
    path.replaceAll('\\', '/').toLowerCase();

bool _isNewBundledImage(String path) {
  final normalized = _normalizedPath(path);
  return normalized.contains('/assets/') &&
      !normalized.contains('/build/') &&
      !normalized.contains('/.dart_tool/') &&
      _isImageAsset(path);
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

final class FlutterMachineController {
  FlutterMachineController(this.process, {
    this.updateTimeout = const Duration(seconds: 120),
  }) {
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
  final Duration updateTimeout;
  String? _appId;
  var _started = false;
  var _lostConnection = false;
  var _stopRequested = false;
  var _relaunchRequested = false;
  var _nextRequestId = 1;
  // Una sola actualización en vuelo: los eventos del sistema de archivos
  // se agrupan y un reload fallido se recupera con un único hot restart.
  int? _inFlightId;
  bool _inFlightRestart = false;
  bool _queuedReload = false;
  bool _queuedRestart = false;
  Timer? _updateWatchdog;
  void Function()? onReady;

  bool get isReady => _appId != null && _started;
  bool get lostConnection => _lostConnection;
  bool get stopRequested => _stopRequested;
  bool get relaunchRequested => _relaunchRequested;

  void dispose() {
    _updateWatchdog?.cancel();
    _updateWatchdog = null;
  }

  Future<void> reload({String reason = 'source-change'}) async {
    _queuedReload = true;
    _dispatchUpdate();
  }

  Future<void> restart() async {
    _queuedRestart = true;
    _dispatchUpdate();
  }

  void _dispatchUpdate() {
    if (!isReady || _relaunchRequested || _stopRequested ||
        _inFlightId != null || (!_queuedReload && !_queuedRestart)) {
      return;
    }
    final fullRestart = _queuedRestart;
    _queuedRestart = false;
    _queuedReload = false;
    final id = _nextRequestId++;
    _inFlightId = id;
    _inFlightRestart = fullRestart;
    // Flutter --machine puede quedarse esperando una respuesta indefinidamente.
    // Si su canal deja de responder, relanzar exclusivamente el proceso que
    // ESTE runner creó. run.ps1 reutiliza la misma sesión/dispositivo.
    _updateWatchdog?.cancel();
    _updateWatchdog = Timer(updateTimeout, () {
      if (_inFlightId != id || _relaunchRequested) return;
      stderr.writeln(
        'Hot ${fullRestart ? 'restart' : 'reload'} fallo: timeout',
      );
      stderr.writeln('Recuperacion Flutter: canal bloqueado; relanzamiento controlado.');
      requestRelaunch();
    });
    _send(
      id: id,
      method: 'app.restart',
      params: {
        'appId': _appId,
        'fullRestart': fullRestart,
        'pause': false,
        'reason': fullRestart ? 'manual' : 'source-change',
        'debounce': true,
      },
    );
  }

  // Registrar solo categorías/códigos estructurados: la salida de flutter
  // puede contener URLs o credenciales y NO debe persistirse en el log.
  String? _updateFailure(Map<String, dynamic> message) {
    final error = message['error'];
    if (error != null) {
      if (error is Map && error['code'] is int) {
        return 'protocolo_${error['code']}';
      }
      return 'protocolo';
    }
    final result = message['result'];
    if (result is! Map || result['code'] == null) {
      return 'respuesta_invalida';
    }
    final code = result['code'];
    if (code == 0) return null;
    if (code is int) return 'codigo_$code';
    return 'resultado_no_valido';
  }

  void _finishUpdate(int id, Map<String, dynamic> message) {
    if (id != _inFlightId) return;
    _updateWatchdog?.cancel();
    _updateWatchdog = null;
    final fullRestart = _inFlightRestart;
    _inFlightId = null;
    final failure = _updateFailure(message);
    if (failure == null) {
      stdout.writeln(
        fullRestart ? 'Hot restart completado.' :
            'Hot reload automatico completado.',
      );
    } else {
      stderr.writeln(
        'Hot ${fullRestart ? 'restart' : 'reload'} fallo: $failure',
      );
      if (!fullRestart) {
        // No repetir un reload rechazado sobre la misma versión. El
        // restart reconstruye el isolate sin parar el runner ni Android.
        stdout.writeln('Recuperacion Flutter: Hot restart automatico solicitado.');
        _queuedRestart = true;
      }
      // Si falla también el restart, no entrar en un bucle: esperar otra
      // modificación de fuentes o una señal explícita del usuario.
    }
    _dispatchUpdate();
  }

  void requestRelaunch() {
    if (_relaunchRequested) return;
    _updateWatchdog?.cancel();
    _relaunchRequested = true;
    unawaited(_terminateProcessTree());
  }

  void stop() {
    _updateWatchdog?.cancel();
    _stopRequested = true;
    unawaited(_terminateProcessTree());
  }

  Future<void> _terminateProcessTree() async {
    if (!Platform.isWindows) {
      process.kill();
      return;
    }
    // Flutter's .bat wrapper owns descendants and inherited output handles.
    // Kill that exact owned tree so streams close and the worker can relaunch.
    final result = await Process.run(
      'taskkill.exe', ['/PID', '${process.pid}', '/T', '/F'],
    );
    if (result.exitCode != 0) {
      stderr.writeln('No se pudo terminar el proceso Flutter de esta sesion.');
    }
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
        _dispatchUpdate();
        continue;
      }

      if (event == 'app.stop') {
        _appId = null;
        _started = false;
        _updateWatchdog?.cancel();
        if (_inFlightId != null) {
          // Una actualización interrumpida deberá reintentarse en la nueva app.
          if (_inFlightRestart) _queuedRestart = true;
          else _queuedReload = true;
          _inFlightId = null;
        }
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

      _finishUpdate(id, message);
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
