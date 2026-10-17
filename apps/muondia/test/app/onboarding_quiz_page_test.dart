import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muondia/app/app_theme.dart';
import 'package:muondia/app/development/experience_preview.dart';
import 'package:muondia/app/onboarding/interaction/onboarding_quiz_page.dart';
import 'package:muondia/app/onboarding/interaction/onboarding_quiz_backdrop.dart';
import 'package:muondia/app/onboarding/interaction/onboarding_quiz_hint.dart';
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
      final stageDecoration = stage.decoration as BoxDecoration;
      expect(stageDecoration.gradient, isNotNull);
      expect(stageDecoration.borderRadius, isNull,
          reason: 'El fondo del test no es una tarjeta redondeada');
      expect(stageDecoration.border, isNull);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is OnboardingQuizBackdrop,
        ),
        findsOneWidget,
      );
      for (final name in ['muondia-fifty-count', 'muondia-hint-count']) {
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byKey(Key(name)),
            matching: find.text('1'),
          ),
        );
        expect(text.style?.color, const Color(0xFF201047),
            reason: 'Los contadores amarillos necesitan cifras oscuras');
      }

      final card = tester.getRect(
        find.byKey(const Key('muondia-question-card')),
      );
      expect(card.height, greaterThan(500));
      for (var i = 0; i < 4; i++) {
        expect(find.text(String.fromCharCode(65 + i)), findsOneWidget);
        final answer = find.byKey(Key('muondia-answer-$i'));
        final letterBadge = tester.widget<Container>(
          find.byKey(Key('muondia-answer-letter-$i')),
        );
        final letterDecoration = letterBadge.decoration as BoxDecoration;
        expect(letterDecoration.gradient, isNotNull);
        expect(letterDecoration.shape, BoxShape.rectangle);
        expect(letterDecoration.borderRadius, isNotNull);
        expect(find.byKey(Key('muondia-answer-divider-$i')), findsOneWidget);
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


  testWidgets('Explorador: 60 segundos congelados incluso al navegar y usar ayudas', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: muondiaTheme,
      home: OnboardingQuizPage(
        previewQuestions: previewQuestions,
        countdownEnabled: false,
        onCompleted: () async {},
      ),
    ));
    await tester.pump();

    expect(find.text('60s'), findsOneWidget);
    final initialProgress = tester.getSemantics(
      find.bySemanticsLabel('Tiempo restante del test'),
    );
    expect(initialProgress.value, '60 segundos');

    // Una previsualización abierta durante minutos no debe agotarse.
    await tester.pump(const Duration(minutes: 3));
    await tester.pump();
    expect(find.text('60s'), findsOneWidget);
    expect(find.text('1/10'), findsOneWidget);
    expect(find.text('Tiempo agotado'), findsNothing);

    await tester.tap(find.byKey(const Key('muondia-aid-fifty')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('60s'), findsOneWidget);
    await tester.tap(find.text('Opción A'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('2/10'), findsOneWidget);
    expect(find.text('60s'), findsOneWidget);

    await tester.tap(find.byKey(const Key('muondia-aid-hint')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pista de demostración'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 2));
    expect(find.text('2/10'), findsOneWidget);
    expect(find.text('60s'), findsOneWidget);
    expect(find.text('Tiempo agotado'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sesenta segundos compartidos y fin automático', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: muondiaTheme,
      home: OnboardingQuizPage(
        previewQuestions: previewQuestions,
        onCompleted: () async {},
      ),
    ));
    await tester.pump();
    expect(find.text('60s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    final before = int.parse(tester.widget<Text>(
      find.byKey(const Key('muondia-test-seconds')),
    ).data!.replaceAll('s', ''));
    expect(before, lessThan(60));
    await tester.tap(find.text('Opción A'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('2/10'), findsOneWidget);
    final after = int.parse(tester.widget<Text>(
      find.byKey(const Key('muondia-test-seconds')),
    ).data!.replaceAll('s', ''));
    expect(after, lessThanOrEqualTo(before));
    await tester.pump(const Duration(seconds: 61));
    await tester.pump();
    expect(find.text('Tiempo agotado'), findsOneWidget);
    expect(find.text('Resultado: 1 / 10'), findsOneWidget);
  });

  testWidgets('50 % atenúa dos errores, bloquea sus toques y mantiene el layout', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: muondiaTheme,
      home: OnboardingQuizPage(
        previewQuestions: previewQuestions,
        onCompleted: () async {},
      ),
    ));
    await tester.pump();
    final cardBefore = tester.getRect(
      find.byKey(const Key('muondia-question-card')),
    );
    final answerRects = [
      for (var i = 0; i < 4; i++)
        tester.getRect(find.byKey(Key('muondia-answer-$i'))),
    ];
    await tester.tap(find.byKey(const Key('muondia-aid-fifty')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Opción A'), findsOneWidget);
    expect(find.text('Opción B'), findsOneWidget);
    expect(find.text('Opción C'), findsOneWidget);
    expect(find.text('Opción D'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('muondia-question-card'))),
      cardBefore,
    );
    for (var i = 0; i < 4; i++) {
      expect(tester.getRect(find.byKey(Key('muondia-answer-$i'))), answerRects[i],
          reason: 'Ninguna fila debe desplazarse al activar el 50 %');
    }
    final discarded = <int>[];
    for (var i = 0; i < 4; i++) {
      final faded = tester.widget<AnimatedOpacity>(
        find.byKey(Key('muondia-answer-opacity-$i')),
      );
      final onTap = tester.widget<InkWell>(
        find.byKey(Key('muondia-answer-$i')),
      ).onTap;
      if (faded.opacity < 1) {
        discarded.add(i);
        expect(onTap, isNull,
            reason: 'La alternativa descartada nunca admite pulsaciones');
      } else {
        expect(onTap, isNotNull);
      }
    }
    expect(discarded, hasLength(2));
    expect(discarded, isNot(contains(0)),
        reason: 'El 50 % nunca puede desactivar la respuesta correcta');
    expect(
      find.descendant(
        of: find.byKey(const Key('muondia-fifty-count')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Opción A'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('2/10'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(Key('muondia-answer-$i')), findsOneWidget);
      expect(
        tester.widget<AnimatedOpacity>(
          find.byKey(Key('muondia-answer-opacity-$i')),
        ).opacity,
        1.0,
      );
    }
    expect(tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('muondia-aid-fifty')),
        matching: find.byType(InkWell),
      ),
    ).onTap, isNull);
  });

  testWidgets('Pista simulada pausa el reloj y consume un uso', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: muondiaTheme,
      home: OnboardingQuizPage(
        previewQuestions: previewQuestions,
        onCompleted: () async {},
      ),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const Key('muondia-aid-hint')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pista de demostración'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('60s'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('muondia-hint-count')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
  });

  test('La pista rechaza la respuesta literal', () {
    final q = previewQuestions.first;
    expect(
      () => validateOnboardingQuizHint('{"pista":"Opción A"}', q),
      throwsFormatException,
    );
    expect(
      validateOnboardingQuizHint('{"pista":"Identifica primero qué se pregunta."}', q),
      'Identifica primero qué se pregunta.',
    );
  });

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
      expect(find.bySemanticsLabel('Tiempo restante del test'), findsOneWidget);
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
    expect(find.bySemanticsLabel('Tiempo restante del test'), findsNothing);
    expect(completed, 0);
    await tester.tap(find.text('Entrar en Muondia'));
    await tester.pump();
    expect(completed, 1);
    expect(loadCalls, 0, reason: 'La preview no debe generar preguntas');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Respuesta incorrecta: solo rojo, avance sin botón', (
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
    expect(correct.color, Colors.transparent);
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
