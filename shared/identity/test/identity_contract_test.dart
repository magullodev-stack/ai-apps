import 'package:ai_apps_identity/ai_apps_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la identidad compartida distingue proveedores y fallos', () {
    const failure = IdentityFailure.providerNotReady(
      IdentityProvider.google,
    );

    expect(failure.code, IdentityFailureCode.providerNotReady);
    expect(failure.provider, IdentityProvider.google);
  });
}
