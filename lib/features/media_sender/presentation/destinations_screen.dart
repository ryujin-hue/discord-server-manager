import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/redaction.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../data/upload_engine.dart';
import '../domain/destination.dart';
import '../domain/upload_failure.dart';
import 'upload_controller.dart';

/// The destinations of the media sender. The webhook URL and the bot token
/// are kept in the secure storage and are never sent to the backend.
class DestinationsScreen extends ConsumerWidget {
  const DestinationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(destinationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Destinations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add destination'),
      ),
      body: destinations.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => ErrorRetryView(
          failure: error is AppFailure
              ? error
              : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(destinationsProvider),
        ),
        data: (List<Destination> items) {
          if (items.isEmpty) {
            return const EmptyStateView(
              icon: Icons.send_outlined,
              title: 'No destination',
              message:
                  'Add a webhook or one of your own bots to send media to '
                  'Discord.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final destination = items[index];
              return _DestinationCard(destination: destination);
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => const _AddDestinationSheet(),
    );
  }
}

class _DestinationCard extends ConsumerWidget {
  const _DestinationCard({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  destination.type == DestinationType.webhook
                      ? Icons.link
                      : Icons.smart_toy_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    destination.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: destination.active,
                  onChanged: (bool value) async {
                    await ref
                        .read(destinationRepositoryProvider)
                        .setActive(destination.id, value);
                    ref.invalidate(destinationsProvider);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              destination.type == DestinationType.webhook
                  ? 'Webhook'
                  : 'Bot · channel ${destination.channelId ?? 'unknown'}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => _rename(context, ref),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Rename'),
                ),
                TextButton.icon(
                  onPressed: () => _test(context, ref),
                  icon: const Icon(Icons.wifi_tethering, size: 18),
                  label: const Text('Test'),
                ),
                TextButton.icon(
                  onPressed: () => _delete(context, ref),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: destination.name);
    final name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Name'),
        content: TextField(controller: controller, autofocus: true),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) {
      return;
    }
    await ref.read(destinationRepositoryProvider).rename(destination.id, name);
    ref.invalidate(destinationsProvider);
  }

  Future<void> _test(BuildContext context, WidgetRef ref) async {
    final secret = await ref
        .read(destinationRepositoryProvider)
        .secretOf(destination);
    if (!context.mounted) {
      return;
    }
    if (secret == null || secret.isEmpty) {
      showFailure(
        context,
        const ValidationFailure('The destination has no secret.'),
      );
      return;
    }
    final engine = ref.read(uploadEngineProvider);
    try {
      if (destination.type == DestinationType.webhook) {
        final info = await engine.testWebhook(secret);
        if (context.mounted) {
          showSuccess(context, 'The webhook "${info.name}" answered.');
        }
        return;
      }
      final identity = await engine.validateBotToken(secret);
      if (context.mounted) {
        showSuccess(context, 'The token belongs to ${identity.username}.');
      }
    } on UploadFailure catch (failure) {
      if (context.mounted) {
        showFailure(context, _failure(failure));
      }
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete destination',
      message:
          'The destination "${destination.name}" and its secret are removed.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) {
      return;
    }
    await ref.read(destinationRepositoryProvider).delete(destination.id);
    ref.invalidate(destinationsProvider);
  }

  static AppFailure _failure(UploadFailure failure) {
    return switch (failure.code) {
      UploadErrorCode.invalidWebhook => const ValidationFailure(
        'The webhook URL is not valid anymore.',
      ),
      UploadErrorCode.invalidBotToken => const ValidationFailure(
        'The bot token was rejected by Discord.',
      ),
      UploadErrorCode.permissionDenied => const ValidationFailure(
        'The bot is missing a permission in that channel.',
      ),
      _ => ValidationFailure(failure.message),
    };
  }
}

/// Adds a webhook or a bot destination.
class _AddDestinationSheet extends ConsumerStatefulWidget {
  const _AddDestinationSheet();

  @override
  ConsumerState<_AddDestinationSheet> createState() =>
      _AddDestinationSheetState();
}

class _AddDestinationSheetState extends ConsumerState<_AddDestinationSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _secret = TextEditingController();
  DestinationType _type = DestinationType.webhook;
  bool _busy = false;
  bool _secretVisible = false;
  List<BotGuild> _guilds = const <BotGuild>[];
  List<BotChannel> _channels = const <BotChannel>[];
  String? _guildId;
  String? _channelId;

  @override
  void dispose() {
    _name.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _validateBot() async {
    setState(() => _busy = true);
    try {
      final engine = ref.read(uploadEngineProvider);
      final identity = await engine.validateBotToken(_secret.text.trim());
      final guilds = await engine.botGuilds(_secret.text.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _guilds = guilds;
        _busy = false;
      });
      showSuccess(context, 'The token belongs to ${identity.username}.');
    } on UploadFailure catch (failure) {
      if (mounted) {
        setState(() => _busy = false);
        showFailure(context, _DestinationCard._failure(failure));
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showFailure(context, error);
      }
    }
  }

  Future<void> _loadChannels() async {
    final token = _secret.text.trim();
    final guildId = _guildId;
    if (guildId == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final channels = await ref
          .read(uploadEngineProvider)
          .botChannels(token, guildId);
      if (mounted) {
        setState(() {
          _channels = channels;
          _busy = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showFailure(context, error);
      }
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final secret = _secret.text.trim();
    if (name.isEmpty || secret.isEmpty) {
      showFailure(
        context,
        const ValidationFailure('Name and secret are required.'),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final repository = ref.read(destinationRepositoryProvider);
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      if (_type == DestinationType.webhook) {
        await repository.addWebhook(id: id, name: name, url: secret);
      } else {
        final channelId = _channelId;
        if (channelId == null || _guildId == null) {
          setState(() => _busy = false);
          showFailure(
            context,
            const ValidationFailure('Choose the server and the channel.'),
          );
          return;
        }
        await repository.addBot(
          id: id,
          name: name,
          token: secret,
          guildId: _guildId!,
          channelId: channelId,
        );
      }
      ref.invalidate(destinationsProvider);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showFailure(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWebhook = _type == DestinationType.webhook;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('New destination', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<DestinationType>(
              segments: const <ButtonSegment<DestinationType>>[
                ButtonSegment<DestinationType>(
                  value: DestinationType.webhook,
                  label: Text('Webhook'),
                  icon: Icon(Icons.link),
                ),
                ButtonSegment<DestinationType>(
                  value: DestinationType.bot,
                  label: Text('Bot token'),
                  icon: Icon(Icons.smart_toy_outlined),
                ),
              ],
              selected: <DestinationType>{_type},
              onSelectionChanged: (Set<DestinationType> selection) {
                setState(() => _type = selection.first);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _secret,
              obscureText: !_secretVisible,
              decoration: InputDecoration(
                labelText: isWebhook ? 'Webhook URL' : 'Bot token',
                helperText: isWebhook
                    ? 'The URL stays on the device.'
                    : 'Use your own bot, never a user token.',
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _secretVisible = !_secretVisible),
                  icon: Icon(
                    _secretVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!isWebhook) ...<Widget>[
              OutlinedButton.icon(
                onPressed: _busy ? null : _validateBot,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Validate the token'),
              ),
              const SizedBox(height: 12),
              if (_guilds.isNotEmpty) ...<Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _guildId,
                  decoration: const InputDecoration(labelText: 'Server'),
                  items: _guilds
                      .map(
                        (BotGuild guild) => DropdownMenuItem<String>(
                          value: guild.id,
                          child: Text(guild.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    setState(() => _guildId = value);
                    unawaited(_loadChannels());
                  },
                ),
                const SizedBox(height: 12),
                if (_channels.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _channelId,
                    decoration: const InputDecoration(labelText: 'Channel'),
                    items: _channels
                        .where((BotChannel channel) => channel.isText)
                        .map(
                          (BotChannel channel) => DropdownMenuItem<String>(
                            value: channel.id,
                            child: Text(channel.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) =>
                        setState(() => _channelId = value),
                  ),
                const SizedBox(height: 8),
                Text(
                  'The bot needs the permissions View Channel, Send Messages '
                  'and Attach Files in the chosen channel.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ] else ...<Widget>[
              Text(
                'The webhook is checked with a request that does not post a '
                'message.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(isWebhook ? 'Add webhook' : 'Add bot'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A masked secret that never shows the full value.
String maskedSecret(String? secret) => Redaction.maskSecret(secret);
