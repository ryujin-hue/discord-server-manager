import 'package:discord_server_manager/features/auth/data/pkce.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PKCE', () {
    test('derives the challenge of the RFC 7636 appendix B vector', () {
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      expect(
        Pkce.challengeFromVerifier(verifier),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('produces a base64url challenge without padding', () {
      final challenge = Pkce.challengeFromVerifier('verifier');
      expect(challenge, isNot(contains('=')));
      expect(challenge, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });

    test('creates a verifier of 64 characters from the unreserved set', () {
      final verifier = Pkce.createVerifier();
      expect(verifier.length, 64);
      expect(verifier, matches(RegExp(r'^[A-Za-z0-9._~-]+$')));
    });

    test('creates two different verifiers', () {
      expect(Pkce.createVerifier(), isNot(Pkce.createVerifier()));
    });

    test('creates a state of 32 characters', () {
      final state = Pkce.createState();
      expect(state.length, 32);
      expect(state, matches(RegExp(r'^[A-Za-z0-9]+$')));
      expect(state, isNot(Pkce.createState()));
    });
  });
}
