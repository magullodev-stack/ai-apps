// Prueba real del protocolo --machine, sin Android, Flutter ni credenciales.
// Ejecutar: dart scripts/flutter-dev-runner-machine-test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'flutter-dev-runner.dart' as runner;

Future<void> fakeMachine(String tracePath) async {
  stdout.writeln(jsonEncode([
    {'event': 'app.start', 'params': {'appId': 'fake-app', 'deviceId': 'fake'}}
  ]));
  stdout.writeln(jsonEncode([{'event': 'app.started'}]));

  var requestCount = 0;
  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final messages = jsonDecode(line) as List<dynamic>;
    for (final raw in messages) {
      final request = Map<String, dynamic>.from(raw as Map);
      final params = Map<String, dynamic>.from(request['params'] as Map);
      if (request['method'] != 'app.restart') {
        throw StateError('Unexpected machine method: ${request['method']}');
      }
      requestCount++;
      File(tracePath).writeAsStringSync(
        jsonEncode({'id': request['id'], 'fullRestart': params['fullRestart']}) + '\n',
        mode: FileMode.append,
      );
      // Dejar tiempo para que lleguen varios cambios antes de responder.
      await Future<void>.delayed(const Duration(milliseconds: 110));
      // 1) Reload rejected, 2) Fallback restart succeeds,
      // 3) Explicit restart fails, 4) New edit succeeds,
      // 5) Machine stops replying (watchdog recovery).
      if (requestCount == 5) continue;
      final code = requestCount == 1 ? 1 : requestCount == 3 ? 2 : 0;
      stdout.writeln(jsonEncode([
        {'id': request['id'], 'result': {'code': code}}
      ]));
    }
  }
}

Future<void> fakeConnectionMachine() async {
  stdout.writeln(jsonEncode([
    {'event': 'app.start', 'params': {'appId': 'fake-app', 'deviceId': 'fake'}},
    {'event': 'app.started'},
  ]));
  await for (final command in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (command == 'app-log') {
      stdout.writeln(jsonEncode([
        {'event': 'app.log', 'params': {'log': 'Lost connection to device.'}},
        {'event': 'app.log', 'params': {'log': 'Example: Lost connection to device.'}},
      ]));
    } else if (command == 'daemon-log') {
      stdout.writeln(jsonEncode([
        {'event': 'daemon.logMessage', 'params': {'message': 'Lost connection to device.'}},
      ]));
    } else if (command == 'plain-loss') {
      stdout.writeln('Lost connection to device.');
    }
  }
}

Future<List<Map<String, dynamic>>> waitRequests(File trace, int count) async {
  for (var attempt = 0; attempt < 180; attempt++) {
    if (trace.existsSync()) {
      final lines = trace.readAsLinesSync().where((line) => line.isNotEmpty);
      if (lines.length >= count) {
        return lines.map((line) =>
          Map<String, dynamic>.from(jsonDecode(line) as Map)).toList();
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError('Flutter machine simulator stalled waiting for $count requests');
}

void require(bool condition, String description) {
  if (!condition) throw StateError('FAIL: $description');
}

void verifyAdbDeviceRecognition() {
  require(runner.adbListsOnlineDevice(
    'List of devices attached\nemulator-5554\tdevice\nemulator-5556\toffline\n',
    'emulator-5554'), 'Solo el dispositivo online cuenta como recuperado');
  require(!runner.adbListsOnlineDevice(
    'List of devices attached\nemulator-5554\toffline\n',
    'emulator-5554'), 'Un emulador offline debe tratarse como ausente');
  require(!runner.adbListsOnlineDevice(
    'List of devices attached\nemulator-5556\tdevice\n',
    'emulator-5554'), 'Otro emulador online no sustituye a Muondia');
  require(!runner.adbListsOnlineDevice(
    'List of devices attached\n',
    'emulator-5554'), 'Un AVD desaparecido no está conectado');
}

void verifyDeviceRecoveryPolicy() {
  final policy = runner.FlutterDeviceRecoveryPolicy();
  for (var i = 0; i < 10; i++) {
    require(policy.observe(vmDisconnected: false, androidOnline: false) ==
        runner.FlutterDeviceRecoveryAction.none,
      'ADB ausente no debe terminar una VM Flutter conectada');
  }
  require(policy.observe(vmDisconnected: true, androidOnline: false) ==
      runner.FlutterDeviceRecoveryAction.none, 'Primera ausencia es transitoria');
  require(policy.observe(vmDisconnected: true, androidOnline: false) ==
      runner.FlutterDeviceRecoveryAction.none, 'Segunda ausencia es transitoria');
  require(policy.observe(vmDisconnected: true, androidOnline: null) ==
      runner.FlutterDeviceRecoveryAction.none, 'ADB bloqueado no demuestra fallo Android');
  require(policy.observe(vmDisconnected: true, androidOnline: false) ==
      runner.FlutterDeviceRecoveryAction.none, 'La ausencia desconocida rompe la secuencia');
  require(policy.observe(vmDisconnected: true, androidOnline: true) ==
      runner.FlutterDeviceRecoveryAction.relaunchFlutter,
    'VM perdida con Android vivo solo recupera Flutter');
  require(policy.observe(vmDisconnected: true, androidOnline: false) ==
      runner.FlutterDeviceRecoveryAction.none, 'Android vivo reinicia la secuencia');
  require(policy.observe(vmDisconnected: true, androidOnline: false) ==
      runner.FlutterDeviceRecoveryAction.none, 'Dos ausencias aún no recuperan Android');
  require(policy.observe(vmDisconnected: true, androidOnline: false) ==
      runner.FlutterDeviceRecoveryAction.recoverDevice,
    'Tres ausencias confirmadas tras perder VM permiten recuperar el dispositivo');
}

void verifyContentDeduplication(Directory directory) {
  final assetDirectory = Directory('${directory.path}/assets')..createSync();
  final asset = File('${assetDirectory.path}/image.png')..writeAsBytesSync([1, 2, 3]);
  final dart = File('${directory.path}/widget.dart')..writeAsStringSync('first');
  final tracker = runner.FlutterContentTracker()..seedDirectory(directory);
  require(tracker.status(asset.path) == runner.FlutterContentStatus.applied,
    'El arranque ya compila los archivos presentes');
  asset.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 1)));
  require(!tracker.queue(asset.path),
    'Cambiar metadatos sin cambiar bytes no debe reiniciar Flutter');

  asset.writeAsBytesSync([4, 5, 6]);
  require(tracker.queue(asset.path) && tracker.beginUpdate(),
    'Una sustitución local del PNG debe actualizarse');
  require(tracker.status(asset.path) == runner.FlutterContentStatus.scheduled &&
      !tracker.queue(asset.path),
    'El commit durante Hot Restart debe esperar, sin encolar otra operación');
  tracker.settle(true);
  require(tracker.status(asset.path) == runner.FlutterContentStatus.applied &&
      !tracker.queue(asset.path) && !tracker.beginUpdate(),
    'Confirmar en Git el PNG ya aplicado no debe repetir Hot Restart');

  dart.writeAsStringSync('second');
  require(tracker.queue(dart.path) && tracker.beginUpdate(),
    'Una nueva versión Dart requiere actualizarse');
  dart.writeAsStringSync('third');
  require(tracker.queue(dart.path),
    'Cambiar el mismo archivo durante una recarga conserva su nueva versión');
  tracker.settle(true);
  require(tracker.status(dart.path) == runner.FlutterContentStatus.scheduled &&
      tracker.beginUpdate(),
    'Confirmar la versión anterior no consume la modificación posterior');
  tracker.settle(false);
  require(tracker.status(dart.path) == runner.FlutterContentStatus.changed,
    'Una recarga fallida no debe acreditar los nuevos bytes');
  require(tracker.queue(dart.path) && tracker.beginUpdate(),
    'La versión no aplicada sigue disponible para recuperación');
  tracker.settle(true);
  require(tracker.status(dart.path) == runner.FlutterContentStatus.applied,
    'Solo el éxito Flutter acredita el contenido');

  dart.writeAsStringSync('temporary');
  require(tracker.queue(dart.path), 'La edición temporal entra en cola');
  dart.writeAsStringSync('third');
  require(!tracker.queue(dart.path) && !tracker.beginUpdate(),
    'Restaurar antes del debounce no debe recargar sin cambios');
}

void verifyUpdateClassification() {
  final cases = <({String path, String status, runner.FlutterChangeAction expected})>[
    (
      path: 'apps/muondia/lib/app/onboarding/interaction/onboarding_quiz_scene.dart',
      status: 'M',
      expected: runner.FlutterChangeAction.reload,
    ),
    (
      path: r'C:\ai-apps\apps\muondia\lib\app\onboarding\interaction\onboarding_quiz_scene.dart',
      status: 'M',
      expected: runner.FlutterChangeAction.reload,
    ),
    (
      path: 'apps/muondia/lib/main.dart',
      status: 'M',
      expected: runner.FlutterChangeAction.restart,
    ),
    (
      path: 'apps/muondia/assets/onboarding/test/quiz_background.png',
      status: 'M',
      expected: runner.FlutterChangeAction.restart,
    ),
    (
      path: 'apps/muondia/assets/onboarding/test/new_background.png',
      status: 'A',
      expected: runner.FlutterChangeAction.rebuild,
    ),
    (
      path: 'apps/muondia/assets/onboarding/test/Caja Test.png',
      status: 'D',
      expected: runner.FlutterChangeAction.rebuild,
    ),
    (
      path: 'apps/muondia/assets/onboarding/test/renamed.png',
      status: 'R',
      expected: runner.FlutterChangeAction.rebuild,
    ),
    (
      path: 'apps/muondia/pubspec.yaml',
      status: 'M',
      expected: runner.FlutterChangeAction.rebuild,
    ),
    (
      path: 'apps/muondia/android/app/build.gradle.kts',
      status: 'M',
      expected: runner.FlutterChangeAction.rebuild,
    ),
    (
      path: 'shared/packages/ai_apps_ui/lib/button.dart',
      status: 'M',
      expected: runner.FlutterChangeAction.reload,
    ),
    (
      path: 'apps/muondia/README.md',
      status: 'M',
      expected: runner.FlutterChangeAction.none,
    ),
    (
      path: 'scripts/flutter-dev-runner.dart',
      status: 'M',
      expected: runner.FlutterChangeAction.rebuild,
    ),
    (
      path: r'C:\ai-apps\scripts\flutter-dev-runner.dart',
      status: 'M',
      expected: runner.FlutterChangeAction.rebuild,
    ),
    (
      path: 'apps/muondia/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java',
      status: 'M',
      expected: runner.FlutterChangeAction.none,
    ),
    (
      path: r'C:\ai-apps\apps\muondia\android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java',
      status: 'A',
      expected: runner.FlutterChangeAction.none,
    ),
    (
      path: 'apps/muondia/android/app/src/main/kotlin/com/aiapps/muondia/MainActivity.kt',
      status: 'M',
      expected: runner.FlutterChangeAction.rebuild,
    ),
    (
      path: 'apps/muondia/android/local.properties',
      status: 'M',
      expected: runner.FlutterChangeAction.none,
    ),
    (
      path: 'build/generated.dart',
      status: 'M',
      expected: runner.FlutterChangeAction.none,
    ),
    (
      path: 'apps/muondia/build/generated/test.dart',
      status: 'M',
      expected: runner.FlutterChangeAction.none,
    ),
  ];
  for (final item in cases) {
    final actual = runner.classifyFlutterChange(
      item.path, status: item.status,
    );
    require(actual == item.expected,
      'Clasificación incorrecta: ${item.path} (${item.status}) => '
      '$actual; esperado ${item.expected}');
  }
  // Si un commit tiene varios archivos, gana el cambio más fuerte.
  final mixed = [
    runner.classifyFlutterChange('apps/muondia/lib/a.dart'),
    runner.classifyFlutterChange('apps/muondia/assets/new.png', status: 'A'),
  ];
  require(mixed.reduce((a, b) => a.index > b.index ? a : b) ==
      runner.FlutterChangeAction.rebuild,
    'La reconstrucción tiene prioridad sobre hot reload');
}

Future<void> main(List<String> args) async {
  if (args.length == 1 && args.first == '--connection-machine') {
    await fakeConnectionMachine();
    return;
  }
  if (args.length == 2 && args.first == '--fake-machine') {
    await fakeMachine(args[1]);
    return;
  }
  verifyUpdateClassification();
  verifyAdbDeviceRecognition();
  verifyDeviceRecoveryPolicy();
  final directory = await Directory.systemTemp.createTemp('ai-apps-flutter-machine-');
  verifyContentDeduplication(directory);
  final trace = File('${directory.path}${Platform.pathSeparator}requests.jsonl');
  final process = await Process.start(
    Platform.resolvedExecutable,
    [Platform.script.toFilePath(), '--fake-machine', trace.path],
  );
  try {
    final controller = runner.FlutterMachineController(
      process, updateTimeout: const Duration(seconds: 1),
    );
    final settled = <String>[];
    controller.onUpdateSettled = (success, fullRestart) =>
        settled.add('$success:$fullRestart');
    final ready = Completer<void>();
    controller.onReady = () {
      if (!ready.isCompleted) ready.complete();
    };
    await ready.future.timeout(const Duration(seconds: 20));

    // Dos ediciones seguidas no deben emitir órdenes concurrentes.
    await controller.reload();
    await controller.reload();
    var requests = await waitRequests(trace, 2);
    require(requests.length == 2, 'Only reload + fallback restart');
    require(requests[0]['fullRestart'] == false,
      'First source edit uses hot reload');
    require(requests[1]['fullRestart'] == true,
      'Failed hot reload must trigger automatic hot restart');
    await Future<void>.delayed(const Duration(milliseconds: 260));
    require(settled.join(',') == 'true:true',
      'Only a successful fallback restart may acknowledge the update');

    await Future<void>.delayed(const Duration(milliseconds: 240));
    requests = await waitRequests(trace, 2);
    require(requests.length == 2,
      'Queued source edits are coalesced into the recovery restart');

    // Si falla también un restart, no entrar en bucles automáticos.
    await controller.restart();
    requests = await waitRequests(trace, 3);
    require(requests[2]['fullRestart'] == true,
      'Explicit restart uses fullRestart=true');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    require((await waitRequests(trace, 3)).length == 3,
      'Failed restart must not cause a restart loop');
    require(settled.join(',') == 'true:true,false:true',
      'A failed Hot Restart must not be acknowledged');

    // Una nueva edición permite volver a actualizar la sesión.
    await controller.reload();
    requests = await waitRequests(trace, 4);
    require(requests[3]['fullRestart'] == false,
      'A new source change can retry after failed restart');
    await Future<void>.delayed(const Duration(milliseconds: 220));
    require(settled.join(',') == 'true:true,false:true,true:false',
      'A subsequent successful edit should be acknowledged');

    // Tras agotar el plazo de respuesta se relanza solo el proceso propiedad
    // del runner, sin manipular los demás dispositivos ni Flutter.
    await controller.reload();
    await waitRequests(trace, 5);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    require(controller.relaunchRequested,
      'A blocked machine triggers a bounded, owned-process relaunch');
    controller.dispose();

    // La pérdida de ADB debe solicitar recuperación del dispositivo (88),
    // no una reconstrucción ordinaria (86) ni matar un proceso ajeno.
    final lostProcess = await Process.start(
      Platform.resolvedExecutable,
      [Platform.script.toFilePath(), '--fake-machine', trace.path],
    );
    try {
      final lostController = runner.FlutterMachineController(lostProcess);
      final started = Completer<void>();
      lostController.onReady = () {
        if (!started.isCompleted) started.complete();
      };
      await started.future.timeout(const Duration(seconds: 20));
      lostController.requestDeviceRecovery();
      require(lostController.lostConnection &&
          lostController.deviceRecoveryRequested &&
          !lostController.relaunchRequested &&
          !lostController.stopRequested,
        'Pérdida ADB debe distinguirse de rebuild y parada manual');
      await lostProcess.exitCode.timeout(const Duration(seconds: 15));
      lostController.dispose();
    } finally {
      lostProcess.kill();
    }

    // Los logs de la app son contenido arbitrario. Solo la señal de Flutter
    // marca una VM perdida, y esa señal no demuestra que Android haya caído.
    for (final signal in ['daemon-log', 'plain-loss']) {
      final connectionProcess = await Process.start(
        Platform.resolvedExecutable,
        [Platform.script.toFilePath(), '--connection-machine'],
      );
      final connectionController = runner.FlutterMachineController(connectionProcess);
      try {
        final connected = Completer<void>();
        connectionController.onReady = () => connected.complete();
        await connected.future.timeout(const Duration(seconds: 20));
        connectionProcess.stdin.writeln('app-log');
        await Future<void>.delayed(const Duration(milliseconds: 150));
        require(!connectionController.lostConnection,
          'El texto de app.log no debe solicitar ninguna recuperación');
        connectionProcess.stdin.writeln(signal);
        for (var attempt = 0; attempt < 100 && !connectionController.lostConnection; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        require(connectionController.lostConnection &&
            !connectionController.deviceRecoveryRequested &&
            !connectionController.relaunchRequested,
          'La pérdida VM no debe matar Flutter ni declarar el AVD averiado');
        // El monitor puede recuperar solo el proceso propio si ADB sigue vivo.
        connectionController.requestRelaunch();
        await connectionProcess.exitCode.timeout(const Duration(seconds: 15));
        require(connectionController.relaunchRequested &&
            !connectionController.deviceRecoveryRequested,
          'Recuperar VM no debe convertirse en recuperación Android');
      } finally {
        connectionController.dispose();
        connectionProcess.kill();
      }
    }

    stdout.writeln('PASS: clasificación, fallback, VM/ADB tolerante y recuperación de proceso propio.');
  } finally {
    process.kill();
    await directory.delete(recursive: true);
  }
}

