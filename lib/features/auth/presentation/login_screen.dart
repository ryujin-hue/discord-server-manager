import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/providers.dart';
import '../presentation/auth_controller.dart';

/// The sign in screen with the Discord OAuth2 PKCE flow.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final auth = ref.watch(authControllerProvider);

    if (!config.isConfigured) {
      return const _MissingConfigurationScreen();
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.forum_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Discord Server Manager',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in with Discord to administer the servers you own '
                    'and to send media to your channels.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  _LoginButton(
                    loading: auth.isLoading,
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signIn(),
                  ),
                  if (auth.hasError) ...<Widget>[
                    const SizedBox(height: 16),
                    _LoginError(failure: auth.error!),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'The app only requests the identity and the server list. '
                    'Your token stays on the device.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF5865F2),
          foregroundColor: Colors.white,
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.discord),
        label: Text(loading ? 'Signing in…' : 'Sign in with Discord'),
      ),
    );
  }
}

class _LoginError extends StatelessWidget {
  const _LoginError({required this.failure});

  final Object failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String message = switch (failure) {
      final AppFailure value => value.message,
      _ => 'The sign in failed.',
    };
    final isCancelled = failure is CancelledFailure;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCancelled
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isCancelled ? Icons.info_outline : Icons.error_outline,
            size: 20,
            color: isCancelled
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isCancelled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingConfigurationScreen extends StatelessWidget {
  const _MissingConfigurationScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.settings_outlined, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    'The app is not configured yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Copy env.example.json to env.json, fill in the Discord '
                    'application id and the backend URL, then build with '
                    '--dart-define-from-file=env.json.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
