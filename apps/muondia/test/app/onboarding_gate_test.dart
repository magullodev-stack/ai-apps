import 'package:ai_apps_identity/ai_apps_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muondia/app/app.dart';
import 'package:muondia/app/app_shell.dart';
import 'package:muondia/app/onboarding/completion_store.dart';
import 'package:muondia/app/onboarding/interaction/onboarding_quiz_page.dart';

void main() {
  testWidgets('Un usuario que ya terminó entra directamente a Home',
      (tester) async {
    final store = _MemoryOnboardingStore()..completed.add('user-1');
    await tester.pumpWidget(
      MuondiaApp(identityService: _SignedInIdentity(), onboardingStore: store),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OnboardingQuizPage), findsNothing);
    expect(store.reads, 1);
  });

  testWidgets('Un usuario nuevo ve el recorrido inicial antes que Home',
      (tester) async {
    final store = _MemoryOnboardingStore();
    await tester.pumpWidget(
      MuondiaApp(identityService: _SignedInIdentity(), onboardingStore: store),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(OnboardingQuizPage), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    expect(store.completed, isEmpty);
  });

  test('La finalización se guarda separadamente por usuario', () async {
    final store = _MemoryOnboardingStore();
    expect(await store.hasCompleted('user-1'), false);
    await store.markCompleted('user-1');
    expect(await store.hasCompleted('user-1'), true);
    expect(await store.hasCompleted('user-2'), false);
  });
}

class _MemoryOnboardingStore implements OnboardingCompletionStore {
  final Set<String> completed = {};
  int reads = 0;

  @override
  Future<bool> hasCompleted(String userId) async {
    reads++;
    return completed.contains(userId);
  }

  @override
  Future<void> markCompleted(String userId) async {
    completed.add(userId);
  }
}

class _SignedInIdentity implements IdentityService {
  static const user = IdentityUser(
    id: 'user-1',
    email: 'user@example.com',
    emailVerified: true,
  );

  @override
  IdentityUser? get currentUser => user;
  @override
  bool get isInitialized => true;
  @override
  Future<void> initialize() async {}
  @override
  Stream<IdentityUser?> authStateChanges() => const Stream.empty();
  @override
  Future<IdentityUser> signInWithEmail({
    required String email,
    required String password,
  }) async => user;
  @override
  Future<IdentityUser> registerWithEmail({
    required String email,
    required String password,
  }) async => user;
  @override
  Future<IdentityUser> signInWithGoogle() async => user;
  @override
  Future<IdentityUser> signInWithApple() async => user;
  @override
  Future<void> sendPasswordReset({required String email}) async {}
  @override
  Future<void> signOut() async {}
}
