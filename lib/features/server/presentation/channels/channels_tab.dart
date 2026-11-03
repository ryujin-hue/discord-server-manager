import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/discord_permissions.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/models.dart';
import '../server_providers.dart';

/// The channels and categories of a server.
class ChannelsTab extends ConsumerWidget {
  const ChannelsTab({required this.guildId, super.key});

  final String guildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(serverChannelsProvider(guildId));

    return Column(
      children: <Widget>[
        Expanded(
          child: channels.when(
            skipLoadingOnRefresh: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) => ErrorRetryView(
              failure: error is AppFailure
                  ? error
                  : UnknownFailure(error.toString()),
              onRetry: () => ref.invalidate(serverChannelsProvider(guildId)),
            ),
            data: (List<ServerChannel> items) {
              if (items.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.tag,
                  title: 'No channel',
                  message: 'This server has no channel yet.',
                );
              }
              final categories = items.where((ServerChannel c) => c.isCategory);
              final others = items.where((ServerChannel c) => !c.isCategory);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  if (categories.isNotEmpty) ...<Widget>[
                    Text(
                      'Categories',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ...categories.map(
                      (ServerChannel category) => _ChannelCard(
                        channel: category,
                        onDelete: () => _delete(context, ref, category),
                        onRename: () => _rename(context, ref, category),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Channels',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...others.map(
                    (ServerChannel channel) => _ChannelCard(
                      channel: channel,
                      onDelete: () => _delete(context, ref, channel),
                      onRename: () => _rename(context, ref, channel),
                      onOverwrite: () => _editOverwrite(context, ref, channel),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () => _create(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Create channel'),
          ),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    var type = 0;
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('New channel'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(controller: controller, autofocus: true),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const <DropdownMenuItem<int>>[
                      DropdownMenuItem<int>(value: 0, child: Text('Text')),
                      DropdownMenuItem<int>(value: 4, child: Text('Category')),
                    ],
                    onChanged: (int? value) {
                      if (value != null) {
                        setState(() => type = value);
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop((controller.text.trim(), type)),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (result == null || result.$1.isEmpty) {
      return;
    }
    try {
      await ref
          .read(serverRepositoryProvider)
          .createChannel(guildId, name: result.$1, type: result.$2);
      ref.invalidate(serverChannelsProvider(guildId));
      if (context.mounted) {
        showSuccess(context, 'The channel was created.');
      }
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ServerChannel channel,
  ) async {
    final controller = TextEditingController(text: channel.name);
    final name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Rename channel'),
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
    try {
      await ref
          .read(serverRepositoryProvider)
          .updateChannel(guildId, channel.id, name: name);
      ref.invalidate(serverChannelsProvider(guildId));
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ServerChannel channel,
  ) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete channel',
      message: 'The channel "${channel.name}" and its messages are deleted.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) {
      return;
    }
    try {
      await ref
          .read(serverRepositoryProvider)
          .deleteChannel(guildId, channel.id);
      ref.invalidate(serverChannelsProvider(guildId));
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _editOverwrite(
    BuildContext context,
    WidgetRef ref,
    ServerChannel channel,
  ) async {
    final roles =
        ref.watch(serverRolesProvider(guildId)).value ?? const <ServerRole>[];
    final result = await showModalBottomSheet<(String, bool, bool)>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) =>
          _OverwriteSheet(channel: channel, roles: roles),
    );
    if (result == null) {
      return;
    }
    try {
      final allow = result.$2 ? PermissionBits.sendMessages : BigInt.zero;
      final deny = result.$3 ? PermissionBits.sendMessages : BigInt.zero;
      await ref
          .read(serverRepositoryProvider)
          .createOverwrite(
            guildId,
            channel.id,
            targetId: result.$1,
            type: 0,
            allow: allow.toString(),
            deny: deny.toString(),
          );
      ref.invalidate(serverChannelsProvider(guildId));
      if (context.mounted) {
        showSuccess(context, 'The permission overwrite was saved.');
      }
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.channel,
    required this.onDelete,
    required this.onRename,
    this.onOverwrite,
  });

  final ServerChannel channel;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback? onOverwrite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(
          channel.isCategory ? Icons.folder_outlined : Icons.tag,
          color: theme.colorScheme.primary,
        ),
        title: Text(channel.name),
        subtitle: Text(
          channel.isCategory
              ? 'Category'
              : 'Type ${channel.type}'
                    '${channel.rateLimitPerUser == null || channel.rateLimitPerUser == 0 ? '' : ' · slowmode ${channel.rateLimitPerUser}s'}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (String value) {
            switch (value) {
              case 'rename':
                onRename();
              case 'overwrite':
                onOverwrite?.call();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(value: 'rename', child: Text('Rename')),
            if (onOverwrite != null)
              const PopupMenuItem<String>(
                value: 'overwrite',
                child: Text('Permission overwrite'),
              ),
            const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

class _OverwriteSheet extends StatefulWidget {
  const _OverwriteSheet({required this.channel, required this.roles});

  final ServerChannel channel;
  final List<ServerRole> roles;

  @override
  State<_OverwriteSheet> createState() => _OverwriteSheetState();
}

class _OverwriteSheetState extends State<_OverwriteSheet> {
  String? _roleId;
  bool _allow = false;
  bool _deny = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Permission overwrite for ${widget.channel.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _roleId,
            decoration: const InputDecoration(labelText: 'Role'),
            items: widget.roles
                .map(
                  (ServerRole role) => DropdownMenuItem<String>(
                    value: role.id,
                    child: Text(role.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) => setState(() => _roleId = value),
          ),
          SwitchListTile(
            value: _allow,
            onChanged: (bool value) => setState(() => _allow = value),
            title: const Text('Allow sending messages'),
          ),
          SwitchListTile(
            value: _deny,
            onChanged: (bool value) => setState(() => _deny = value),
            title: const Text('Deny sending messages'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _roleId == null
                ? null
                : () => Navigator.of(context).pop((_roleId!, _allow, _deny)),
            child: const Text('Save overwrite'),
          ),
        ],
      ),
    );
  }
}
