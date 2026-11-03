import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Proof Key for Code Exchange helpers for the OAuth2 public client flow.
class Pkce {
  const Pkce._();

  /// RFC 7636 allows 43 to 128 characters. 64 keeps the verifier short
  /// enough for every browser while staying well above the minimum.
  static const int verifierLength = 64;

  static const String _unreserved =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  /// Creates a high entropy code verifier from a cryptographically secure
  /// random source.
  static String createVerifier({Random? random}) {
    final source = random ?? Random.secure();
    return List<String>.generate(
      verifierLength,
      (_) => _unreserved[source.nextInt(_unreserved.length)],
      growable: false,
    ).join();
  }

  /// Derives the S256 code challenge from a verifier.
  static String challengeFromVerifier(String verifier) {
    final digest = sha256.convert(ascii.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Creates the opaque state value that protects the authorization request
  /// against cross site request forgery.
  static String createState({Random? random}) {
    final source = random ?? Random.secure();
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return List<String>.generate(
      32,
      (_) => alphabet[source.nextInt(alphabet.length)],
      growable: false,
    ).join();
  }
}
