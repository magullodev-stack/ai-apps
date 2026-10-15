import 'package:ai_apps_ui/ai_apps_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('La visibilidad es reversible, validada y exclusiva de debug', () {
    final inspector = AiAppsVisualAssetController();
    expect(inspector.isVisible('assets/auth/Example.png'), isTrue);
    expect(inspector.setVisible('assets/auth/Example.png', false), isTrue);
    expect(inspector.isVisible('assets/auth/Example.png'), isFalse);
    expect(inspector.setVisible('assets/auth/Example.png', true), isTrue);
    expect(inspector.isVisible('assets/auth/Example.png'), isTrue);
    expect(inspector.setVisible('../../archivo.png', false), isFalse);
    expect(inspector.setVisible('assets/auth/Robot.dart', false), isFalse);
    inspector.dispose();
  });

  testWidgets('El scope instala DefaultAssetBundle sin modificar widgets',
      (tester) async {
    final controller = AiAppsVisualAssetController();
    await tester.pumpWidget(MaterialApp(
      home: AiAppsVisualAssetScope(
        controller: controller,
        child: const Text('Vista reutilizable'),
      ),
    ));
    expect(find.text('Vista reutilizable'), findsOneWidget);
    expect(find.byType(DefaultAssetBundle), findsWidgets);

    // El recurso no necesita existir en disco para quedar oculto: el
    // bundle intercepta la petición y devuelve un PNG RGBA transparente.
    expect(controller.setVisible('assets/auth/Example.png', false), isTrue);
    await tester.pump();
    final context = tester.element(find.text('Vista reutilizable'));
    final byteData = await DefaultAssetBundle.of(context)
        .load('assets/auth/Example.png');
    expect(byteData.lengthInBytes, greaterThan(40));
    final header = byteData.buffer.asUint8List(0, 8);
    expect(header, orderedEquals([137, 80, 78, 71, 13, 10, 26, 10]));

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('El canal global acepta cambios de visibilidad',
      (tester) async {
    final controller = AiAppsVisualAssetController();
    controller.connectDebugChannel();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    await messenger.handlePlatformMessage(
      'ai_apps/visual_inspector',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('setAssetVisibility', {
          'asset': 'assets/auth/OtherExample.png',
          'visible': false,
        }),
      ),
      (_) {},
    );
    expect(controller.isVisible('assets/auth/OtherExample.png'), isFalse);
    controller.dispose();
  });
}
