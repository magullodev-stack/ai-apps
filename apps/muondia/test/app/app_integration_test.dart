import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muondia/app/app_shell.dart';
import 'package:muondia/app/app_theme.dart';
import 'package:muondia/app/profile/profile_page.dart';
import 'package:muondia/app/settings/settings_page.dart';
import 'package:muondia/modes/estudio/estudio_page.dart';

Future<void> pumpApp(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(theme: muondiaTheme, home: const AppShell()),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(390, 500),
    const Size(900, 1100),
  ]) {
    testWidgets('Home conserva estructura y navegación a $size', (
      tester,
    ) async {
      await pumpApp(tester, size);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).theme,
        same(muondiaTheme),
      );
      expect(find.byKey(const Key('muondia-home-logo-slot')), findsOneWidget);
      expect(find.byTooltip('Ajustes'), findsOneWidget);
      expect(find.byKey(const Key('muondia-bottom-nav')), findsOneWidget);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);

      final orderedBlocks = [
        find.byKey(const Key('muondia-home-salas')),
        find.byKey(const Key('muondia-home-document')),
      ];
      for (var i = 0; i < orderedBlocks.length; i++) {
        expect(orderedBlocks[i], findsOneWidget);
        if (i > 0) {
          expect(
            tester.getTopLeft(orderedBlocks[i]).dy,
            greaterThan(tester.getTopLeft(orderedBlocks[i - 1]).dy),
          );
        }
      }

      final salasWidth = tester.getSize(
        find.byKey(const Key('muondia-home-salas')),
      ).width;
      final documentWidth = tester.getSize(
        find.byKey(const Key('muondia-home-document')),
      ).width;

      expect(
        salasWidth,
        lessThanOrEqualTo(
          QuizLayout.maxWidth - 2 * QuizLayout.horizontalPadding,
        ),
      );
      expect(documentWidth, closeTo(salasWidth, 0.01));

      final navPosition = tester.getTopLeft(
        find.byKey(const Key('muondia-bottom-nav')),
      );
      final headerPosition = tester.getTopLeft(
        find.byKey(const Key('muondia-home-logo-slot')),
      );
      await tester.drag(
        find.byKey(const Key('muondia-home-scroll')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('muondia-bottom-nav'))),
        navPosition,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('muondia-home-logo-slot'))),
        headerPosition,
      );

      final documentBottom = tester
          .getBottomLeft(find.byKey(const Key('muondia-home-document')))
          .dy;
      final navTop = tester
          .getTopLeft(find.byKey(const Key('muondia-bottom-nav')))
          .dy;
      expect(documentBottom, lessThanOrEqualTo(navTop - 20));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Perfil y Ajustes conservan la pestaña al regresar', (
    tester,
  ) async {
    await pumpApp(tester, const Size(390, 844));
    for (final fromProfile in [false, true]) {
      if (fromProfile) {
        await tester.tap(find.byKey(const Key('muondia-nav-perfil')));
        await tester.pumpAndSettle();
        expect(find.byType(ProfilePage), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Experiencia'), findsOneWidget);
      expect(find.byKey(const Key('muondia-bottom-nav')), findsNothing);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(
        find.byType(ProfilePage),
        fromProfile ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const Key('muondia-home-salas')),
        fromProfile ? findsNothing : findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const Key('muondia-nav-inicio')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muondia-home-salas')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Estudio abre su pantalla Material y regresa a Home',
    (tester) async {
      await pumpApp(tester, const Size(390, 844));
      await tester.ensureVisible(
        find.byKey(const Key('muondia-document-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('muondia-document-button')));
      await tester.pumpAndSettle();
      expect(find.byType(EstudioPage), findsOneWidget);
      expect(find.byKey(const Key('estudio-upload-card')), findsOneWidget);
      expect(find.byKey(const Key('estudio-upload-file')), findsOneWidget);
      expect(find.text('Subir archivo'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Generar'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(EstudioPage)))
            .scaffoldBackgroundColor,
        QuizPalette.surface,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('muondia-bottom-nav')), findsOneWidget);
      expect(find.byKey(const Key('muondia-home-document')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
