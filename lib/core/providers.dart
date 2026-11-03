import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/auth/data/auth_repository.dart';
import 'config/app_config.dart';
import 'network/auth_interceptor.dart';
import 'network/backend_api.dart';
import 'network/discord_api.dart';
import 'security/secret_store.dart';
import 'security/token_store.dart';
import 'storage/app_database.dart';

/// The build time configuration.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment,
);

/// The secure storage that holds the tokens and the user supplied secrets.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(aOptions: AndroidOptions()),
);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(ref.watch(secureStorageProvider)),
);

final secretStoreProvider = Provider<SecretStorage>(
  (ref) => SecretStore(ref.watch(secureStorageProvider)),
);

/// The local database with the queue, the history and the settings.
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// A Dio client without any interceptor, used for the OAuth2 token calls.
final plainDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: <String, String>{'Accept': 'application/json'},
    ),
  );
});

/// The repository that performs the OAuth2 PKCE flow.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    config: ref.watch(appConfigProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    dio: ref.watch(plainDioProvider),
  );
});

/// The Dio client that talks to the backend and to Discord with the user
/// token attached.
///
/// `baseUrl` is set to the backend URL so that `BackendApi` can use relative
/// paths (`/guilds/:id/overview`). `DiscordApi` uses its own absolute URLs
/// (`https://discord.com/api/v10/...`), which Dio resolves correctly even when
/// a baseUrl is configured, because absolute request paths override baseUrl.
final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.backendUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: <String, String>{'Accept': 'application/json'},
    ),
  );
  final interceptor = AuthInterceptor(
    tokenStore: ref.watch(tokenStoreProvider),
    authRepository: ref.watch(authRepositoryProvider),
    dio: dio,
    onSignedOut: () => ref.read(signedOutSignalProvider.notifier).signOut(),
  );
  dio.interceptors.add(interceptor);
  return dio;
});

/// A Dio client used for the uploads. It never carries the user token.
final uploadDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 300),
      sendTimeout: const Duration(seconds: 300),
    ),
  );
});

final backendApiProvider = Provider<BackendApi>(
  (ref) => BackendApi(ref.watch(dioProvider)),
);

final discordApiProvider = Provider<DiscordApi>(
  (ref) => DiscordApi(ref.watch(dioProvider)),
);

/// A signal that tells the router to show the sign in screen again.
class SignedOutSignal extends Notifier<int> {
  @override
  int build() => 0;

  void signOut() {
    state = state + 1;
  }
}

final signedOutSignalProvider = NotifierProvider<SignedOutSignal, int>(
  SignedOutSignal.new,
);
