/// OAuth2 tokens of the signed in Discord user.
class OAuthToken {
  const OAuthToken({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  /// The token is refreshed a minute before it actually expires so a request
  /// never fails because the token expired while it was in flight.
  bool isExpiringSoon({Duration window = const Duration(seconds: 60)}) =>
      DateTime.now().isAfter(expiresAt.subtract(window));

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
