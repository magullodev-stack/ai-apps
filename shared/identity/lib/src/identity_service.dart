import 'identity_user.dart';

abstract interface class IdentityService {
  Future<void> initialize();

  bool get isInitialized;

  IdentityUser? get currentUser;

  Stream<IdentityUser?> authStateChanges();

  Future<IdentityUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<IdentityUser> registerWithEmail({
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset({
    required String email,
  });

  Future<IdentityUser> signInWithGoogle();

  Future<IdentityUser> signInWithApple();

  Future<void> signOut();
}
