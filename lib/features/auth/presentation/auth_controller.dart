import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/providers.dart';
import '../domain/discord_user.dart';
import '../domain/oauth_token.dart';

/// The signed in session.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final OAuthToken token;
  final DiscordUser user;
}

/// The state of the sign in.
class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    ref.listen<int>(signedOutSignalProvider, (int? previous, int next) {
      state = const AsyncValue<AuthSession?>.data(null);
    });

    final token = await ref.watch(tokenStoreProvider).read();
    if (token == null) {
      return null;
    }
    try {
      final user = await ref.watch(discordApiProvider).currentUser();
      return AuthSession(token: token, user: user);
    } on AppFailure {
      return null;
    } on Object {
      return null;
    }
  }

  /// Starts the OAuth2 flow. The state of the provider holds the failure so
  /// the screen can show the real Discord error.
  Future<bool> signIn() async {
    state = const AsyncValue<AuthSession?>.loading();
    try {
      final token = await ref.read(authRepositoryProvider).signIn();
      final user = await ref.read(discordApiProvider).currentUser();
      state = AsyncValue<AuthSession?>.data(
        AuthSession(token: token, user: user),
      );
      return true;
    } on AppFailure catch (failure) {
      state = AsyncValue<AuthSession?>.error(failure, StackTrace.current);
      return false;
    } on Object catch (error) {
      state = AsyncValue<AuthSession?>.error(
        UnknownFailure(error.toString()),
        StackTrace.current,
      );
      return false;
    }
  }

  /// Revokes the session and clears the stored tokens. The tokens are cleared
  /// even when the revocation fails.
  Future<void> signOut() async {
    final token = await ref.read(tokenStoreProvider).read();
    if (token != null) {
      try {
        await ref.read(authRepositoryProvider).revoke(token);
      } on Object {
        // A failed revocation must not keep the user signed in.
      }
    }
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncValue<AuthSession?>.data(null);
    ref.read(signedOutSignalProvider.notifier).signOut();
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

/// The signed in user, or null when nobody is signed in.
final currentUserProvider = Provider<DiscordUser?>(
  (ref) => ref.watch(authControllerProvider).value?.user,
);
