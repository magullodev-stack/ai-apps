import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'identity_failure.dart';
import 'identity_service.dart';
import 'identity_user.dart';

final class FirebaseIdentityService implements IdentityService {
  FirebaseAuth? _auth;
  bool _initialized = false;
  bool _googleInitialized = false;

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
  Future<IdentityUser> signInWithGoogle() async {
    try {
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize();
        _googleInitialized = true;
      }

      final googleUser = await GoogleSignIn.instance.authenticate();
      final idToken = googleUser.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const IdentityFailure(
          IdentityFailureCode.unknown,
          provider: IdentityProvider.google,
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _requireAuth.signInWithCredential(credential);
      return _mapCredential(result);
    } on GoogleSignInException catch (error) {
      throw IdentityFailure(
        IdentityFailureCode.unknown,
        provider: IdentityProvider.google,
        cause: error,
      );
    } on FirebaseAuthException catch (error) {
      throw _mapAuthFailure(error, provider: IdentityProvider.google);
    }
  }

  @override
  Future<IdentityUser> signInWithApple() async {
    try {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');

      final result = await _requireAuth.signInWithProvider(provider);
      return _mapCredential(result);
    } on FirebaseAuthException catch (error) {
      throw _mapAuthFailure(error, provider: IdentityProvider.apple);
    }
  }

  @override
  Future<void> signOut() async {
    await _requireAuth.signOut();

    if (_googleInitialized) {
      await GoogleSignIn.instance.signOut();
    }
  }

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

  IdentityFailure _mapAuthFailure(
    FirebaseAuthException error, {
    IdentityProvider? provider,
  }) {
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
      'operation-not-allowed' ||
      'configuration-not-found' => IdentityFailureCode.notConfigured,
      _ => IdentityFailureCode.unknown,
    };

    return IdentityFailure(
      code,
      provider: provider,
      cause: error,
    );
  }
}
