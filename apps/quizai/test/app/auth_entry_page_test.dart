import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/app/app.dart';
import 'package:quizai/app/app_shell.dart';
import 'package:quizai/app/auth/auth_entry_page.dart';

void main() {
  testWidgets('QuizAI abre en la pantalla de autenticación', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const QuizAIApp());
    await tester.pumpAndSettle();

    expect(find.byType(AuthEntryPage), findsOneWidget);
    expect(find.byKey(const Key('quizai-auth-entry')), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((image) => image.assetName)
        .toSet();

    expect(
      assets,
      containsAll(<String>[
        'assets/auth/QuizAI_Auth_background_1080x1920.png',
        'assets/auth/QuizAI_Auth_LOGO_1080x1920.png',
        'assets/auth/QuizAI_Auth_AI-APPS_1080x1920.png',
        'assets/auth/QuizAI_Auth_Lema_1080x1920.png',
      ]),
    );

    final google = find.byKey(const Key('quizai-auth-button-google'));
    final apple = find.byKey(const Key('quizai-auth-button-apple'));
    final email = find.byKey(const Key('quizai-auth-button-email'));
    expect(google, findsOneWidget);
    expect(apple, findsOneWidget);
    expect(email, findsOneWidget);

    final googleSize = tester.getSize(google);
    final appleSize = tester.getSize(apple);
    final emailSize = tester.getSize(email);
    expect(appleSize, googleSize);
    expect(emailSize, googleSize);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con Apple'), findsOneWidget);
    expect(find.text('Continuar con email'), findsOneWidget);
    final googleIcon = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .where(
          (image) =>
              image.assetName ==
              'assets/auth/QuizAI_Auth_Google_ICON.png',
        );
    expect(googleIcon, hasLength(1));

    final legal = tester.widget<Text>(
      find.byKey(const Key('quizai-auth-legal')),
    );
    expect(
      legal.textSpan?.toPlainText(),
      'Al continuar, aceptas los Términos de uso\ny la Política de privacidad.',
    );

    final children = (legal.textSpan as TextSpan).children!.cast<TextSpan>();
    expect(
      children
          .where((span) => span.text == 'Términos de uso')
          .single
          .recognizer,
      isA<TapGestureRecognizer>(),
    );
    expect(
      children
          .where((span) => span.text == 'Política de privacidad')
          .single
          .recognizer,
      isA<TapGestureRecognizer>(),
    );
    expect(tester.takeException(), isNull);
  });
}
