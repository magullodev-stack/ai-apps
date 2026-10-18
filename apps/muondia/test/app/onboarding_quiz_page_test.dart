import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muondia/app/app_theme.dart';
import 'package:muondia/app/onboarding/interaction/onboarding_quiz_page.dart';
import 'package:muondia/app/onboarding/interaction/onboarding_quiz_header.dart';
import 'package:muondia/app/onboarding/interaction/onboarding_quiz_hint.dart';
import 'package:muondia/app/onboarding/production/onboarding_quiz_pipeline.dart';

List<OnboardingQuizFinalQuestion> get questions => [
  for (var i = 0; i < 10; i++)
    (
      pivot: 'Física',
      question: 'Pregunta ' + (i + 1).toString(),
      correct: 'Opción A',
      options: <String>['Opción A', 'Opción B', 'Opción C', 'Opción D'],
    ),
];

Future<void> openQuiz(WidgetTester tester, {
  bool countdownEnabled = false,
  Future<String> Function(OnboardingQuizFinalQuestion)? loadHint,
  List<OnboardingQuizFinalQuestion>? data,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: muondiaTheme,
    home: OnboardingQuizPage(
      previewQuestions: data ?? questions,
      countdownEnabled: countdownEnabled,
      loadHint: loadHint,
      onCompleted: () async {},
    ),
  ));
  await tester.pump();
}

Finder answer(int index) => find.byKey(Key('muondia-answer-$index'));
Future<void> choose(WidgetTester tester, int index) async {
  await tester.ensureVisible(answer(index));
  await tester.tap(answer(index));
  await tester.pump();
}
Future<void> advance(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}
InkWell aid(WidgetTester tester, String kind) =>
    tester.widget<InkWell>(find.descendant(
      of: find.byKey(Key('muondia-aid-$kind')),
      matching: find.byType(InkWell),
    ));
Color orbColor(WidgetTester tester, int index) {
  final orb = tester.widget<DecoratedBox>(
      find.byKey(Key('muondia-progress-orb-$index')));
  return ((orb.decoration as BoxDecoration).gradient as RadialGradient)
      .colors[1];
}

void main() {
  test('Anillo: verde 60–21, amarillo 20–6 y rojo 5–0', () {
    for (final seconds in [60, 34, 21]) {
      expect(quizTimerColor(seconds), const Color(0xFF00E8A1));
    }
    for (final seconds in [20, 12, 6]) {
      expect(quizTimerColor(seconds), const Color(0xFFFFD439));
    }
    for (final seconds in [5, 1, 0]) {
      expect(quizTimerColor(seconds), const Color(0xFFFF355C));
    }
  });

  testWidgets('Cabecera de referencia y tres comodines con PNG originales',
      (tester) async {
    await openQuiz(tester);
    expect(find.byKey(const Key('muondia-timer-ring')), findsOneWidget);
    expect(find.text('60s'), findsOneWidget);
    expect(find.byKey(const Key('muondia-hearts-count')), findsOneWidget);
    expect(find.byKey(const Key('muondia-progress-orbs')), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      expect(orbColor(tester, i), const Color(0xAA340E93));
    }
    for (var i = 0; i < 4; i++) {
      expect(answer(i), findsOneWidget);
    }
    for (final entry in <String, String>{
      'fifty': '50%.png',
      'hint': 'Pista.png',
      'pause': 'Pausa.png',
    }.entries) {
      final image = tester.widget<Image>(
          find.byKey(Key('muondia-${entry.key}-image')));
      expect((image.image as AssetImage).assetName,
          'assets/onboarding/test/' + entry.value);
      expect(find.byKey(Key('muondia-${entry.key}-count')), findsOneWidget);
    }
    expect(find.byKey(const Key('muondia-hearts')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('50/50 oculta dos incorrectas y nunca la correcta',
      (tester) async {
    await openQuiz(tester);
    await tester.tap(find.byKey(const Key('muondia-aid-fifty')));
    await tester.pump();
    expect(aid(tester, 'fifty').onTap, isNull);
    expect(tester.widget<InkWell>(answer(0)).onTap, isNotNull);
    expect([1, 2, 3].where((i) =>
      tester.widget<InkWell>(answer(i)).onTap == null).length, 2);
    await choose(tester, 0);
    await advance(tester);
    expect(find.text('Pregunta 2'), findsOneWidget);
    expect(aid(tester, 'fifty').onTap, isNull);
  });

  testWidgets('Corazones: dos reintentos, opciones fallidas desactivadas',
      (tester) async {
    await openQuiz(tester);
    await choose(tester, 1);
    await advance(tester);
    expect(find.text('Pregunta 1'), findsOneWidget);
    expect(tester.widget<InkWell>(answer(1)).onTap, isNull);
    expect(orbColor(tester, 0), const Color(0xAA340E93));
    await choose(tester, 2);
    await advance(tester);
    expect(find.text('Pregunta 1'), findsOneWidget);
    expect(tester.widget<InkWell>(answer(2)).onTap, isNull);
    expect(find.descendant(
      of: find.byKey(const Key('muondia-hearts-count')),
      matching: find.text('0'),
    ), findsOneWidget);
    await choose(tester, 3);
    await advance(tester);
    expect(find.text('Pregunta 2'), findsOneWidget);
    expect(orbColor(tester, 0), const Color(0xFFFF476C));
  });

  testWidgets('Acertar en reintento conserva vida gastada y esfera verde',
      (tester) async {
    await openQuiz(tester);
    await choose(tester, 1);
    await advance(tester);
    await choose(tester, 0);
    await advance(tester);
    expect(find.text('Pregunta 2'), findsOneWidget);
    expect(orbColor(tester, 0), const Color(0xFF2AFF97));
    expect(find.descendant(
      of: find.byKey(const Key('muondia-hearts-count')),
      matching: find.text('1'),
    ), findsOneWidget);
  });

  testWidgets('Pausa dura 10 segundos y permite responder sin detener UI',
      (tester) async {
    await openQuiz(tester, countdownEnabled: true);
    await tester.tap(find.byKey(const Key('muondia-aid-pause')));
    await tester.pump();
    expect(aid(tester, 'pause').onTap, isNull);
    await choose(tester, 0);
    await advance(tester);
    expect(find.text('Pregunta 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    expect(find.text('60s'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(
        find.byKey(const Key('muondia-pause-opacity'))).opacity, 0.42);
  });

  testWidgets('50/50, pista y pausa combinables en la misma pregunta',
      (tester) async {
    await openQuiz(tester, loadHint: (_) async =>
        'Considera el concepto que pide el enunciado.');
    await tester.tap(find.byKey(const Key('muondia-aid-fifty')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('muondia-aid-pause')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('muondia-aid-hint')));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Considera el concepto'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    for (final key in ['fifty', 'hint', 'pause']) {
      expect(aid(tester, key).onTap, isNull);
    }
    expect(tester.widget<InkWell>(answer(0)).onTap, isNotNull);
  });

  test('La pista no puede revelar una respuesta literal', () {
    expect(() => validateOnboardingQuizHint(
        '{"pista":"Opción A"}', questions.first), throwsFormatException);
  });

  testWidgets('Diez preguntas: final cuenta aciertos y fallos definitivos',
      (tester) async {
    await openQuiz(tester);
    for (final index in [1, 2, 3]) {
      await choose(tester, index);
      await advance(tester);
    }
    for (var i = 1; i < 10; i++) {
      await choose(tester, 0);
      await advance(tester);
    }
    expect(find.text('Aciertos: 9'), findsOneWidget);
    expect(find.text('Fallos definitivos: 1'), findsOneWidget);
    expect(find.text('Sin responder: 0'), findsOneWidget);
    expect(find.text('Resultado: 9 / 10'), findsOneWidget);
  });

  testWidgets('Pregunta breve: D visible sin desplazar el panel',
      (tester) async {
    final data = [
      for (var i = 0; i < 10; i++)
        (
          pivot: 'Astronomía',
          question: 'Pregunta de prueba 1: ¿qué opción quieres seleccionar?',
          correct: 'Opción A',
          options: <String>['Opción A', 'Opción B', 'Opción C', 'Opción D'],
        ),
    ];
    await openQuiz(tester, data: data, size: const Size(390, 700));
    final panel = tester.getRect(
      find.byKey(const Key('muondia-question-card')));
    final optionD = tester.getRect(answer(3));
    expect(optionD.bottom, lessThanOrEqualTo(panel.bottom - 6),
        reason: 'La respuesta D debe verse completa en un quiz corto');
    expect(optionD.top, greaterThanOrEqualTo(panel.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Progreso sin contorno blanco y anillo compacto',
      (tester) async {
    await openQuiz(tester);
    final orb = tester.widget<DecoratedBox>(
        find.byKey(const Key('muondia-progress-orb-0')));
    final border = (orb.decoration as BoxDecoration).border! as Border;
    expect(border.top.width, lessThan(1.1));
    expect(border.top.color, isNot(const Color(0xFFA5FFF5)));
    expect(tester.getSize(
        find.byKey(const Key('muondia-timer-ring'))).width, 58);
    for (final kind in ['fifty', 'hint', 'pause']) {
      final target = find.byKey(Key('muondia-aid-$kind'));
      expect(tester.getSize(target).height, greaterThan(60));
      expect(tester.getSize(target).height, lessThan(80));
    }
  });

  testWidgets('Pantalla estrecha: scroll solo dentro de tarjeta',
      (tester) async {
    final data = [
      for (var i = 0; i < 10; i++)
        (
          pivot: 'Entretenimiento y cultura popular',
          question: '¿Qué descripción amplia representa el fenómeno en esta pregunta de prueba?',
          correct: 'Describe los procesos físicos implicados durante el movimiento en cada caso',
          options: <String>[
            'Describe los procesos físicos implicados durante el movimiento en cada caso',
            'Representa otro proceso que no encaja exactamente con el fenómeno propuesto',
            'Es una alternativa extensa pero incorrecta que exige leer varias líneas',
            'Menciona un comportamiento diferente al que se pregunta en el enunciado',
          ],
        ),
    ];
    await openQuiz(tester, data: data, size: const Size(320, 640));
    final card = find.byKey(const Key('muondia-question-card'));
    final before = tester.getRect(card);
    final aids = tester.getRect(
        find.byKey(const Key('muondia-lifelines-row')));
    await tester.ensureVisible(answer(3));
    await tester.pump();
    expect(tester.getRect(card), before);
    expect(tester.getRect(
        find.byKey(const Key('muondia-lifelines-row'))), aids);
    expect(answer(3).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
