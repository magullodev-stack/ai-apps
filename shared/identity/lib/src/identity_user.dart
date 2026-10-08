class IdentityUser {
  const IdentityUser({
    required this.id,
    required this.email,
    required this.emailVerified,
    this.displayName,
  });

  final String id;
  final String? email;
  final bool emailVerified;
  final String? displayName;
}
