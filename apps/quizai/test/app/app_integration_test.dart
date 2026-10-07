import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/app/app.dart';
import 'package:quizai/app/app_theme.dart';
import 'package:quizai/app/profile/profile_page.dart';
import 'package:quizai/app/settings/settings_page.dart';
import 'package:quizai/modes/estudio/estudio_page.dart';
import 'package:quizai/modes/quiz10/interaction/quiz_page.dart';

Future<void> pumpApp(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const QuizAIApp());
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
        same(quizAITheme),
      );
      expect(find.byKey(const Key('quizai-home-logo-slot')), findsOneWidget);
      expect(find.byTooltip('Ajustes'), findsOneWidget);
      expect(find.byKey(const Key('quizai-bottom-nav')), findsOneWidget);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);

      final orderedBlocks = [
        find.byKey(const Key('quizai-home-quiz10')),
        find.byKey(const Key('quizai-home-salas-header')),
        find.byKey(const Key('quizai-home-salas')),
        find.byKey(const Key('quizai-home-document')),
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

      final quiz10Width = tester.getSize(
        find.byKey(const Key('quizai-home-quiz10')),
      ).width;
      final salasWidth = tester.getSize(
        find.byKey(const Key('quizai-home-salas')),
      ).width;
      final documentWidth = tester.getSize(
        find.byKey(const Key('quizai-home-document')),
      ).width;

      expect(
        quiz10Width,
        lessThanOrEqualTo(
          QuizLayout.maxWidth - 2 * QuizLayout.horizontalPadding,
        ),
      );
      expect(salasWidth, closeTo(quiz10Width, 0.01));
      expect(documentWidth, closeTo(quiz10Width, 0.01));

      final navPosition = tester.getTopLeft(
        find.byKey(const Key('quizai-bottom-nav')),
      );
      final headerPosition = tester.getTopLeft(
        find.byKey(const Key('quizai-home-logo-slot')),
      );
      await tester.drag(
        find.byKey(const Key('quizai-home-scroll')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('quizai-bottom-nav'))),
        navPosition,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('quizai-home-logo-slot'))),
        headerPosition,
      );

      final documentBottom = tester
          .getBottomLeft(find.byKey(const Key('quizai-home-document')))
          .dy;
      final navTop = tester
          .getTopLeft(find.byKey(const Key('quizai-bottom-nav')))
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
        await tester.tap(find.byKey(const Key('quizai-nav-perfil')));
        await tester.pumpAndSettle();
        expect(find.byType(ProfilePage), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Experiencia'), findsOneWidget);
      expect(find.byKey(const Key('quizai-bottom-nav')), findsNothing);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(
        find.byType(ProfilePage),
        fromProfile ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const Key('quizai-home-quiz10')),
        fromProfile ? findsNothing : findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const Key('quizai-nav-inicio')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quizai-home-quiz10')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Quiz10 y Estudio abren sus pantallas Material y regresan a Home',
    (tester) async {
      await pumpApp(tester, const Size(390, 844));
      await tester.tap(find.byKey(const Key('quizai-home-quiz10')));
      await tester.pumpAndSettle();
      expect(find.byType(QuizPage), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Jugar'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(QuizPage))).scaffoldBackgroundColor,
        QuizPalette.surface,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quizai-home-quiz10')), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('quizai-document-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quizai-document-button')));
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
      expect(find.byKey(const Key('quizai-bottom-nav')), findsOneWidget);
      expect(find.byKey(const Key('quizai-home-document')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
