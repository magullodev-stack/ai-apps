import 'package:ai_apps_identity/ai_apps_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muondia/app/app.dart';

void main() {
  testWidgets('los botones llaman al proveedor correspondiente', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final identity = _ProviderFakeIdentityService();
    await tester.pumpWidget(MuondiaApp(identityService: identity));
    await tester.pump();

    await tester.tap(find.byKey(const Key('muondia-auth-button-google')));
    await tester.pump();
    expect(identity.googleAttempts, 1);
    expect(identity.appleAttempts, 0);

    await tester.tap(find.byKey(const Key('muondia-auth-button-apple')));
    await tester.pump();
    expect(identity.googleAttempts, 1);
    expect(identity.appleAttempts, 1);
    expect(tester.takeException(), isNull);
  });
}

class _ProviderFakeIdentityService implements IdentityService {
  int googleAttempts = 0;
  int appleAttempts = 0;

  @override
  bool get isInitialized => true;
  @override
  IdentityUser? get currentUser => null;
  @override
  Future<void> initialize() async {}
  @override
  Stream<IdentityUser?> authStateChanges() => const Stream.empty();
  @override
  Future<IdentityUser> signInWithGoogle() async {
    googleAttempts++;
    throw const IdentityFailure.providerNotReady(IdentityProvider.google);
  }
  @override
  Future<IdentityUser> signInWithApple() async {
    appleAttempts++;
    throw const IdentityFailure.providerNotReady(IdentityProvider.apple);
  }
  @override
  Future<IdentityUser> signInWithEmail({
    required String email,
    required String password,
  }) async => throw UnimplementedError();
  @override
  Future<IdentityUser> registerWithEmail({
    required String email,
    required String password,
  }) async => throw UnimplementedError();
  @override
  Future<void> sendPasswordReset({required String email}) async =>
      throw UnimplementedError();
  @override
  Future<void> signOut() async {}
}
