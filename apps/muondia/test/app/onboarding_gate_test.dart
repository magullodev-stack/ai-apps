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

  testWidgets('F7 abre Auth desde el onboarding sin cerrar sesión ni borrar progreso',
      (tester) async {
    final identity = _SignedInIdentity();
    final store = _MemoryOnboardingStore();
    await tester.pumpWidget(
      MuondiaApp(identityService: identity, onboardingStore: store),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(OnboardingQuizPage), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.f7);
    await tester.pump();
    expect(find.byType(AuthEntryPage), findsOneWidget);
    expect(find.byType(OnboardingQuizPage), findsNothing);
    expect(identity.signOutCalls, 0);
    expect(identity.googleSignInCalls, 0);
    expect(identity.currentUser, isNotNull);
    expect(store.completed, isEmpty);

    await tester.tap(find.byKey(const Key('muondia-auth-button-google')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MuondiaStage), findsOneWidget);
    expect(find.byType(OnboardingQuizPage), findsNothing);
    expect(identity.googleSignInCalls, 0);
    expect(store.completed, isEmpty);
  });

  testWidgets('El comando Android abre Auth sin depender del foco del teclado',
      (tester) async {
    final identity = _SignedInIdentity();
    final store = _MemoryOnboardingStore();
    await tester.pumpWidget(
      MuondiaApp(identityService: identity, onboardingStore: store),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(OnboardingQuizPage), findsOneWidget);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    await messenger.handlePlatformMessage(
      'muondia/development',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('showAuth'),
      ),
      (_) {},
    );
    await tester.pump();

    expect(find.byType(AuthEntryPage), findsOneWidget);
    expect(identity.signOutCalls, 0);
    expect(store.completed, isEmpty);
  });

  testWidgets('F7 muestra Auth desde Home sin perder el progreso completado',
      (tester) async {
    final identity = _SignedInIdentity();
    final store = _MemoryOnboardingStore()..completed.add('user-1');
    await tester.pumpWidget(
      MuondiaApp(identityService: identity, onboardingStore: store),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(AppShell), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.f7);
    await tester.pump();
    expect(find.byType(AuthEntryPage), findsOneWidget);
    expect(identity.signOutCalls, 0);
    expect(store.completed, contains('user-1'));

    await tester.tap(find.byKey(const Key('muondia-auth-button-google')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MuondiaStage), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    expect(store.completed, contains('user-1'));
  });

  testWidgets(
    'El explorador alterna entre vista previa y recorrido real sin perder sesión',
    (tester) async {
      final identity = _SignedInIdentity();
      final store = _MemoryOnboardingStore()..completed.add('user-1');
      final deviceLocations = <String>[];
      final locationChannel = const MethodChannel('muondia/development_location');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(locationChannel, (call) async {
        if (call.method == 'setActiveLocation') {
          final args = Map<String, Object?>.from(call.arguments as Map);
          deviceLocations.add(
            '${args['mode']}:${args['experience']}:${args['state']}',
          );
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(locationChannel, null));
      await tester.pumpWidget(MuondiaApp(
        identityService: identity,
        onboardingStore: store,
        developmentPreviewOnStartup: true,
      ));
      await tester.pump();
      expect(find.byType(AuthEntryPage), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);

      expect(deviceLocations, contains('preview:auth:inicio'),
        reason: 'El estado inicial debe ser visible tras recargar VS Code');
      Future<void> send(String method, [Object? args]) async {
        await messenger.handlePlatformMessage(
          'muondia/development',
          const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
          (_) {},
        );
        await tester.pump();
        await tester.pump();
      }

      await send('openRealFlow');
      expect(deviceLocations, contains('real::'));
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(AuthEntryPage), findsNothing);
      expect(identity.signOutCalls, 0);
      expect(store.completed, contains('user-1'));

      // Un Hot Reload no debe sacar al desarrollador del modo real.
      await tester.binding.reassembleApplication();
      await tester.pump();
      await tester.pump();
      expect(find.byType(AppShell), findsOneWidget);

      await send('openExperience', {'experience': 'auth', 'state': 'inicio'});
      expect(deviceLocations.last, 'preview:auth:inicio',
        reason: 'Volver desde el modo real actualiza la ubicación efectiva');
      expect(find.byType(AuthEntryPage), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);

      await send('openRealFlow');
      expect(find.byType(AppShell), findsOneWidget);
      expect(identity.signOutCalls, 0);
      expect(store.completed, contains('user-1'));
    },
  );

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
  int signOutCalls = 0;
  int googleSignInCalls = 0;
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
  Future<IdentityUser> signInWithGoogle() async {
    googleSignInCalls++;
    return user;
  }
  @override
  Future<IdentityUser> signInWithApple() async => user;
  @override
  Future<void> sendPasswordReset({required String email}) async {}
  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}
