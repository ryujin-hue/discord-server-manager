import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/discord_permissions.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/models.dart';
import '../../domain/permission_inspector.dart';
import '../server_providers.dart';

/// The roles and the permission inspector of a server.
class RolesAccessTab extends ConsumerWidget {
  const RolesAccessTab({required this.guildId, super.key});

  final String guildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(serverRolesProvider(guildId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('Roles', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'The bot needs the manage roles permission to create and change '
          'roles.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        roles.when(
          skipLoadingOnRefresh: false,
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace stackTrace) => ErrorRetryView(
            failure: error is AppFailure
                ? error
                : UnknownFailure(error.toString()),
            onRetry: () => ref.invalidate(serverRolesProvider(guildId)),
          ),
          data: (List<ServerRole> items) {
            if (items.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('This server has no role besides @everyone.'),
                ),
              );
            }
            return Column(
              children: items
                  .map(
                    (ServerRole role) => Card(
                      child: ListTile(
                        title: Text(role.name),
                        subtitle: Text(
                          'Position ${role.position} · permissions '
                          '${role.permissions.toRadixString(16)}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (String value) =>
                              _handleRoleAction(context, ref, role, value),
                          itemBuilder: (BuildContext context) =>
                              const <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Text('Rename'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _createRole(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Create role'),
        ),
        const SizedBox(height: 24),
        PermissionInspector(guildId: guildId),
      ],
    );
  }

  Future<void> _handleRoleAction(
    BuildContext context,
    WidgetRef ref,
    ServerRole role,
    String action,
  ) async {
    if (action == 'delete') {
      final confirmed = await confirmDestructive(
        context,
        title: 'Delete role',
        message: 'The role "${role.name}" is removed from the server.',
        confirmLabel: 'Delete',
      );
      if (!confirmed) {
        return;
      }
      try {
        await ref.read(serverRepositoryProvider).deleteRole(guildId, role.id);
        ref.invalidate(serverRolesProvider(guildId));
      } on Object catch (error) {
        if (context.mounted) {
          showFailure(context, error);
        }
      }
      return;
    }

    final name = await _askName(context, role.name);
    if (name == null || name.isEmpty) {
      return;
    }
    try {
      await ref
          .read(serverRepositoryProvider)
          .updateRole(guildId, role.id, name: name);
      ref.invalidate(serverRolesProvider(guildId));
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _createRole(BuildContext context, WidgetRef ref) async {
    final name = await _askName(context, 'New role');
    if (name == null || name.isEmpty) {
      return;
    }
    try {
      await ref.read(serverRepositoryProvider).createRole(guildId, name: name);
      ref.invalidate(serverRolesProvider(guildId));
      if (context.mounted) {
        showSuccess(context, 'The role was created.');
      }
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<String?> _askName(BuildContext context, String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Role name'),
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
    return result;
  }
}

/// Shows the permissions a member holds in a channel.
class PermissionInspector extends ConsumerStatefulWidget {
  const PermissionInspector({required this.guildId, super.key});

  final String guildId;

  @override
  ConsumerState<PermissionInspector> createState() =>
      _PermissionInspectorState();
}

class _PermissionInspectorState extends ConsumerState<PermissionInspector> {
  String? _memberId;
  String? _channelId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = ref.watch(serverMembersProvider(widget.guildId));
    final channels = ref.watch(serverChannelsProvider(widget.guildId));
    final roles = ref.watch(serverRolesProvider(widget.guildId));

    final memberList = members.value ?? const <ServerMember>[];
    final channelList = channels.value ?? const <ServerChannel>[];
    final roleList = roles.value ?? const <ServerRole>[];

    final selectedMember = memberList
        .where((ServerMember member) => member.userId == _memberId)
        .firstOrNull;
    final selectedChannel = channelList
        .where((ServerChannel channel) => channel.id == _channelId)
        .firstOrNull;

    final inspection = selectedMember != null && selectedChannel != null
        ? inspectMemberPermissions(
            memberId: selectedMember.userId,
            channelId: selectedChannel.id,
            everyoneRolePermissions:
                roleList
                    .where((ServerRole role) => role.name == '@everyone')
                    .map((ServerRole role) => role.permissions)
                    .firstOrNull ??
                BigInt.zero,
            memberRolePermissions: selectedMember.roles
                .map(
                  (String roleId) =>
                      roleList
                          .where((ServerRole role) => role.id == roleId)
                          .map((ServerRole role) => role.permissions)
                          .firstOrNull ??
                      BigInt.zero,
                )
                .toList(growable: false),
            memberRoleIds: selectedMember.roles,
            overwrites: selectedChannel.overwrites,
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Permission inspector', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Shows the permissions a member holds in a channel, taking the '
          'overwrites of the channel into account.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _memberId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Member', isDense: true),
          items: memberList
              .map(
                (ServerMember member) => DropdownMenuItem<String>(
                  value: member.userId,
                  child: Text(
                    member.displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (String? value) => setState(() => _memberId = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _channelId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Channel',
            isDense: true,
          ),
          items: channelList
              .map(
                (ServerChannel channel) => DropdownMenuItem<String>(
                  value: channel.id,
                  child: Text(channel.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: (String? value) => setState(() => _channelId = value),
        ),
        if (inspection != null) ...<Widget>[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Effective permissions',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    inspection.permissions.toRadixString(16),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _PermissionRow(
                    label: 'Administrator',
                    granted: inspection.isAdministrator,
                  ),
                  _PermissionRow(
                    label: 'Manage server',
                    granted: inspection.canManageGuild,
                  ),
                  _PermissionRow(
                    label: 'Manage channels',
                    granted: inspection.canManageChannels,
                  ),
                  _PermissionRow(
                    label: 'Manage roles',
                    granted: inspection.canManageRoles,
                  ),
                  _PermissionRow(
                    label: 'Manage messages',
                    granted: inspection.canManageMessages,
                  ),
                  _PermissionRow(
                    label: 'Send messages',
                    granted: inspection.canSendMessages,
                  ),
                  _PermissionRow(
                    label: 'View channel',
                    granted: inspection.canViewChannel,
                  ),
                  _PermissionRow(
                    label: 'Read message history',
                    granted: inspection.canReadHistory,
                  ),
                  _PermissionRow(
                    label: 'Kick members',
                    granted: inspection.canKickMembers,
                  ),
                  _PermissionRow(
                    label: 'Ban members',
                    granted: inspection.canBanMembers,
                  ),
                  _PermissionRow(
                    label: 'Timeout members',
                    granted: inspection.canModerateMembers,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.granted});

  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Icon(
            granted ? Icons.check_circle : Icons.remove_circle_outline,
            size: 16,
            color: granted
                ? const Color(0xFF57F287)
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// The permission the bot needs, shown in the readme and in the app.
BigInt botPermissionInteger() => BotPermissions.integer;
