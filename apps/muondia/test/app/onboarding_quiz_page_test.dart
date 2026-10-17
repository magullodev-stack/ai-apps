import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muondia/app/app_theme.dart';
import 'package:muondia/app/development/experience_preview.dart';
import 'package:muondia/app/onboarding/interaction/onboarding_quiz_page.dart';
import 'package:muondia/app/onboarding/pivot_images.dart';

void main() {
  testWidgets(
    'Composición continua: tarjeta, cuatro respuestas A–D y fondo oscuro',
    (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: muondiaTheme,
          home: OnboardingQuizPage(
            previewQuestions: [
              for (var i = 0; i < 10; i++)
                (
                  pivot: 'Física',
                  question: '¿Cuál es el valor aproximado de la aceleración de la gravedad cerca de la superficie terrestre?',
                  correct: '9,8 m/s²',
                  options: ['9,8 m/s²', '6,7 m/s²', '15,4 m/s²', '3,2 m/s²'],
                ),
            ],
            onCompleted: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final stage = tester.widget<DecoratedBox>(
        find.byKey(const Key('muondia-quiz-stage')),
      );
      expect((stage.decoration as BoxDecoration).gradient, isNotNull);
      final card = tester.getRect(
        find.byKey(const Key('muondia-question-card')),
      );
      expect(card.height, greaterThan(500));
      for (var i = 0; i < 4; i++) {
        expect(find.text(String.fromCharCode(65 + i)), findsOneWidget);
        final answer = find.byKey(Key('muondia-answer-$i'));
        expect(answer.hitTestable(), findsOneWidget);
        expect(card.contains(tester.getTopLeft(answer)), isTrue);
        expect(card.contains(tester.getBottomRight(answer)), isTrue);
      }
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.textContaining('Aciertos:'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Texto largo a 200 %: respuestas accesibles y nueva pregunta arriba',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final questions = [
        for (final q in previewQuestions)
          (
            pivot: q.pivot,
            question: '${q.question} ${q.question}',
            correct: 'Guardar temporalmente los datos y programas que se están utilizando',
            options: [
              'Guardar temporalmente los datos y programas que se están utilizando',
              'Conservar archivos incluso cuando el equipo está apagado',
              'Controlar la conexión del equipo con dispositivos externos',
              'Traducir nombres de dominio a direcciones de red',
            ],
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: muondiaTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: OnboardingQuizPage(
            previewQuestions: questions,
            onCompleted: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final last = find.byKey(const Key('muondia-answer-3'));
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      expect(last.hitTestable(), findsOneWidget);
      await tester.tap(last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('2/10').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
      expect(find.text('Siguiente'), findsNothing);

      await tester.ensureVisible(find.text('Opción A'));
      await tester.tap(find.text('Opción A'));
      await tester.pump();
      expect(find.text('Siguiente'), findsNothing);
      expect(find.text('Ver resultado'), findsNothing);
      expect(
        tester.widget<InkWell>(find.byKey(const Key('muondia-answer-0'))).onTap,
        isNull,
        reason: 'Una sola pulsación: las demás opciones se bloquean',
      );
      final selectedDecoration =
          tester
                  .widget<AnimatedContainer>(
                    find.byKey(const Key('muondia-answer-feedback-0')),
                  )
                  .decoration
              as BoxDecoration;
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
    await tester.pumpWidget(
      MaterialApp(
        theme: muondiaTheme,
        home: OnboardingQuizPage(
          previewQuestions: previewQuestions,
          onCompleted: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Opción B'));
    await tester.pump();
    final wrong =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const Key('muondia-answer-feedback-1')),
                )
                .decoration
            as BoxDecoration;
    final correct =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const Key('muondia-answer-feedback-0')),
                )
                .decoration
            as BoxDecoration;
    expect(wrong.color, MuondiaPalette.error.withAlpha(48));
    expect(correct.color, MuondiaPalette.success.withAlpha(48));
    expect(find.text('Siguiente'), findsNothing);

    // Los siguientes toques durante el velo no pueden contar otra respuesta.
    expect(
      tester.widget<InkWell>(find.byKey(const Key('muondia-answer-3'))).onTap,
      isNull,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('2/10'), findsOneWidget);
    final cleared =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const Key('muondia-answer-feedback-0')),
                )
                .decoration
            as BoxDecoration;
    expect(cleared.color, Colors.transparent);
    for (var i = 1; i < 10; i++) {
      await tester.ensureVisible(find.text('Opción A'));
      await tester.tap(find.text('Opción A'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }
    expect(find.text('Resultado: 9 / 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Salir de la página cancela el avance automático pendiente', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: muondiaTheme,
        home: OnboardingQuizPage(
          previewQuestions: previewQuestions,
          onCompleted: () async {},
        ),
      ),
    );
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
