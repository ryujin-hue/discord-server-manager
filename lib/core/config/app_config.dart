/// Runtime configuration injected at build time with
/// `--dart-define-from-file=env.json`.
///
/// The file is not committed; `env.example.json` documents the expected keys.
class AppConfig {
  const AppConfig({
    required this.discordClientId,
    required this.backendUrl,
    required this.githubRepo,
  });

  /// Values coming from the JSON file passed to `--dart-define-from-file`.
  static const AppConfig fromEnvironment = AppConfig(
    discordClientId: String.fromEnvironment('DISCORD_CLIENT_ID'),
    backendUrl: String.fromEnvironment('BACKEND_URL'),
    githubRepo: String.fromEnvironment('GITHUB_REPO'),
  );

  final String discordClientId;
  final String backendUrl;
  final String githubRepo;

  /// Custom scheme the backend redirects to after the OAuth2 handshake.
  static const String callbackScheme = 'my-discord-manager';

  bool get isConfigured =>
      discordClientId.isNotEmpty &&
      backendUrl.isNotEmpty &&
      githubRepo.isNotEmpty;

  Uri get backendUri => Uri.parse(backendUrl);

  /// Redirect URI registered in the Discord Developer Portal.
  String get redirectUri => '$backendUrl/auth/mobile-callback';

  /// Owner and repository used for the update check.
  String get githubApiBase => 'https://api.github.com/repos/$githubRepo';

  String get githubReleasesPage => 'https://github.com/$githubRepo/releases';
}
