import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_failure.dart';

/// Renders the three states of an asynchronous value in a uniform way.
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    required this.value,
    required this.data,
    required this.onRetry,
    this.loading,
    this.loadingLabel,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback onRetry;
  final Widget? loading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: false,
      data: (T data) => this.data(data),
      error: (Object error, StackTrace stackTrace) => ErrorRetryView(
        failure: error is AppFailure ? error : UnknownFailure(error.toString()),
        onRetry: onRetry,
      ),
      loading: () => loading ?? _LoadingView(label: loadingLabel),
    );
  }
}

/// The error state with a retry button.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    required this.failure,
    required this.onRetry,
    this.title,
    super.key,
  });

  final AppFailure failure;
  final VoidCallback onRetry;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              title ?? failure.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (failure.discordCode != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Discord error ${failure.discordCode}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The loading state, optionally with a label.
class _LoadingView extends StatelessWidget {
  const _LoadingView({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          if (label != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(label!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// The placeholder shown while the first page loads.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.itemCount = 6, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (BuildContext context, int index) {
        return Container(
          height: 68,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
        );
      },
    );
  }
}

/// The state of a list that has no entries.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 44, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            if (message != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A banner that shows the device is offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.visible, super.key});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.wifi_off_outlined,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No connection. The last loaded data is shown.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
