import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/models.dart';
import '../server_providers.dart';
import 'automod/automod_screen.dart';
import 'purge_sheet.dart';

/// The member the moderation actions apply to.
class SelectedMember extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final selectedMemberProvider = NotifierProvider<SelectedMember, String?>(
  SelectedMember.new,
);

/// The moderation tab with the actions that need a bot token.
class ModerationTab extends ConsumerWidget {
  const ModerationTab({required this.guildId, super.key});

  final String guildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(serverMembersProvider(guildId));
    final channels = ref.watch(serverChannelsProvider(guildId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _MemberPicker(guildId: guildId, members: members),
        const SizedBox(height: 16),
        _ActionGrid(guildId: guildId, members: members, channels: channels),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) =>
                  AutoModScreen(guildId: guildId),
            ),
          ),
          icon: const Icon(Icons.shield_outlined),
          label: const Text('Auto moderation rules'),
        ),
      ],
    );
  }
}

/// A member picker used by the moderation actions.
class _MemberPicker extends ConsumerWidget {
  const _MemberPicker({required this.guildId, required this.members});

  final String guildId;
  final AsyncValue<List<ServerMember>> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMemberProvider);
    return members.when(
      skipLoadingOnRefresh: false,
      loading: () => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) => ErrorRetryView(
        failure: error is AppFailure ? error : UnknownFailure(error.toString()),
        onRetry: () => ref.invalidate(serverMembersProvider(guildId)),
      ),
      data: (List<ServerMember> members) {
        if (members.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No member was loaded for this server.'),
            ),
          );
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Member', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Choose a member',
                  ),
                  items: members
                      .map(
                        (ServerMember member) => DropdownMenuItem<String>(
                          value: member.userId,
                          child: Text(
                            '${member.displayName} (${member.userId})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) =>
                      ref.read(selectedMemberProvider.notifier).set(value),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The moderation actions.
class _ActionGrid extends ConsumerStatefulWidget {
  const _ActionGrid({
    required this.guildId,
    required this.members,
    required this.channels,
  });

  final String guildId;
  final AsyncValue<List<ServerMember>> members;
  final AsyncValue<List<ServerChannel>> channels;

  @override
  ConsumerState<_ActionGrid> createState() => _ActionGridState();
}

class _ActionGridState extends ConsumerState<_ActionGrid> {
  bool _busy = false;

  String? get _selectedMemberId => ref.read(selectedMemberProvider);

  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        showSuccess(context, successMessage);
      }
    } on Object catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _ban() async {
    final memberId = _selectedMemberId;
    if (memberId == null) {
      return;
    }
    final confirmed = await confirmDestructive(
      context,
      title: 'Ban member',
      message: 'The member $memberId will be banned from this server.',
      confirmLabel: 'Ban',
    );
    if (!confirmed) {
      return;
    }
    await _run(
      () => ref
          .read(serverRepositoryProvider)
          .ban(widget.guildId, userId: memberId),
      'The member was banned.',
    );
  }

  Future<void> _kick() async {
    final memberId = _selectedMemberId;
    if (memberId == null) {
      return;
    }
    final confirmed = await confirmDestructive(
      context,
      title: 'Kick member',
      message: 'The member $memberId will leave the server and can join again.',
      confirmLabel: 'Kick',
    );
    if (!confirmed) {
      return;
    }
    await _run(
      () => ref
          .read(serverRepositoryProvider)
          .kick(widget.guildId, userId: memberId),
      'The member was kicked.',
    );
  }

  Future<void> _timeout() async {
    final memberId = _selectedMemberId;
    if (memberId == null) {
      return;
    }
    final minutes = await _askDuration();
    if (minutes == null || !mounted) {
      return;
    }
    final confirmed = await confirmDestructive(
      context,
      title: 'Timeout member',
      message: 'The member $memberId cannot talk for $minutes minutes.',
      confirmLabel: 'Timeout',
    );
    if (!confirmed) {
      return;
    }
    await _run(
      () => ref
          .read(serverRepositoryProvider)
          .timeout(
            widget.guildId,
            userId: memberId,
            durationSeconds: minutes * 60,
          ),
      'The member was timed out.',
    );
  }

  Future<void> _warning() async {
    final memberId = _selectedMemberId;
    if (memberId == null) {
      return;
    }
    final reason = await _askText('Reason of the warning');
    if (reason == null || reason.isEmpty) {
      return;
    }
    await _run(
      () => ref
          .read(serverRepositoryProvider)
          .issueWarning(widget.guildId, userId: memberId, reason: reason),
      'The warning was issued.',
    );
  }

  Future<void> _lockdown() async {
    final channels = widget.channels.value ?? const <ServerChannel>[];
    final textChannels = channels.where((ServerChannel c) => c.isText).toList();
    if (textChannels.isEmpty) {
      if (mounted) {
        showFailure(
          context,
          const ValidationFailure('The server has no text channel.'),
        );
      }
      return;
    }
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      builder: (BuildContext context) => _ChannelSelectionSheet(
        channels: textChannels,
        title: 'Lock channels',
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) {
      return;
    }
    final confirmed = await confirmDestructive(
      context,
      title: 'Lock channels',
      message:
          'Everyone loses the permission to send messages in '
          '${selected.length} channel(s). The previous setting is stored and '
          'restored when you unlock them.',
      confirmLabel: 'Lock',
    );
    if (!confirmed) {
      return;
    }
    await _run(
      () => ref
          .read(serverRepositoryProvider)
          .lockChannels(widget.guildId, selected),
      'The channels are locked.',
    );
  }

  Future<void> _unlock() async {
    final channels = widget.channels.value ?? const <ServerChannel>[];
    final textChannels = channels.where((ServerChannel c) => c.isText).toList();
    if (textChannels.isEmpty) {
      return;
    }
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      builder: (BuildContext context) => _ChannelSelectionSheet(
        channels: textChannels,
        title: 'Unlock channels',
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) {
      return;
    }
    final confirmed = await confirmDestructive(
      context,
      title: 'Unlock channels',
      message:
          'The previous permission of ${selected.length} channel(s) is restored.',
      confirmLabel: 'Unlock',
    );
    if (!confirmed) {
      return;
    }
    await _run(
      () => ref
          .read(serverRepositoryProvider)
          .unlockChannels(widget.guildId, selected),
      'The channels are unlocked.',
    );
  }

  Future<void> _massSlowmode() async {
    final seconds = await _askDuration(unit: 'seconds', maximum: 21600);
    if (seconds == null) {
      return;
    }
    await _run(
      () => ref
          .read(serverRepositoryProvider)
          .setMassSlowmode(widget.guildId, seconds),
      'The slowmode was applied to every text channel.',
    );
  }

  Future<void> _purge() async {
    final channels = widget.channels.value ?? const <ServerChannel>[];
    final textChannels = channels.where((ServerChannel c) => c.isText).toList();
    if (textChannels.isEmpty) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) =>
          PurgeSheet(guildId: widget.guildId, channels: textChannels),
    );
  }

  Future<int?> _askDuration({
    int maximum = 10080,
    String unit = 'minutes',
  }) async {
    final controller = TextEditingController(text: '10');
    final result = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Duration in $unit'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text);
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || result <= 0 || result > maximum) {
      return null;
    }
    return result;
  }

  Future<String?> _askText(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
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
        );
      },
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = widget.members.value ?? const <ServerMember>[];
    final selectedMember = ref.watch(selectedMemberProvider);
    final hasMember = members.isNotEmpty && selectedMember != null;

    Widget action({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
      bool destructive = false,
    }) {
      return Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _busy ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  icon,
                  color: destructive
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(height: 10),
                Text(label, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Moderation', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'The bot needs the ban, kick and moderate members permissions to run '
          'these actions.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.1,
          children: <Widget>[
            action(
              icon: Icons.gavel,
              label: 'Ban member',
              destructive: true,
              onPressed: hasMember ? _ban : () {},
            ),
            action(
              icon: Icons.logout,
              label: 'Kick member',
              destructive: true,
              onPressed: hasMember ? _kick : () {},
            ),
            action(
              icon: Icons.timer,
              label: 'Timeout member',
              destructive: true,
              onPressed: hasMember ? _timeout : () {},
            ),
            action(
              icon: Icons.warning_amber,
              label: 'Issue warning',
              onPressed: hasMember ? _warning : () {},
            ),
            action(
              icon: Icons.lock,
              label: 'Lock channels',
              destructive: true,
              onPressed: _lockdown,
            ),
            action(
              icon: Icons.lock_open,
              label: 'Unlock channels',
              onPressed: _unlock,
            ),
            action(
              icon: Icons.delete_sweep,
              label: 'Purge messages',
              destructive: true,
              onPressed: _purge,
            ),
            action(
              icon: Icons.hourglass_bottom,
              label: 'Mass slowmode',
              onPressed: _massSlowmode,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Purging deletes between 2 and 100 messages per call and only '
          'messages that are younger than 14 days.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Lets the user pick several channels.
class _ChannelSelectionSheet extends StatefulWidget {
  const _ChannelSelectionSheet({required this.channels, required this.title});

  final List<ServerChannel> channels;
  final String title;

  @override
  State<_ChannelSelectionSheet> createState() => _ChannelSelectionSheetState();
}

class _ChannelSelectionSheetState extends State<_ChannelSelectionSheet> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.channels.length,
                itemBuilder: (BuildContext context, int index) {
                  final channel = widget.channels[index];
                  return CheckboxListTile(
                    value: _selected.contains(channel.id),
                    title: Text(channel.name),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value ?? false) {
                          _selected.add(channel.id);
                        } else {
                          _selected.remove(channel.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_selected.toList()),
              child: Text('Apply to ${_selected.length} channel(s)'),
            ),
          ],
        ),
      ),
    );
  }
}
