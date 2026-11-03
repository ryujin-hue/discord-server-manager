import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/models.dart';
import '../server_providers.dart';

/// Lets the user pick the messages that are deleted.
class PurgeSheet extends ConsumerStatefulWidget {
  const PurgeSheet({required this.guildId, required this.channels, super.key});

  final String guildId;
  final List<ServerChannel> channels;

  @override
  ConsumerState<PurgeSheet> createState() => _PurgeSheetState();
}

class _PurgeSheetState extends ConsumerState<PurgeSheet> {
  String? _channelId;
  final Set<String> _selected = <String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _channelId = widget.channels.isEmpty ? null : widget.channels.first.id;
  }

  Future<void> _purge() async {
    final channelId = _channelId;
    if (channelId == null) {
      return;
    }
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete ${_selected.length} messages',
      message:
          'The messages are deleted permanently. Only messages younger than '
          '14 days can be removed.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(serverRepositoryProvider)
          .purge(
            widget.guildId,
            channelId: channelId,
            messageIds: _selected.toList(growable: false),
          );
      if (mounted) {
        Navigator.of(context).pop();
        showSuccess(context, '${_selected.length} messages were deleted.');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final channelId = _channelId;
    final messages = channelId == null
        ? const AsyncValue<List<RecentMessage>>.data(<RecentMessage>[])
        : ref.watch(
            recentMessagesProvider((
              guildId: widget.guildId,
              channelId: channelId,
            )),
          );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController controller) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Purge messages', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Discord deletes between 2 and 100 messages per call and only '
                'messages that are younger than 14 days.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: channelId,
                decoration: const InputDecoration(
                  labelText: 'Channel',
                  isDense: true,
                ),
                items: widget.channels
                    .map(
                      (ServerChannel channel) => DropdownMenuItem<String>(
                        value: channel.id,
                        child: Text(channel.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (String? value) {
                  setState(() {
                    _channelId = value;
                    _selected.clear();
                  });
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: messages.when(
                  skipLoadingOnRefresh: false,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (Object error, StackTrace stackTrace) =>
                      ErrorRetryView(
                        failure: error is AppFailure
                            ? error
                            : UnknownFailure(error.toString()),
                        onRetry: () => ref.invalidate(
                          recentMessagesProvider((
                            guildId: widget.guildId,
                            channelId: channelId ?? '',
                          )),
                        ),
                      ),
                  data: (List<RecentMessage> items) {
                    if (items.isEmpty) {
                      return const EmptyStateView(
                        icon: Icons.chat_bubble_outline,
                        title: 'No messages loaded',
                      );
                    }
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (BuildContext context, int index) {
                        final message = items[index];
                        final tooOld = message.isTooOld;
                        return CheckboxListTile(
                          value: _selected.contains(message.id),
                          enabled: !tooOld,
                          title: Text(
                            message.content.isEmpty
                                ? '(no text)'
                                : message.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            tooOld
                                ? 'Older than 14 days, cannot be deleted'
                                : '${message.authorName ?? 'Unknown'} · '
                                      '${DateFormat.yMd().add_Hm().format(message.timestamp.toLocal())}',
                          ),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value ?? false) {
                                _selected.add(message.id);
                              } else {
                                _selected.remove(message.id);
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed:
                    _busy || _selected.length < 2 || _selected.length > 100
                    ? null
                    : _purge,
                child: Text(
                  _selected.length < 2
                      ? 'Select at least 2 messages'
                      : 'Delete ${_selected.length} messages',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
