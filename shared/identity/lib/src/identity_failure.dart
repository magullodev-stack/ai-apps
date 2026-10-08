enum IdentityProvider {
  email,
  google,
  apple,
}

enum IdentityFailureCode {
  notConfigured,
  invalidEmail,
  weakPassword,
  wrongCredentials,
  emailAlreadyInUse,
  userDisabled,
  network,
  tooManyRequests,
  providerNotReady,
  unknown,
}

class IdentityFailure implements Exception {
  const IdentityFailure(
    this.code, {
    this.provider,
    this.cause,
  });

  final IdentityFailureCode code;
  final IdentityProvider? provider;
  final Object? cause;

  const IdentityFailure.providerNotReady(IdentityProvider provider)
    : this(
        IdentityFailureCode.providerNotReady,
        provider: provider,
      );

  @override
  String toString() {
    final providerSuffix = provider == null ? '' : ' ($provider)';
    return 'IdentityFailure.$code$providerSuffix';
  }
}
