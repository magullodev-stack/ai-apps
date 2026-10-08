import 'package:ai_apps_identity/ai_apps_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizai/app/app_theme.dart';
import 'package:quizai/app/auth/email_auth_page.dart';

void main() {
  testWidgets('email permite iniciar sesión y crear una cuenta', (tester) async {
    final identity = _RecordingIdentityService();

    await tester.pumpWidget(
      MaterialApp(
        theme: quizAITheme,
        home: EmailAuthPage(identity: identity),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('quizai-email-auth-email')),
      'persona@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('quizai-email-auth-password')),
      'secreto123',
    );
    await tester.tap(find.byKey(const Key('quizai-email-auth-submit')));
    await tester.pumpAndSettle();

    expect(identity.lastSignInEmail, 'persona@example.com');
    expect(identity.lastSignInPassword, 'secreto123');

    await tester.pumpWidget(
      MaterialApp(
        theme: quizAITheme,
        home: EmailAuthPage(identity: identity),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('quizai-email-auth-email')),
      'nueva@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('quizai-email-auth-password')),
      'secreto456',
    );
    await tester.enterText(
      find.byKey(const Key('quizai-email-auth-confirm')),
      'secreto456',
    );
    await tester.tap(find.byKey(const Key('quizai-email-auth-submit')));
    await tester.pumpAndSettle();

    expect(identity.lastRegisterEmail, 'nueva@example.com');
    expect(identity.lastRegisterPassword, 'secreto456');
    expect(tester.takeException(), isNull);
  });
}

class _RecordingIdentityService implements IdentityService {
  String? lastSignInEmail;
  String? lastSignInPassword;
  String? lastRegisterEmail;
  String? lastRegisterPassword;

  @override
  bool get isInitialized => true;

  @override
  IdentityUser? get currentUser => null;

  @override
  Future<void> initialize() async {}

  @override
  Stream<IdentityUser?> authStateChanges() => const Stream.empty();

  @override
  Future<IdentityUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    lastSignInEmail = email;
    lastSignInPassword = password;
    return const IdentityUser(
      id: 'signed-in',
      email: 'persona@example.com',
      emailVerified: false,
    );
  }

  @override
  Future<IdentityUser> registerWithEmail({
    required String email,
    required String password,
  }) async {
    lastRegisterEmail = email;
    lastRegisterPassword = password;
    return const IdentityUser(
      id: 'registered',
      email: 'nueva@example.com',
      emailVerified: false,
    );
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {}

  @override
  Future<IdentityUser> signInWithGoogle() {
    throw const IdentityFailure.providerNotReady(IdentityProvider.google);
  }

  @override
  Future<IdentityUser> signInWithApple() {
    throw const IdentityFailure.providerNotReady(IdentityProvider.apple);
  }

  @override
  Future<void> signOut() async {}
}
