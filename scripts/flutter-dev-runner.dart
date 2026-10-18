import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  final root = Directory(options.workingDirectory).parent.parent.path;
  final appName = options.workingDirectory
      .split(RegExp(r'[\\/]'))
      .where((part) => part.isNotEmpty)
      .last;
  final appPath = 'apps/$appName/';

  // Una revisión solo se considera aplicada tras la respuesta de Flutter.
  // Si el runner termina, flutter run vuelve a compilar el checkout actual.
  String? appliedRevision = await _readGitRevision(root);
  String? queuedRevision;
  String? activeRevision;
  String? blockedRevision;
  var pendingAction = FlutterChangeAction.none;
  var activeAction = FlutterChangeAction.none;
  var pendingPath = '';
  var activePath = '';
  var updating = false;
  var relaunching = false;
  Timer? debounce;

  final flutter = await Process.start(
    options.flutter,
    [
      'run', '--machine',
      if (options.noDds) '--no-dds',
      '-d', options.device,
      '--dart-define-from-file=' + options.definesFile,
    ],
    workingDirectory: options.workingDirectory,
    runInShell: Platform.isWindows,
  );
  final controller = FlutterMachineController(flutter);
  final watchers = <StreamSubscription<FileSystemEvent>>[];

  // Los assets presentes antes de una edición no requieren reempaquetarse
  // si solo se sustituye su contenido. Un alta/baja sí exige recompilar.
  final existingAssets = <String>{};
  final assets = Directory(
    options.workingDirectory + Platform.pathSeparator + 'assets',
  );
  if (assets.existsSync()) {
    for (final entity in assets.listSync(recursive: true, followLinks: false)) {
      if (entity is File) existingAssets.add(_normalizedPath(entity.path));
    }
  }

  void rebuild(String path, {String? revision}) {
    if (relaunching) return;
    relaunching = true;
    debounce?.cancel();
    stdout.writeln('Reconstruccion Flutter solicitada: ' +
        _relativePath(options.workingDirectory, path));
    unawaited(() async {
      // pubspec exige actualizar primero el grafo de dependencias.
      final name = _normalizedPath(path);
      if (name.endsWith('/pubspec.yaml') ||
          name.endsWith('/pubspec.lock')) {
        final result = await Process.run(
          options.flutter, ['pub', 'get'],
          workingDirectory: options.workingDirectory,
          runInShell: Platform.isWindows,
        );
        if (result.exitCode != 0) {
          stderr.writeln('ERROR: flutter pub get fallo; se conserva Flutter.');
          blockedRevision = revision;
          relaunching = false;
          return;
        }
      }
      controller.requestRelaunch();
    }());
  }

  // Una sola actualización activa y como máximo una acción pendiente.
  // Una operación más fuerte (restart) nunca se rebaja a reload.
  void dispatch() {
    if (relaunching || updating || !controller.isReady ||
        pendingAction == FlutterChangeAction.none) return;
    updating = true;
    activeAction = pendingAction;
    activePath = pendingPath;
    activeRevision = queuedRevision;
    pendingAction = FlutterChangeAction.none;
    pendingPath = '';
    queuedRevision = null;
    stdout.writeln('Cambio detectado: ' +
        _relativePath(options.workingDirectory, activePath));
    stdout.writeln(activeAction == FlutterChangeAction.reload
        ? 'Actualizando Flutter: Hot Reload.'
        : 'Actualizando Flutter: Hot Restart.');
    if (activeAction == FlutterChangeAction.restart) {
      unawaited(controller.restart());
    } else {
      unawaited(controller.reload());
    }
  }

  void queue(FlutterChangeAction action, String path, {String? revision}) {
    if (action == FlutterChangeAction.none || relaunching) return;
    // Una edición más reciente desatasca un commit cuyo Flutter falló.
    if (revision == null || revision != blockedRevision) {
      blockedRevision = null;
    }
    if (action == FlutterChangeAction.rebuild) {
      rebuild(path, revision: revision);
      return;
    }
    if (action.index > pendingAction.index) pendingAction = action;
    pendingPath = path;
    if (revision != null) queuedRevision = revision;
    debounce?.cancel();
    debounce = Timer(
      Duration(milliseconds: pendingAction == FlutterChangeAction.restart
          ? 1100 : 650),
      dispatch,
    );
  }

  // El callback se ejecuta al terminar la operación real, incluido el
  // fallback reload -> restart. Detectar archivos NO equivale a aplicarlos.
  controller.onUpdateSettled = (success, fullRestart) {
    if (!updating) return;
    final revision = activeRevision;
    final path = activePath;
    updating = false;
    activeRevision = null;
    if (success) {
      blockedRevision = null;
      if (revision != null) {
        appliedRevision = revision;
        stdout.writeln('Revision dev aplicada: ' +
            revision.substring(0, 7) + '.');
      }
      if (pendingAction != FlutterChangeAction.none) dispatch();
      return;
    }
    // Si Flutter rechaza tanto Hot Reload como Hot Restart, la siguiente
    // operación necesaria es una recompilación, no más recargas en bucle.
    // run.ps1 ejecutará una nueva instancia de este mismo runner.
    blockedRevision = revision;
    stderr.writeln(
      'Recuperacion Flutter: Hot Restart rechazado; '
      'recompilacion completa solicitada.',
    );
    rebuild(path, revision: revision);
  };

  controller.onReady = () {
    stdout.writeln('Hot reload automatico activo: '
        'los cambios sincronizados se reflejaran en el dispositivo.');
    dispatch();
  };

  // Primer detector: modificaciones locales, incluidas las no confirmadas
  // por Git. Evitar duplicados corresponde a la cola, no a descartar commits.
  for (final watched in options.watchRoots) {
    final directory = Directory(watched);
    if (!directory.existsSync()) continue;
    watchers.add(directory.watch(recursive: true).listen((event) {
      final path = _normalizedPath(event.path);
      var status = 'M';
      if (event is FileSystemDeleteEvent) {
        status = 'D';
        existingAssets.remove(path);
      } else if (event is FileSystemCreateEvent &&
          path.contains('/assets/')) {
        status = existingAssets.add(path) ? 'A' : 'M';
      }
      final action = classifyFlutterChange(event.path, status: status);
      queue(action, event.path);
    }));
  }

  // Respaldo: un merge de Git puede no producir eventos fiables en Windows.
  // Comparar SIEMPRE desde la última revisión aplicada, no desde la detectada.
  var gitChecking = false;
  final gitMonitor = Timer.periodic(const Duration(seconds: 4), (_) async {
    if (gitChecking || relaunching) return;
    gitChecking = true;
    try {
      final current = await _readGitRevision(root);
      if (current == null || current == appliedRevision ||
          current == activeRevision || current == queuedRevision ||
          current == blockedRevision) return;
      final old = appliedRevision;
      if (old == null) {
        appliedRevision = current;
        return;
      }
      final changes = await _readGitChanges(root, old, current, appPath);
      if (changes == null) return;
      var action = FlutterChangeAction.none;
      String? path;
      for (final change in changes) {
        final next = classifyFlutterChange(change.path, status: change.status);
        if (next.index > action.index) {
          action = next;
          path = change.path;
        }
      }
      if (action == FlutterChangeAction.none) {
        // Un commit de documentación no necesita actualizar Flutter.
        appliedRevision = current;
      } else {
        stdout.writeln('Revision dev detectada: ' +
            current.substring(0, 7) + '.');
        queue(action, root + Platform.pathSeparator +
            path!.replaceAll('/', Platform.pathSeparator),
            revision: current);
      }
    } catch (_) {
      // Git puede estar trabajando: conservar la revisión para reintentar.
    } finally {
      gitChecking = false;
    }
  });

  // Configuración Firebase ignorada por Git: cambios externos al monitor
  // también necesitan reconstrucción; exigir dos lecturas iguales.
  final firebase = File(options.workingDirectory +
      Platform.pathSeparator + 'android' + Platform.pathSeparator +
      'app' + Platform.pathSeparator + 'google-services.json');
  var firebaseSignature = _configurationSignature(firebase);
  String? proposedSignature;
  // Flutter puede seguir abierto aunque Android desaparezca de ADB.
  // Tres comprobaciones seguidas entregan la recuperación a Windows.
  var adbChecking = false;
  var missingDeviceChecks = 0;
  final deviceMonitor = Timer.periodic(const Duration(seconds: 5), (_) async {
    if (adbChecking || controller.relaunchRequested ||
        controller.stopRequested || controller.lostConnection) return;
    adbChecking = true;
    try {
      final online = await _isAndroidDeviceOnline(options.device);
      if (online == true) {
        missingDeviceChecks = 0;
      } else if (online == false && ++missingDeviceChecks >= 3) {
        stderr.writeln('Dispositivo Android perdido: recuperacion del AVD solicitada.');
        controller.requestDeviceRecovery();
      }
      // null: ADB no disponible/bloqueado. No declarar desconexión.
    } catch (_) {
      // Una consulta fallida no debe interrumpir una sesión válida.
    } finally {
      adbChecking = false;
    }
  });

  final firebaseMonitor = Timer.periodic(const Duration(seconds: 2), (_) {
    final now = _configurationSignature(firebase);
    if (now == firebaseSignature) {
      proposedSignature = null;
    } else if (now == proposedSignature) {
      firebaseSignature = now;
      proposedSignature = null;
      rebuild(firebase.path);
    } else {
      proposedSignature = now;
    }
  });

  _configureKeyboard(controller);
  final code = await flutter.exitCode;
  debounce?.cancel();
  gitMonitor.cancel();
  deviceMonitor.cancel();
  firebaseMonitor.cancel();
  controller.dispose();
  for (final watcher in watchers) {
    await watcher.cancel();
  }
  if (controller.relaunchRequested) {
    exitCode = 86; // run.ps1 vuelve a ejecutar Flutter y carga este archivo.
  } else if (controller.stopRequested) {
    exitCode = 0;
  } else if (controller.lostConnection) {
    exitCode = 88;
  } else {
    exitCode = code;
  }
}

/// Solo una ausencia confirmada en ADB cuenta como desconexión.
bool adbListsOnlineDevice(String output, String serial) {
  return output.split(RegExp(r'\r?\n')).any((line) {
    final fields = line.trim().split(RegExp(r'\s+'));
    return fields.length >= 2 && fields[0] == serial && fields[1] == 'device';
  });
}

Future<bool?> _isAndroidDeviceOnline(String serial) async {
  final sdk = Platform.environment['ANDROID_HOME'] ??
      Platform.environment['ANDROID_SDK_ROOT'] ??
      (Platform.isWindows
          ? (Platform.environment['LOCALAPPDATA'] ?? '') + r'\Android\Sdk'
          : '');
  final adb = sdk.isEmpty
      ? 'adb'
      : sdk + Platform.pathSeparator + 'platform-tools' +
          Platform.pathSeparator + (Platform.isWindows ? 'adb.exe' : 'adb');
  Process? probe;
  try {
    probe = await Process.start(adb, ['devices']);
    final output = probe.stdout.transform(utf8.decoder).join();
    final errors = probe.stderr.drain<void>();
    final code = await probe.exitCode.timeout(const Duration(seconds: 5));
    final text = await output;
    await errors;
    if (code != 0) return null;
    return adbListsOnlineDevice(text, serial);
  } on TimeoutException {
    probe?.kill();
    return null;
  } on ProcessException {
    return null;
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

/// Orden de precedencia: un conjunto de cambios usa la acción más fuerte.
/// El clasificador es único para eventos locales y diferencias de Git.
enum FlutterChangeAction { none, reload, restart, rebuild }

FlutterChangeAction classifyFlutterChange(
  String path, {
  String status = 'M',
}) {
  final normalized = _normalizedPath(path);
  if (normalized.contains('/build/') ||
      normalized.contains('/.dart_tool/') ||
      normalized.contains('/.git/') ||
      normalized.contains('/node_modules/') ||
      normalized.contains('/android/.gradle/')) {
    return FlutterChangeAction.none;
  }
  if (normalized.endsWith('/scripts/flutter-dev-runner.dart')) {
    return FlutterChangeAction.rebuild; // Autoactualizar el runner.
  }
  if (_requiresRelaunch(normalized)) return FlutterChangeAction.rebuild;

  // Los recursos eliminados o nuevos cambian el bundle Flutter.
  // Los PNG, fuentes y JSON existentes necesitan limpiar el estado/cache.
  if (normalized.contains('/assets/')) {
    if (status != 'M') return FlutterChangeAction.rebuild;
    return FlutterChangeAction.restart;
  }
  if (normalized.endsWith('/lib/main.dart')) {
    return FlutterChangeAction.restart;
  }
  if (normalized.endsWith('.dart')) {
    return FlutterChangeAction.reload;
  }
  if (_shouldReload(normalized)) {
    return FlutterChangeAction.restart;
  }
  return FlutterChangeAction.none;
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
  void Function(bool success, bool fullRestart)? onUpdateSettled;

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
      onUpdateSettled?.call(true, fullRestart);
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
      // El fallo solo se confirma si también ha fallado Hot Restart.
      // Quien solicitó el cambio mantiene entonces la revisión pendiente.
      if (fullRestart) onUpdateSettled?.call(false, true);
    }
    _dispatchUpdate();
  }

  void requestDeviceRecovery() {
    if (_lostConnection || _stopRequested || _relaunchRequested) return;
    _lostConnection = true;
    _updateWatchdog?.cancel();
    unawaited(_terminateProcessTree());
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


/// Leer el commit actual; no publicar mensajes ni argumentos de Git.
Future<String?> _readGitRevision(String root) async {
  final result = await Process.run(
    'git', ['-C', root, 'rev-parse', '--verify', 'HEAD'],
  );
  if (result.exitCode != 0) return null;
  final hash = result.stdout.toString().trim();
  return RegExp(r'^[a-f0-9]{40}$').hasMatch(hash) ? hash : null;
}

typedef _GitChange = ({String status, String path});

/// Obtener los archivos que han cambiado en la app desde el último commit.
Future<List<_GitChange>?> _readGitChanges(
  String root,
  String before,
  String after,
  String appPath,
) async {
  final result = await Process.run('git', [
    '-C', root, 'diff', '--name-status', before, after, '--',
    '${appPath}lib/', '${appPath}assets/', '${appPath}pubspec.yaml',
    '${appPath}pubspec.lock', '${appPath}android/', '${appPath}ios/',
    'shared/', 'ai/flutter_client/', 'scripts/flutter-dev-runner.dart',
  ]);
  if (result.exitCode != 0) return null;
  final changes = <_GitChange>[];
  for (final line in result.stdout.toString().split('\n')) {
    final fields = line.trim().split('\t');
    if (fields.length < 2) continue;
    // R/C: el último campo es el destino nuevo.
    final path = fields.last.replaceAll('\\', '/');
    changes.add((status: fields.first.substring(0, 1), path: path));
  }
  return changes;
}
