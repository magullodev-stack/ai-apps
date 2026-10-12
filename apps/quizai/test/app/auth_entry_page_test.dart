import 'package:ai_apps_identity/ai_apps_identity.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/app/app.dart';
import 'package:quizai/app/app_shell.dart';
import 'package:quizai/app/auth/auth_entry_page.dart';
import 'package:quizai/app/auth/email_auth_page.dart';

void main() {
  testWidgets('QuizAI abre en la pantalla de autenticación', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final identity = _FakeIdentityService();
    await tester.pumpWidget(QuizAIApp(identityService: identity));
    // El parallax es continuo: no puede utilizarse pumpAndSettle en esta ruta.
    await tester.pump();

    expect(find.byType(AuthEntryPage), findsOneWidget);
    expect(find.byKey(const Key('quizai-auth-entry')), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    for (final asset in [
      'assets/auth/Background.png',
      'assets/auth/Estrellas.png',
      'assets/auth/Esferas.png',
      'assets/auth/Robot.png',
    ]) {
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == asset,
        ),
        findsOneWidget,
      );
    }
    final robot = find.byKey(const Key('quizai-auth-parallax-robot'));
    final start = tester.widget<Transform>(robot).transform.getTranslation();
    await tester.pump(const Duration(seconds: 2));
    final moved = tester.widget<Transform>(robot).transform.getTranslation();
    expect(start.x, 0);
    expect(moved.x, 0);
    expect(moved.y, isNot(closeTo(start.y, 0.01)));

    final background = tester.widget<Transform>(
      find.byKey(const Key('quizai-auth-background-fill')),
    );
    expect(background.transform.getMaxScaleOnAxis(), greaterThan(1.25));

    final google = find.byKey(const Key('quizai-auth-button-google'));
    final apple = find.byKey(const Key('quizai-auth-button-apple'));
    final email = find.byKey(const Key('quizai-auth-button-email'));
    expect(google, findsOneWidget);
    expect(apple, findsOneWidget);
    expect(email, findsOneWidget);

    expect(tester.getSize(apple), tester.getSize(google));
    expect(tester.getSize(email), tester.getSize(google));

    final legal = tester.widget<Text>(
      find.byKey(const Key('quizai-auth-legal')),
    );
    expect(
      legal.textSpan?.toPlainText(),
      'Al continuar, aceptas los Términos de uso\ny la Política de privacidad.',
    );

    final children = (legal.textSpan as TextSpan).children!.cast<TextSpan>();
    expect(
      children.where((span) => span.text == 'Términos de uso').single.recognizer,
      isA<TapGestureRecognizer>(),
    );
    expect(
      children
          .where((span) => span.text == 'Política de privacidad')
          .single
          .recognizer,
      isA<TapGestureRecognizer>(),
    );

    await tester.tap(email);
    await tester.pumpAndSettle();
    expect(find.byType(EmailAuthPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeIdentityService implements IdentityService {
  @override
  bool get isInitialized => true;

  @override
  IdentityUser? get currentUser => null;

  @override
  Future<void> initialize() async {}

  @override
  Stream<IdentityUser?> authStateChanges() => const Stream.empty();

  @override
  Future<IdentityUser> registerWithEmail({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordReset({required String email}) {
    throw UnimplementedError();
  }

  @override
  Future<IdentityUser> signInWithApple() {
    throw const IdentityFailure.providerNotReady(IdentityProvider.apple);
  }

  @override
  Future<IdentityUser> signInWithEmail({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<IdentityUser> signInWithGoogle() {
    throw const IdentityFailure.providerNotReady(IdentityProvider.google);
  }

  @override
  Future<void> signOut() async {}
}
