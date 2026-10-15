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

Future<void> main(List<String> args) async {
  if (args.length == 2 && args.first == '--fake-machine') {
    await fakeMachine(args[1]);
    return;
  }
  final directory = await Directory.systemTemp.createTemp('ai-apps-flutter-machine-');
  final trace = File('${directory.path}${Platform.pathSeparator}requests.jsonl');
  final process = await Process.start(
    Platform.resolvedExecutable,
    [Platform.script.toFilePath(), '--fake-machine', trace.path],
  );
  try {
    final controller = runner.FlutterMachineController(
      process, updateTimeout: const Duration(seconds: 1),
    );
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

    // Una nueva edición permite volver a actualizar la sesión.
    await controller.reload();
    requests = await waitRequests(trace, 4);
    require(requests[3]['fullRestart'] == false,
      'A new source change can retry after failed restart');

    // Tras agotar el plazo de respuesta se relanza solo el proceso propiedad
    // del runner, sin manipular los demás dispositivos ni Flutter.
    await controller.reload();
    await waitRequests(trace, 5);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    require(controller.relaunchRequested,
      'A blocked machine triggers a bounded, owned-process relaunch');
    controller.dispose();

    stdout.writeln('PASS: serialización, fallback, sin bucle y watchdog seguro.');
  } finally {
    process.kill();
    await directory.delete(recursive: true);
  }
}

