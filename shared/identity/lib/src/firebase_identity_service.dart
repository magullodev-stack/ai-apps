import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'identity_failure.dart';
import 'identity_service.dart';
import 'identity_user.dart';

final class FirebaseIdentityService implements IdentityService {
  FirebaseAuth? _auth;
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  IdentityUser? get currentUser {
    final user = _auth?.currentUser;
    return user == null ? null : _mapUser(user);
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _auth = FirebaseAuth.instance;
      _initialized = true;
    } on FirebaseException catch (error) {
      throw IdentityFailure(
        IdentityFailureCode.notConfigured,
        cause: error,
      );
    } catch (error) {
      throw IdentityFailure(
        IdentityFailureCode.notConfigured,
        cause: error,
      );
    }
  }

  @override
  Stream<IdentityUser?> authStateChanges() {
    return _requireAuth.authStateChanges().map(
      (user) => user == null ? null : _mapUser(user),
    );
  }

  @override
  Future<IdentityUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _requireAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _mapCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw _mapAuthFailure(error);
    }
  }

  @override
  Future<IdentityUser> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _requireAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _mapCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw _mapAuthFailure(error);
    }
  }

  @override
  Future<void> sendPasswordReset({
    required String email,
  }) async {
    try {
      await _requireAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw _mapAuthFailure(error);
    }
  }

  @override
  Future<IdentityUser> signInWithGoogle() {
    throw const IdentityFailure.providerNotReady(IdentityProvider.google);
  }

  @override
  Future<IdentityUser> signInWithApple() {
    throw const IdentityFailure.providerNotReady(IdentityProvider.apple);
  }

  @override
  Future<void> signOut() => _requireAuth.signOut();

  FirebaseAuth get _requireAuth {
    final auth = _auth;
    if (!_initialized || auth == null) {
      throw const IdentityFailure(IdentityFailureCode.notConfigured);
    }
    return auth;
  }

  IdentityUser _mapCredential(UserCredential credential) {
    final user = credential.user;
    if (user == null) {
      throw const IdentityFailure(IdentityFailureCode.unknown);
    }
    return _mapUser(user);
  }

  IdentityUser _mapUser(User user) => IdentityUser(
    id: user.uid,
    email: user.email,
    emailVerified: user.emailVerified,
    displayName: user.displayName,
  );

  IdentityFailure _mapAuthFailure(FirebaseAuthException error) {
    final code = switch (error.code) {
      'invalid-email' => IdentityFailureCode.invalidEmail,
      'weak-password' => IdentityFailureCode.weakPassword,
      'email-already-in-use' => IdentityFailureCode.emailAlreadyInUse,
      'user-disabled' => IdentityFailureCode.userDisabled,
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => IdentityFailureCode.wrongCredentials,
      'network-request-failed' => IdentityFailureCode.network,
      'too-many-requests' => IdentityFailureCode.tooManyRequests,
      _ => IdentityFailureCode.unknown,
    };
    return IdentityFailure(code, cause: error);
  }
}
