import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/state_views.dart';
import '../../server/presentation/server_providers.dart';
import '../domain/guild.dart';
import 'guild_controller.dart';

/// The list of servers the user administers.
class GuildListScreen extends ConsumerStatefulWidget {
  const GuildListScreen({super.key});

  @override
  ConsumerState<GuildListScreen> createState() => _GuildListScreenState();
}

class _GuildListScreenState extends ConsumerState<GuildListScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckBotPresence();
    }
  }

  /// The bot may have been removed while the app was in the background, so
  /// the presence is checked again as soon as the app comes back.
  void _recheckBotPresence() {
    final guilds = ref.read(guildsControllerProvider).value;
    if (guilds == null) {
      return;
    }
    for (final guild in guilds) {
      ref.invalidate(serverStatusProvider(guild.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final guilds = ref.watch(guildsControllerProvider);
    final favorites =
        ref.watch(favoriteGuildsProvider).value ?? const <String>[];
    final query = ref.watch(guildSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servers'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(guildsControllerProvider.notifier).reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (String value) =>
                  ref.read(guildSearchQueryProvider.notifier).set(value),
              decoration: const InputDecoration(
                hintText: 'Search servers',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: guilds.when(
              skipLoadingOnRefresh: false,
              loading: () => const SkeletonList(),
              error: (Object error, StackTrace stackTrace) => ErrorRetryView(
                failure: error is Exception
                    ? UnknownFailure(error.toString())
                    : UnknownFailure(),
                onRetry: () =>
                    ref.read(guildsControllerProvider.notifier).reload(),
              ),
              data: (List<DiscordGuild> items) {
                final filtered = _applyQuery(items, query);
                if (filtered.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.dns_outlined,
                    title: items.isEmpty
                        ? 'No servers to show'
                        : 'No server matches the search',
                    message: items.isEmpty
                        ? 'You can only see the servers you own or administer.'
                        : 'Try a different name.',
                  );
                }
                final pinned = filtered
                    .where((guild) => favorites.contains(guild.id))
                    .toList(growable: false);
                final rest = filtered
                    .where((guild) => !favorites.contains(guild.id))
                    .toList(growable: false);

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(guildsControllerProvider.notifier).reload(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: <Widget>[
                      if (pinned.isNotEmpty) ...<Widget>[
                        const _SectionHeader(label: 'Pinned'),
                        ...pinned.map(
                          (guild) => _GuildTile(
                            guild: guild,
                            isFavorite: true,
                            onToggleFavorite: () => ref
                                .read(guildsControllerProvider.notifier)
                                .toggleFavorite(guild.id),
                          ),
                        ),
                      ],
                      if (rest.isNotEmpty) ...<Widget>[
                        const _SectionHeader(label: 'All servers'),
                        ...rest.map(
                          (guild) => _GuildTile(
                            guild: guild,
                            isFavorite: false,
                            onToggleFavorite: () => ref
                                .read(guildsControllerProvider.notifier)
                                .toggleFavorite(guild.id),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static List<DiscordGuild> _applyQuery(
    List<DiscordGuild> guilds,
    String query,
  ) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return guilds;
    }
    return guilds
        .where((guild) => guild.name.toLowerCase().contains(trimmed))
        .toList(growable: false);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

class _GuildTile extends ConsumerWidget {
  const _GuildTile({
    required this.guild,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final DiscordGuild guild;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = ref.watch(serverStatusProvider(guild.id));

    return ListTile(
      onTap: () => context.go('/servers/${guild.id}'),
      leading: _GuildAvatar(guild: guild),
      title: Text(guild.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        guild.memberCount == null
            ? 'Members unknown'
            : '${guild.memberCount} members',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (status.hasValue)
            Tooltip(
              message: status.value!.botPresent
                  ? 'The bot is in this server'
                  : 'The bot is not in this server',
              child: Icon(
                status.value!.botPresent
                    ? Icons.check_circle
                    : Icons.error_outline,
                size: 18,
                color: status.value!.botPresent
                    ? const Color(0xFF57F287)
                    : theme.colorScheme.error,
              ),
            ),
          IconButton(
            tooltip: isFavorite ? 'Unpin' : 'Pin',
            onPressed: onToggleFavorite,
            icon: Icon(
              isFavorite ? Icons.push_pin : Icons.push_pin_outlined,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuildAvatar extends StatelessWidget {
  const _GuildAvatar({required this.guild});

  final DiscordGuild guild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = guild.iconUrl;
    if (url != null) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (Object error, StackTrace? stackTrace) {},
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        guild.initials,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
