import 'package:ai_apps_identity/ai_apps_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muondia/app/app.dart';
import 'package:muondia/app/app_shell.dart';
import 'package:muondia/app/auth/auth_entry_page.dart';
import 'package:muondia/app/interaction/ai_stage.dart';
import 'package:muondia/app/onboarding/completion_store.dart';
import 'package:muondia/app/onboarding/interaction/onboarding_quiz_page.dart';

void main() {
  testWidgets('Debug inicia en Auth seguro sin consultar Firebase ni onboarding',
      (tester) async {
    final identity = _IdentityStub();
    final store = _StoreStub();
    await tester.pumpWidget(MuondiaApp(
      identityService: identity,
      onboardingStore: store,
      developmentPreviewOnStartup: true,
    ));
    await tester.pump();
    expect(find.byType(AuthEntryPage), findsOneWidget);
    expect(find.byType(OnboardingQuizPage), findsNothing);
    expect(identity.googleCalls, 0);
    expect(store.reads, 0);
    expect(store.writes, 0);

    await tester.tap(find.byKey(const Key('muondia-auth-button-google')));
    await tester.pump();
    expect(find.byType(MuondiaStage), findsOneWidget);
    expect(identity.googleCalls, 0);
    expect(store.reads, 0);
  });

  testWidgets('Abre experiencias sin llamar a Google ni generar preguntas',
      (tester) async {
    final identity = _IdentityStub();
    final store = _StoreStub();
    await tester.pumpWidget(MuondiaApp(
      identityService: identity,
      onboardingStore: store,
    ));
    await tester.pump();

    Future<void> open(String experience, String state) async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'muondia/development',
        const StandardMethodCodec().encodeMethodCall(MethodCall(
          'openExperience',
          {'experience': experience, 'state': state},
        )),
        (_) {},
      );
      await tester.pump();
    }

    await open('test', 'inicio');
    expect(find.byType(OnboardingQuizPage), findsOneWidget);
    expect(find.text('1/10'), findsOneWidget);
    await open('loading', 'progreso');
    expect(tester.widget<MuondiaStage>(find.byType(MuondiaStage)).progress, 0.58);
    await open('loading', 'final');
    expect(tester.widget<MuondiaStage>(find.byType(MuondiaStage)).progress, 1.0);
    await open('home', 'inicio');
    expect(find.byType(AppShell), findsOneWidget);
    await open('auth', 'inicio');
    expect(find.byType(AuthEntryPage), findsOneWidget);
    await tester.tap(find.byKey(const Key('muondia-auth-button-google')));
    await tester.pump();
    expect(find.byType(MuondiaStage), findsOneWidget);
    expect(identity.googleCalls, 0);
    expect(identity.logoutCalls, 0);
    expect(store.reads, 0);
    expect(store.writes, 0);
  });
}

class _StoreStub implements OnboardingCompletionStore {
  int reads = 0, writes = 0;
  @override
  Future<bool> hasCompleted(String userId) async { reads++; return true; }
  @override
  Future<void> markCompleted(String userId) async { writes++; }
}
class _IdentityStub implements IdentityService {
  int googleCalls = 0, logoutCalls = 0;
  @override
  IdentityUser? get currentUser => null;
  @override
  bool get isInitialized => true;
  @override
  Future<void> initialize() async {}
  @override
  Stream<IdentityUser?> authStateChanges() => const Stream.empty();
  @override
  Future<IdentityUser> signInWithGoogle() async { googleCalls++; throw UnimplementedError(); }
  @override
  Future<IdentityUser> signInWithApple() async => throw UnimplementedError();
  @override
  Future<IdentityUser> signInWithEmail({required String email, required String password}) async => throw UnimplementedError();
  @override
  Future<IdentityUser> registerWithEmail({required String email, required String password}) async => throw UnimplementedError();
  @override
  Future<void> sendPasswordReset({required String email}) async {}
  @override
  Future<void> signOut() async { logoutCalls++; }
}

