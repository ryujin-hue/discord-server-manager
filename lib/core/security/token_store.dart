import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/oauth_token.dart';

/// Reads and writes the OAuth2 tokens of the signed in user. The
/// implementation keeps them in the Android Keystore.
abstract class TokenStorage {
  Future<OAuthToken?> read();

  Future<void> write(OAuthToken token);

  Future<void> clear();
}

/// Stores the tokens in the secure storage of the platform.
class TokenStore implements TokenStorage {
  TokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const String accessTokenKey = 'discord_access_token';
  static const String refreshTokenKey = 'discord_refresh_token';
  static const String expiresAtKey = 'discord_expires_at';

  @override
  Future<OAuthToken?> read() async {
    final accessToken = await _storage.read(key: accessTokenKey);
    final refreshToken = await _storage.read(key: refreshTokenKey);
    final expiresAt = await _storage.read(key: expiresAtKey);
    if (accessToken == null || refreshToken == null || expiresAt == null) {
      return null;
    }
    final parsed = DateTime.tryParse(expiresAt);
    if (parsed == null) {
      return null;
    }
    return OAuthToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: parsed,
    );
  }

  @override
  Future<void> write(OAuthToken token) async {
    await _storage.write(key: accessTokenKey, value: token.accessToken);
    await _storage.write(key: refreshTokenKey, value: token.refreshToken);
    await _storage.write(
      key: expiresAtKey,
      value: token.expiresAt.toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: refreshTokenKey);
    await _storage.delete(key: expiresAtKey);
  }
}
