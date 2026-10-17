import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muondia/app/app_theme.dart';
import 'package:muondia/app/development/experience_preview.dart';
import 'package:muondia/app/onboarding/interaction/onboarding_quiz_page.dart';
import 'package:muondia/app/onboarding/pivot_images.dart';

void main() {
  testWidgets('La cabecera sigue las diez preguntas y conserva el resultado', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var completed = 0;
    var loadCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: muondiaTheme,
        home: OnboardingQuizPage(
          previewQuestions: previewQuestions,
          loadQuestions: () async {
            loadCalls++;
            return previewQuestions;
          },
          onCompleted: () async => completed++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 10; i++) {
      final question = previewQuestions[i];
      expect(find.text(question.pivot), findsOneWidget);
      expect(find.text('${i + 1}/10'), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        onboardingPivotImageFor(question.pivot),
      );
      expect(image.fit, BoxFit.contain);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Progreso del cuestionario')),
        matchesSemantics(
          label: 'Progreso del cuestionario',
          value: '${(i + 1) * 10}%',
          textDirection: TextDirection.ltr,
        ),
      );
      expect(find.text('Aciertos: $i'), findsOneWidget);
      expect(find.text('Siguiente'), findsNothing);

      await tester.ensureVisible(find.text('Opción A'));
      await tester.tap(find.text('Opción A'));
      await tester.pump();
      expect(find.text('Aciertos: ${i + 1}'), findsOneWidget);
      expect(find.text('Siguiente'), findsNothing);
      expect(find.text('Ver resultado'), findsNothing);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton).first).onPressed,
        isNull,
        reason: 'Una sola pulsación: las demás opciones se bloquean',
      );
      final selectedDecoration = tester
          .widget<AnimatedContainer>(
            find.byKey(const Key('muondia-answer-feedback-0')),
          ).decoration as BoxDecoration;
      expect(selectedDecoration.color, MuondiaPalette.success.withAlpha(48));
      await tester.pump(const Duration(milliseconds: 499));
      expect(find.text('${i + 1}/10'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
    }

    expect(find.text('Resultado: 10 / 10'), findsOneWidget);
    expect(find.bySemanticsLabel('Progreso del cuestionario'), findsNothing);
    expect(completed, 0);
    await tester.tap(find.text('Entrar en Muondia'));
    await tester.pump();
    expect(completed, 1);
    expect(loadCalls, 0, reason: 'La preview no debe generar preguntas');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Respuesta incorrecta: rojo, correcta verde, avance sin botón', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      theme: muondiaTheme,
      home: OnboardingQuizPage(
        previewQuestions: previewQuestions,
        onCompleted: () async {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Opción B'));
    await tester.pump();
    final wrong = tester
        .widget<AnimatedContainer>(
          find.byKey(const Key('muondia-answer-feedback-1')),
        ).decoration as BoxDecoration;
    final correct = tester
        .widget<AnimatedContainer>(
          find.byKey(const Key('muondia-answer-feedback-0')),
        ).decoration as BoxDecoration;
    expect(wrong.color, MuondiaPalette.error.withAlpha(48));
    expect(correct.color, MuondiaPalette.success.withAlpha(48));
    expect(find.text('Aciertos: 0'), findsOneWidget);
    expect(find.text('Siguiente'), findsNothing);

    // Los siguientes toques durante el velo no pueden contar otra respuesta.
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton).last).onPressed,
      isNull,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('2/10'), findsOneWidget);
    expect(find.text('Aciertos: 0'), findsOneWidget);
    final cleared = tester
        .widget<AnimatedContainer>(
          find.byKey(const Key('muondia-answer-feedback-0')),
        ).decoration as BoxDecoration;
    expect(cleared.color, Colors.transparent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Salir de la página cancela el avance automático pendiente', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      theme: muondiaTheme,
      home: OnboardingQuizPage(
        previewQuestions: previewQuestions,
        onCompleted: () async {},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opción A'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Regresar respeta el navegador y no completa el recorrido', (
    tester,
  ) async {
    var completed = 0;
    Widget quiz() => OnboardingQuizPage(
      previewQuestions: previewQuestions,
      onCompleted: () async => completed++,
    );
    await tester.pumpWidget(MaterialApp(theme: muondiaTheme, home: quiz()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('1/10'), findsOneWidget);
    expect(completed, 0);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        theme: muondiaTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => quiz())),
              child: const Text('Abrir test'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir test'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Abrir test'), findsOneWidget);
    expect(find.byType(OnboardingQuizPage), findsNothing);
    expect(completed, 0);
  });

  testWidgets(
    'Temáticas largas y desconocidas caben en una pantalla estrecha',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final pivot in [
        'Entretenimiento y cultura popular',
        'Tema desconocido',
      ]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            theme: muondiaTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: OnboardingQuizPage(
              previewQuestions: [
                for (final question in previewQuestions)
                  (
                    pivot: pivot,
                    question: question.question,
                    options: question.options,
                    correct: question.correct,
                  ),
              ],
              onCompleted: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(pivot), findsOneWidget);
        expect(find.text('1/10'), findsOneWidget);
        expect(
          find.byType(Image),
          findsNothing,
          reason: 'No se inventa una imagen para temáticas sin PNG',
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
