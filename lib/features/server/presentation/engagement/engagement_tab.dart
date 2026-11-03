import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/models.dart';
import '../server_providers.dart';

/// The engagement tab with the announcements, the invite tracker and the
/// reaction and button roles.
class EngagementTab extends ConsumerWidget {
  const EngagementTab({required this.guildId, super.key});

  final String guildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const _AnnouncementsSection(),
        const SizedBox(height: 24),
        const _InviteSection(),
        const SizedBox(height: 24),
        const _RoleMessageSection(),
      ],
    );
  }
}

class _AnnouncementsSection extends ConsumerWidget {
  const _AnnouncementsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guildId = ref.watch(currentGuildIdProvider);
    final announcements = ref.watch(announcementsProvider(guildId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Scheduled announcements',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'The backend sends them, so they survive a restart of the app.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        announcements.when(
          skipLoadingOnRefresh: false,
          loading: () => const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace stackTrace) => ErrorRetryView(
            failure: error is AppFailure
                ? error
                : UnknownFailure(error.toString()),
            onRetry: () => ref.invalidate(announcementsProvider(guildId)),
          ),
          data: (List<ScheduledAnnouncement> items) {
            if (items.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No announcement is scheduled.'),
                ),
              );
            }
            return Column(
              children: items
                  .map(
                    (ScheduledAnnouncement announcement) => Card(
                      child: ListTile(
                        title: Text(
                          announcement.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${DateFormat.yMd().add_Hm().format(announcement.scheduledAt.toLocal())} · '
                          '${announcement.status}',
                        ),
                        trailing: announcement.status == 'pending'
                            ? IconButton(
                                tooltip: 'Cancel',
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(serverRepositoryProvider)
                                        .cancelAnnouncement(
                                          guildId,
                                          announcement.id,
                                        );
                                    ref.invalidate(
                                      announcementsProvider(guildId),
                                    );
                                  } on Object catch (error) {
                                    if (context.mounted) {
                                      showFailure(context, error);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.cancel_outlined),
                              )
                            : null,
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _schedule(context, ref),
          icon: const Icon(Icons.schedule),
          label: const Text('Schedule announcement'),
        ),
      ],
    );
  }

  Future<void> _schedule(BuildContext context, WidgetRef ref) async {
    final guildId = ref.read(currentGuildIdProvider);
    final channels =
        ref.read(serverChannelsProvider(guildId)).value ??
        const <ServerChannel>[];
    final textChannels = channels
        .where((ServerChannel channel) => channel.isText)
        .toList();
    if (textChannels.isEmpty) {
      showFailure(
        context,
        const ValidationFailure('The server has no text channel.'),
      );
      return;
    }
    final contentController = TextEditingController();
    var channelId = textChannels.first.id;
    DateTime scheduledAt = DateTime.now().add(const Duration(hours: 1));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Schedule announcement'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: contentController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Message'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: channelId,
                    decoration: const InputDecoration(labelText: 'Channel'),
                    items: textChannels
                        .map(
                          (ServerChannel channel) => DropdownMenuItem<String>(
                            value: channel.id,
                            child: Text(channel.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() => channelId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Send at'),
                    subtitle: Text(
                      DateFormat.yMd().add_Hm().format(scheduledAt),
                    ),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: scheduledAt,
                      );
                      if (picked == null || !context.mounted) {
                        return;
                      }
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(scheduledAt),
                      );
                      if (time == null) {
                        return;
                      }
                      setState(() {
                        scheduledAt = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Schedule'),
                ),
              ],
            );
          },
        );
      },
    );
    final content = contentController.text.trim();
    contentController.dispose();
    if (confirmed != true || content.isEmpty) {
      return;
    }
    try {
      await ref
          .read(serverRepositoryProvider)
          .scheduleAnnouncement(
            guildId,
            channelId: channelId,
            content: content,
            scheduledAt: scheduledAt,
          );
      ref.invalidate(announcementsProvider(guildId));
      if (context.mounted) {
        showSuccess(context, 'The announcement is scheduled.');
      }
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }
}

class _InviteSection extends ConsumerWidget {
  const _InviteSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guildId = ref.watch(currentGuildIdProvider);
    final invites = ref.watch(invitesProvider(guildId));
    final joins = ref.watch(inviteJoinsProvider(guildId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Invite tracker', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'The gateway remembers the usage of every invite, so it is possible '
          'to see which invite brought which member.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        invites.when(
          skipLoadingOnRefresh: false,
          loading: () => const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace stackTrace) => ErrorRetryView(
            failure: error is AppFailure
                ? error
                : UnknownFailure(error.toString()),
            onRetry: () => ref.invalidate(invitesProvider(guildId)),
          ),
          data: (List<InviteSummary> items) {
            if (items.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No invite was cached yet. The tracker needs the gateway '
                    'to be connected.',
                  ),
                ),
              );
            }
            return Column(
              children: items
                  .map(
                    (InviteSummary invite) => Card(
                      child: ListTile(
                        title: Text(invite.code),
                        subtitle: Text(
                          '${invite.uses} uses · ${invite.joins} joins · '
                          'inviter ${invite.inviterId ?? 'unknown'}',
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: 12),
        joins.when(
          skipLoadingOnRefresh: false,
          loading: () => const SizedBox.shrink(),
          error: (Object error, StackTrace stackTrace) =>
              const SizedBox.shrink(),
          data: (List<InviteJoin> items) {
            if (items.isEmpty) {
              return const Text('No join was attributed to an invite yet.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Recent joins',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...items
                    .take(20)
                    .map(
                      (InviteJoin join) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(join.memberId),
                        subtitle: Text(
                          join.inviteCode == null
                              ? 'Unknown invite'
                              : 'Invite ${join.inviteCode} · '
                                    'inviter ${join.inviterId ?? 'unknown'}',
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RoleMessageSection extends ConsumerWidget {
  const _RoleMessageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guildId = ref.watch(currentGuildIdProvider);
    final channels =
        ref.watch(serverChannelsProvider(guildId)).value ??
        const <ServerChannel>[];
    final roles =
        ref.watch(serverRolesProvider(guildId)).value ?? const <ServerRole>[];
    final textChannels = channels
        .where((ServerChannel channel) => channel.isText)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Role messages', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'A reaction message grants a role when a member reacts, a button '
          'message toggles the role.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: textChannels.isEmpty || roles.isEmpty
              ? null
              : () => _postReactionRole(context, ref, textChannels, roles),
          icon: const Icon(Icons.emoji_emotions_outlined),
          label: const Text('Post a reaction role message'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: textChannels.isEmpty || roles.isEmpty
              ? null
              : () => _postButtonRole(context, ref, textChannels, roles),
          icon: const Icon(Icons.smart_button_outlined),
          label: const Text('Post a button role message'),
        ),
      ],
    );
  }

  Future<void> _postReactionRole(
    BuildContext context,
    WidgetRef ref,
    List<ServerChannel> channels,
    List<ServerRole> roles,
  ) async {
    final guildId = ref.read(currentGuildIdProvider);
    var channelId = channels.first.id;
    var roleId = roles.first.id;
    final emojiController = TextEditingController(text: '👍');
    final contentController = TextEditingController(
      text: 'React to get the role',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Reaction role message'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(labelText: 'Message'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emojiController,
                    decoration: const InputDecoration(labelText: 'Emoji'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: channelId,
                    decoration: const InputDecoration(labelText: 'Channel'),
                    items: channels
                        .map(
                          (ServerChannel channel) => DropdownMenuItem<String>(
                            value: channel.id,
                            child: Text(channel.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() => channelId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: roleId,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: roles
                        .map(
                          (ServerRole role) => DropdownMenuItem<String>(
                            value: role.id,
                            child: Text(role.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() => roleId = value);
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Post'),
                ),
              ],
            );
          },
        );
      },
    );
    final emoji = emojiController.text.trim();
    final content = contentController.text.trim();
    emojiController.dispose();
    contentController.dispose();
    if (confirmed != true || emoji.isEmpty) {
      return;
    }
    try {
      await ref
          .read(serverRepositoryProvider)
          .postReactionRole(
            guildId,
            channelId: channelId,
            content: content,
            bindings: <({String emoji, String roleId})>[
              (emoji: emoji, roleId: roleId),
            ],
          );
      if (context.mounted) {
        showSuccess(context, 'The reaction role message was posted.');
      }
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _postButtonRole(
    BuildContext context,
    WidgetRef ref,
    List<ServerChannel> channels,
    List<ServerRole> roles,
  ) async {
    final guildId = ref.read(currentGuildIdProvider);
    var channelId = channels.first.id;
    var roleId = roles.first.id;
    final contentController = TextEditingController(text: 'Pick a role');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Button role message'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(labelText: 'Message'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: channelId,
                    decoration: const InputDecoration(labelText: 'Channel'),
                    items: channels
                        .map(
                          (ServerChannel channel) => DropdownMenuItem<String>(
                            value: channel.id,
                            child: Text(channel.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() => channelId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: roleId,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: roles
                        .map(
                          (ServerRole role) => DropdownMenuItem<String>(
                            value: role.id,
                            child: Text(role.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() => roleId = value);
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Post'),
                ),
              ],
            );
          },
        );
      },
    );
    final content = contentController.text.trim();
    contentController.dispose();
    if (confirmed != true) {
      return;
    }
    try {
      await ref
          .read(serverRepositoryProvider)
          .postButtonRole(
            guildId,
            channelId: channelId,
            content: content,
            buttons: <({String roleId, String label})>[
              (
                roleId: roleId,
                label:
                    roles
                        .where((ServerRole role) => role.id == roleId)
                        .map((ServerRole role) => role.name)
                        .firstOrNull ??
                    'Role',
              ),
            ],
          );
      if (context.mounted) {
        showSuccess(context, 'The button role message was posted.');
      }
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }
}

/// The announcements of one server.
final announcementsProvider =
    FutureProvider.family<List<ScheduledAnnouncement>, String>(
      (ref, guildId) =>
          ref.watch(serverRepositoryProvider).announcements(guildId),
    );

/// The cached invites of one server.
final invitesProvider = FutureProvider.family<List<InviteSummary>, String>(
  (ref, guildId) => ref.watch(serverRepositoryProvider).invites(guildId),
);

/// The joins that were attributed to an invite.
final inviteJoinsProvider = FutureProvider.family<List<InviteJoin>, String>(
  (ref, guildId) => ref.watch(serverRepositoryProvider).inviteJoins(guildId),
);
