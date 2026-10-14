import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
        diagnosticCode: 'firebase/${error.code}',
      );
    } on PlatformException catch (error) {
      throw IdentityFailure(
        IdentityFailureCode.notConfigured,
        cause: error,
        diagnosticCode: 'android/${error.code}',
      );
    } catch (error) {
      throw IdentityFailure(
        IdentityFailureCode.notConfigured,
        cause: error,
        diagnosticCode: error.runtimeType.toString(),
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
  Future<IdentityUser> signInWithGoogle() async {
    final auth = _requireAuth;
    try {
      final account = await GoogleSignIn(scopes: ['email']).signIn();
      if (account == null) {
        throw const IdentityFailure(IdentityFailureCode.cancelled);
      }
      final tokens = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      );
      return _mapCredential(await auth.signInWithCredential(credential));
    } on IdentityFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapAuthFailure(error);
    } on PlatformException catch (error) {
      if (_isProviderCancellation(error.code)) {
        throw IdentityFailure(IdentityFailureCode.cancelled, cause: error);
      }
      throw IdentityFailure(IdentityFailureCode.unknown, cause: error);
    }
  }

  @override
  Future<IdentityUser> signInWithApple() async {
    final auth = _requireAuth;
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    try {
      return _mapCredential(await auth.signInWithProvider(provider));
    } on FirebaseAuthException catch (error) {
      throw _mapAuthFailure(error);
    } on PlatformException catch (error) {
      if (_isProviderCancellation(error.code)) {
        throw IdentityFailure(IdentityFailureCode.cancelled, cause: error);
      }
      throw IdentityFailure(IdentityFailureCode.unknown, cause: error);
    }
  }

  bool _isProviderCancellation(String code) =>
      code == 'sign_in_canceled' ||
      code == 'sign_in_cancelled' ||
      code == 'canceled' ||
      code == 'cancelled' ||
      code == 'web-context-cancelled' ||
      code == 'popup-closed-by-user';

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
      'operation-not-allowed' => IdentityFailureCode.providerNotReady,
      'canceled' ||
      'cancelled' ||
      'web-context-cancelled' ||
      'popup-closed-by-user' => IdentityFailureCode.cancelled,
      _ => IdentityFailureCode.unknown,
    };
    return IdentityFailure(code, cause: error);
  }
}
