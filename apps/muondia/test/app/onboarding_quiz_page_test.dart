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
      await tester.pumpAndSettle();
      expect(find.text('Aciertos: ${i + 1}'), findsOneWidget);
      // La selección sigue bloqueada hasta pasar a la siguiente pregunta.
      expect(
        tester
            .widget<OutlinedButton>(find.byType(OutlinedButton).first)
            .onPressed,
        isNull,
      );
      final next = find.text(i == 9 ? 'Ver resultado' : 'Siguiente');
      await tester.ensureVisible(next);
      await tester.tap(next);
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
