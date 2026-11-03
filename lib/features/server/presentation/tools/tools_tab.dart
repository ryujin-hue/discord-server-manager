import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/models.dart';
import '../server_providers.dart';

/// The server tools tab with the emojis, the stickers, the audit log and the
/// backup.
class ToolsTab extends ConsumerWidget {
  const ToolsTab({required this.guildId, super.key});

  final String guildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: <Widget>[
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: 'Emojis', height: 44),
              Tab(text: 'Stickers', height: 44),
              Tab(text: 'Audit log', height: 44),
              Tab(text: 'Backup', height: 44),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _EmojiList(guildId: guildId),
                _StickerList(guildId: guildId),
                _AuditLog(guildId: guildId),
                _Backup(guildId: guildId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiList extends ConsumerWidget {
  const _EmojiList({required this.guildId});

  final String guildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emojis = ref.watch(serverEmojisProvider(guildId));

    return emojis.when(
      skipLoadingOnRefresh: false,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => ErrorRetryView(
        failure: error is AppFailure ? error : UnknownFailure(error.toString()),
        onRetry: () => ref.invalidate(serverEmojisProvider(guildId)),
      ),
      data: (List<ServerEmoji> items) {
        if (items.isEmpty) {
          return const EmptyStateView(
            icon: Icons.emoji_emotions_outlined,
            title: 'No custom emoji',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) {
            final emoji = items[index];
            return Card(
              child: ListTile(
                title: Text(emoji.displayName),
                subtitle: Text(
                  '${emoji.id}${emoji.animated ? ' · animated' : ''}',
                ),
                trailing: IconButton(
                  tooltip: 'Delete',
                  onPressed: () async {
                    final confirmed = await confirmDestructive(
                      context,
                      title: 'Delete emoji',
                      message: 'The emoji "${emoji.displayName}" is deleted.',
                      confirmLabel: 'Delete',
                    );
                    if (!confirmed) {
                      return;
                    }
                    try {
                      await ref
                          .read(serverRepositoryProvider)
                          .deleteEmoji(guildId, emoji.id);
                      ref.invalidate(serverEmojisProvider(guildId));
                    } on Object catch (error) {
                      if (context.mounted) {
                        showFailure(context, error);
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StickerList extends ConsumerWidget {
  const _StickerList({required this.guildId});

  final String guildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stickers = ref.watch(serverStickersProvider(guildId));

    return stickers.when(
      skipLoadingOnRefresh: false,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => ErrorRetryView(
        failure: error is AppFailure ? error : UnknownFailure(error.toString()),
        onRetry: () => ref.invalidate(serverStickersProvider(guildId)),
      ),
      data: (List<ServerSticker> items) {
        if (items.isEmpty) {
          return const EmptyStateView(
            icon: Icons.emoji_emotions,
            title: 'No sticker',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) {
            final sticker = items[index];
            return Card(
              child: ListTile(
                title: Text(sticker.name),
                subtitle: Text(sticker.description ?? sticker.tags),
                trailing: IconButton(
                  tooltip: 'Delete',
                  onPressed: () async {
                    final confirmed = await confirmDestructive(
                      context,
                      title: 'Delete sticker',
                      message: 'The sticker "${sticker.name}" is deleted.',
                      confirmLabel: 'Delete',
                    );
                    if (!confirmed) {
                      return;
                    }
                    try {
                      await ref
                          .read(serverRepositoryProvider)
                          .deleteSticker(guildId, sticker.id);
                      ref.invalidate(serverStickersProvider(guildId));
                    } on Object catch (error) {
                      if (context.mounted) {
                        showFailure(context, error);
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AuditLog extends ConsumerWidget {
  const _AuditLog({required this.guildId});

  final String guildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(auditLogProvider(guildId));

    return entries.when(
      skipLoadingOnRefresh: false,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => ErrorRetryView(
        failure: error is AppFailure ? error : UnknownFailure(error.toString()),
        onRetry: () => ref.invalidate(auditLogProvider(guildId)),
      ),
      data: (List<AuditLogEntry> items) {
        if (items.isEmpty) {
          return const EmptyStateView(
            icon: Icons.history,
            title: 'No audit log entry',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) {
            final entry = items[index];
            return Card(
              child: ListTile(
                title: Text('Action ${entry.actionType}'),
                subtitle: Text(
                  '${entry.userId ?? 'unknown'} → ${entry.targetId ?? 'unknown'}\n'
                  '${DateFormat.yMd().add_Hm().format(entry.createdAt.toLocal())}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _Backup extends ConsumerWidget {
  const _Backup({required this.guildId});

  final String guildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('Backup', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'The export contains the roles, the categories, the channels and '
          'their permission overwrites. The restore only creates the items '
          'that are missing and never deletes anything.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _export(context, ref),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Export the backup'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _restore(context, ref),
          icon: const Icon(Icons.upload_outlined),
          label: const Text('Restore from a backup file'),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final backup = await ref
          .read(serverRepositoryProvider)
          .exportBackup(guildId);
      final json = JsonEncoder.withIndent('  ').convert(backup);
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Backup'),
            content: SizedBox(
              width: 420,
              height: 320,
              child: SingleChildScrollView(child: SelectableText(json)),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Restore a backup',
      message:
          'The restore creates the roles, categories and channels of the '
          'backup that do not exist yet. Nothing is deleted or changed.',
      confirmLabel: 'Choose a file',
      isDestructive: false,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final document = await showModalBottomSheet<Map<Object?, Object?>>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => const _BackupFileSheet(),
    );
    if (document == null || !context.mounted) {
      return;
    }
    try {
      await ref.read(serverRepositoryProvider).restoreBackup(guildId, document);
      if (context.mounted) {
        showSuccess(context, 'The backup was restored.');
      }
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }
}

class _BackupFileSheet extends ConsumerStatefulWidget {
  const _BackupFileSheet();

  @override
  ConsumerState<_BackupFileSheet> createState() => _BackupFileSheetState();
}

class _BackupFileSheetState extends ConsumerState<_BackupFileSheet> {
  Map<Object?, Object?>? _document;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Choose a backup file',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.folder_open),
            label: const Text('Pick a JSON file'),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _document == null
                ? null
                : () => Navigator.of(context).pop(_document),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  Future<void> _pick() async {
    final picker = ref.read(backupFilePickerProvider);
    final path = await picker();
    if (path == null) {
      return;
    }
    try {
      final content = await File(path).readAsString();
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        setState(() {
          _document = decoded.cast<Object?, Object?>();
          _error = null;
        });
      } else {
        setState(() => _error = 'The file does not contain a backup object.');
      }
    } on Object {
      setState(() => _error = 'The file could not be read as a backup.');
    }
  }
}

/// The emojis of one server.
final serverEmojisProvider = FutureProvider.family<List<ServerEmoji>, String>(
  (ref, guildId) => ref.watch(serverRepositoryProvider).emojis(guildId),
);

/// The stickers of one server.
final serverStickersProvider =
    FutureProvider.family<List<ServerSticker>, String>(
      (ref, guildId) => ref.watch(serverRepositoryProvider).stickers(guildId),
    );

/// The audit log of one server.
final auditLogProvider = FutureProvider.family<List<AuditLogEntry>, String>(
  (ref, guildId) => ref.watch(serverRepositoryProvider).auditLog(guildId),
);

/// Picks a backup file from the device.
final backupFilePickerProvider = Provider<Future<String?> Function()>((ref) {
  return () async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result.isEmpty) {
      return null;
    }
    return result.first.path;
  };
});
