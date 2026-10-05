import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/app/app.dart';
import 'package:quizai/app/app_theme.dart';
import 'package:quizai/app/home/modalidad_card.dart';
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
    testWidgets('Home conserva identidad, orden y navegación a $size', (
      tester,
    ) async {
      await pumpApp(tester, size);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).theme,
        same(quizAITheme),
      );
      expect(find.text('QuizAI'), findsOneWidget);
      expect(find.byTooltip('Ajustes'), findsOneWidget);
      expect(find.byKey(const Key('quizai-bottom-nav')), findsOneWidget);
      expect(find.text('Modalidades'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);

      final orderedCards = [
        find.byKey(const Key('quizai-hero')),
        find.byKey(const Key('quizai-card-sala')),
        find.byKey(const Key('quizai-card-1vs1')),
        find.byKey(const Key('quizai-card-estudio')),
      ];
      for (var i = 0; i < orderedCards.length; i++) {
        expect(orderedCards[i], findsOneWidget);
        if (i > 0) {
          expect(
            tester.getTopLeft(orderedCards[i]).dy,
            greaterThan(tester.getTopLeft(orderedCards[i - 1]).dy),
          );
        }
      }
      for (final id in ['sala', '1vs1']) {
        expect(
          tester
              .widget<ModalidadCard>(
                find.byWidgetPredicate(
                  (widget) => widget is ModalidadCard && widget.id == id,
                ),
              )
              .onTap,
          isNull,
        );
      }
      expect(
        tester.getSize(orderedCards.first).width,
        lessThanOrEqualTo(
          QuizLayout.maxWidth - 2 * QuizLayout.horizontalPadding,
        ),
      );
      if (size.height == 500) {
        expect(find.byKey(const Key('quizai-home-scroll')), findsOneWidget);
        final navPosition = tester.getTopLeft(
          find.byKey(const Key('quizai-bottom-nav')),
        );
        await tester.drag(
          find.byKey(const Key('quizai-home-scroll')),
          const Offset(0, -250),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(const Key('quizai-bottom-nav'))),
          navPosition,
        );
      }
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
        find.byKey(const Key('quizai-hero')),
        fromProfile ? findsNothing : findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const Key('quizai-nav-modalidades')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quizai-hero')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Quiz10 y Estudio abren sus pantallas Material y regresan a Home',
    (tester) async {
      await pumpApp(tester, const Size(390, 844));
      await tester.tap(find.byKey(const Key('quizai-hero')));
      await tester.pumpAndSettle();
      expect(find.byType(QuizPage), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Jugar'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(QuizPage))).scaffoldBackgroundColor,
        QuizPalette.surface,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quizai-hero')), findsOneWidget);

      await tester.tap(find.byKey(const Key('quizai-card-estudio')));
      await tester.pumpAndSettle();
      expect(find.byType(EstudioPage), findsOneWidget);
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
      expect(find.byKey(const Key('quizai-card-estudio')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
