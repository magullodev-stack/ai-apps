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

Future<void> fakeRunnerMachine(String sourcePath, String tracePath) async {
  File('$tracePath.starts').writeAsStringSync('$pid\n', mode: FileMode.append);
  stdout.writeln(jsonEncode([
    {'event': 'app.start', 'params': {'appId': 'fixture-app', 'deviceId': 'fake'}},
    {'event': 'app.started'},
  ]));
  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    for (final request in jsonDecode(line) as List<dynamic>) {
      final params = request['params'] as Map;
      File(tracePath).writeAsStringSync(
        jsonEncode({'fullRestart': params['fullRestart']}) + '\n',
        mode: FileMode.append,
      );
      stdout.writeln(jsonEncode([
        {'id': request['id'], 'result': {
          'code': File(sourcePath).readAsStringSync() == 'invalid' ? 1 : 0,
        }},
      ]));
    }
  }
}

Future<void> verifyRunnerLifecycle(Directory directory) async {
  if (!Platform.isWindows) return;
  final fixture = Directory('${directory.path}/runner-fixture')..createSync();
  final app = Directory('${fixture.path}/apps/fixture')..createSync(recursive: true);
  final lib = Directory('${app.path}/lib')..createSync();
  final source = File('${lib.path}/widget.dart')..writeAsStringSync('initial');
  final assets = Directory('${app.path}/assets')..createSync();
  final existingAsset = File('${assets.path}/existing.png')..writeAsBytesSync([1, 2, 3]);
  final trace = File('${fixture.path}/requests.jsonl');
  final wrapper = File('${fixture.path}/flutter.cmd')..writeAsStringSync(
    '@echo off\r\n"${Platform.resolvedExecutable}" '
    '"${Platform.script.toFilePath()}" --runner-machine '
    '"${source.path}" "${trace.path}"\r\n',
  );
  Future<void> git(List<String> args) async {
    final result = await Process.run('git', [
      '-C', fixture.path, '-c', 'user.name=Runner Fixture',
      '-c', 'user.email=runner-fixture@example.invalid', ...args,
    ]);
    require(result.exitCode == 0, 'Git local del fixture debe completar ${args.first}');
  }
  Future<void> commit() async {
    await git(['add', 'apps']);
    await git(['commit', '-qm', 'fixture']);
  }
  await git(['init', '-b', 'dev']);
  await commit();
  final runnerScript = File.fromUri(Platform.script.resolve('flutter-dev-runner.dart'));
  final runnerArgs = [
    runnerScript.path, '--flutter', wrapper.path, '--device', 'fake',
    '--defines-file', '${fixture.path}/defines.json',
    '--working-directory', app.path, '--watch', app.path,
  ];
  final process = await Process.start(Platform.resolvedExecutable, runnerArgs);
  final output = <String>[];
  final stdoutSubscription = process.stdout.transform(utf8.decoder)
      .transform(const LineSplitter()).listen(output.add);
  final stderrSubscription = process.stderr.transform(utf8.decoder)
      .transform(const LineSplitter()).listen(output.add);
  var exited = false;
  unawaited(process.exitCode.then((_) { exited = true; }));
  try {
    for (var i = 0; i < 200 &&
        !output.any((line) => line.startsWith('Hot reload automatico activo:')); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    require(!exited && output.any((line) => line.startsWith('Hot reload automatico activo:')),
      'El runner principal debe iniciar el Flutter simulado');
    source.writeAsStringSync('invalid');
    await waitRequests(trace, 2);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    require(!exited && File('${trace.path}.starts').readAsLinesSync().length == 1 &&
        output.any((line) => line.contains('se conserva la app hasta una nueva modificacion')),
      'Compilación inválida debe conservar el mismo Flutter tras rechazar reload y restart');
    await commit();
    await Future<void>.delayed(const Duration(milliseconds: 4500));
    require((await waitRequests(trace, 2)).length == 2 &&
        File('${trace.path}.starts').readAsLinesSync().length == 1,
      'Confirmar código inválido en Git no debe repetir actualizaciones ni recompilar');
    source.writeAsStringSync('fixed');
    await waitRequests(trace, 3);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    require(output.contains('Hot restart completado.'),
      'Los nuevos bytes válidos permiten volver a actualizar');
    await commit();
    await Future<void>.delayed(const Duration(milliseconds: 4500));
    require((await waitRequests(trace, 3)).length == 3 && !exited &&
        File('${trace.path}.starts').readAsLinesSync().length == 1,
      'El commit posterior a la recarga no debe iniciar una segunda operación ni otro Flutter');

    // Un checkout Git de Windows puede emitir delete/create para sustituir
    // el mismo PNG. Solo el estado tras el debounce decide si cambió el bundle.
    existingAsset.deleteSync();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    existingAsset.writeAsBytesSync([4, 5, 6]);
    final replacedRequests = await waitRequests(trace, 4);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    require(replacedRequests[3]['fullRestart'] == true && !exited &&
        File('${trace.path}.starts').readAsLinesSync().length == 1,
      'Delete/create de un PNG existente solo debe hacer Hot Restart del mismo Flutter');
    await commit();
    await Future<void>.delayed(const Duration(milliseconds: 4500));
    require((await waitRequests(trace, 4)).length == 4 && !exited,
      'El commit del PNG sustituido no debe repetir el Hot Restart');

    final addedAsset = File('${assets.path}/added.png')..writeAsBytesSync([7, 8, 9]);
    require(await process.exitCode.timeout(const Duration(seconds: 12)) == 86 &&
        (await waitRequests(trace, 4)).length == 4,
      'Un alta real de PNG exige reconstrucción en vez de Hot Restart');
    await commit();

    final deletionProcess = await Process.start(Platform.resolvedExecutable, runnerArgs);
    final deletionOutput = <String>[];
    final deletionStdout = deletionProcess.stdout.transform(utf8.decoder)
        .transform(const LineSplitter()).listen(deletionOutput.add);
    final deletionStderr = deletionProcess.stderr.drain<void>();
    var deletionExited = false;
    unawaited(deletionProcess.exitCode.then((_) { deletionExited = true; }));
    try {
      for (var i = 0; i < 200 &&
          !deletionOutput.any((line) => line.startsWith('Hot reload automatico activo:')); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      require(!deletionExited &&
          deletionOutput.any((line) => line.startsWith('Hot reload automatico activo:')),
        'La sesión reconstruida debe inventariar el PNG añadido');
      addedAsset.deleteSync();
      require(await deletionProcess.exitCode.timeout(const Duration(seconds: 12)) == 86 &&
          (await waitRequests(trace, 4)).length == 4 &&
          File('${trace.path}.starts').readAsLinesSync().length == 2,
        'Una baja real de PNG exige reconstrucción, sin otro app.restart');
    } finally {
      if (!deletionExited) {
        await Process.run('taskkill.exe', ['/PID', '${deletionProcess.pid}', '/T', '/F']);
      }
      await deletionProcess.exitCode;
      await deletionStdout.cancel();
      await deletionStderr;
    }

    // Tras compilar una baja local, confirmar después esa misma ausencia
    // en Git tampoco debe provocar otra reconstrucción.
    final absentProcess = await Process.start(Platform.resolvedExecutable, runnerArgs);
    final absentOutput = <String>[];
    final absentStdout = absentProcess.stdout.transform(utf8.decoder)
        .transform(const LineSplitter()).listen(absentOutput.add);
    final absentStderr = absentProcess.stderr.drain<void>();
    var absentExited = false;
    unawaited(absentProcess.exitCode.then((_) { absentExited = true; }));
    try {
      for (var i = 0; i < 200 &&
          !absentOutput.any((line) => line.startsWith('Hot reload automatico activo:')); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      require(!absentExited &&
          absentOutput.any((line) => line.startsWith('Hot reload automatico activo:')),
        'La nueva sesión debe arrancar con el PNG ya ausente');
      await commit();
      await Future<void>.delayed(const Duration(milliseconds: 4500));
      require(!absentExited && (await waitRequests(trace, 4)).length == 4 &&
          File('${trace.path}.starts').readAsLinesSync().length == 3,
        'Confirmar después la baja ya compilada no debe repetir Gradle ni app.restart');
    } finally {
      if (!absentExited) {
        await Process.run('taskkill.exe', ['/PID', '${absentProcess.pid}', '/T', '/F']);
      }
      await absentProcess.exitCode;
      await absentStdout.cancel();
      await absentStderr;
    }
  } finally {
    if (!exited) {
      await Process.run('taskkill.exe', ['/PID', '${process.pid}', '/T', '/F']);
    }
    await process.exitCode;
    await stdoutSubscription.cancel();
    await stderrSubscription.cancel();
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
  require(tracker.status(dart.path) == runner.FlutterContentStatus.rejected &&
      !tracker.queue(dart.path),
    'Una recarga fallida no acredita bytes ni los reintenta al confirmarlos en Git');
  dart.writeAsStringSync('fourth');
  require(tracker.queue(dart.path) && tracker.beginUpdate(),
    'La versión no aplicada sigue disponible para recuperación');
  tracker.settle(true);
  require(tracker.status(dart.path) == runner.FlutterContentStatus.applied,
    'Solo el éxito Flutter acredita el contenido');

  dart.writeAsStringSync('temporary');
  require(tracker.queue(dart.path), 'La edición temporal entra en cola');
  dart.writeAsStringSync('fourth');
  require(!tracker.queue(dart.path) && !tracker.beginUpdate(),
    'Restaurar antes del debounce no debe recargar sin cambios');

  dart.writeAsStringSync('B');
  require(tracker.queue(dart.path) && tracker.beginUpdate(), 'B pasa a estar en vuelo');
  dart.writeAsStringSync('C');
  require(tracker.queue(dart.path), 'C queda pendiente mientras B se aplica');
  dart.writeAsStringSync('B');
  require(!tracker.queue(dart.path), 'Restaurar B elimina la versión C pendiente');
  tracker.settle(true);
  require(!tracker.beginUpdate() &&
      tracker.status(dart.path) == runner.FlutterContentStatus.applied,
    'B→C→B durante recarga no debe aplicar ni acreditar la versión C abandonada');

  asset.writeAsBytesSync([7, 8, 9]);
  dart.writeAsStringSync('invalid');
  require(tracker.queue(asset.path) && tracker.queue(dart.path) && tracker.beginUpdate(),
    'El lote mixto contiene asset y Dart');
  tracker.settle(false);
  dart.writeAsStringSync('fixed');
  require(tracker.queue(dart.path), 'Corregir Dart permite un intento nuevo');
  tracker.retryRejected();
  require(tracker.beginUpdate(), 'El lote rechazado vuelve a ponerse en vuelo una sola vez');
  tracker.settle(true);
  require(tracker.status(asset.path) == runner.FlutterContentStatus.applied &&
      tracker.status(dart.path) == runner.FlutterContentStatus.applied &&
      !tracker.beginUpdate(),
    'Corregir solo Dart también aplica el asset pendiente sin dejar revisiones rechazadas');
}

void verifyGitChangeNames() {
  final changes = runner.parseFlutterGitChanges(
    'M\u0000apps/muondia/assets/Pivotes/P08 - Física.png\u0000'
    'R100\u0000apps/muondia/assets/old.png\u0000'
    'apps/muondia/assets/renamed image.png\u0000',
  );
  require(changes.length == 2 &&
      changes[0].path == 'apps/muondia/assets/Pivotes/P08 - Física.png' &&
      changes[1].status == 'R' &&
      changes[1].path == 'apps/muondia/assets/renamed image.png',
    'Git debe conservar rutas Unicode y destino del renombre para comparar sus bytes');
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
  if (args.length == 3 && args.first == '--runner-machine') {
    await fakeRunnerMachine(args[1], args[2]);
    return;
  }
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
  verifyGitChangeNames();
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

    await verifyRunnerLifecycle(directory);
    stdout.writeln('PASS: clasificación, fallback, VM/ADB tolerante y recuperación de proceso propio.');
  } finally {
    process.kill();
    await directory.delete(recursive: true);
  }
}

