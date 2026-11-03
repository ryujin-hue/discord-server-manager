import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../data/media_picker.dart';
import '../domain/destination.dart';
import '../domain/picked_media.dart';
import '../domain/queue_item.dart';
import '../domain/queue_state.dart';
import 'destinations_screen.dart';
import 'upload_controller.dart';

/// The picker the tests replace with a fake.
final mediaPickerProvider = Provider<MediaPicker>((ref) => DeviceMediaPicker());

/// The files the user picked but did not queue yet.
class PickedFiles extends Notifier<List<PickedMedia>> {
  @override
  List<PickedMedia> build() => const <PickedMedia>[];

  void add(List<PickedMedia> media) {
    state = <PickedMedia>[...state, ...media];
  }

  void removeAt(int index) {
    final copy = <PickedMedia>[...state]..removeAt(index);
    state = copy;
  }

  void clear() => state = const <PickedMedia>[];
}

final pickedFilesProvider = NotifierProvider<PickedFiles, List<PickedMedia>>(
  PickedFiles.new,
);

/// The media sender screen with the picker, the queue and the destinations.
class SendScreen extends ConsumerWidget {
  const SendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(destinationsProvider);
    final picked = ref.watch(pickedFilesProvider);
    final queue = ref.watch(uploadControllerProvider);
    final controller = ref.read(uploadControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Destinations',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const DestinationsScreen(),
              ),
            ),
            icon: const Icon(Icons.settings_input_component),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _DestinationSelector(destinations: destinations),
          const Divider(height: 1),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: <Widget>[
                  const TabBar(
                    tabs: <Widget>[
                      Tab(text: 'Selection'),
                      Tab(text: 'Queue'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        _SelectionTab(picked: picked),
                        _QueueTab(queue: queue, controller: controller),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          FloatingActionButton.extended(
            heroTag: 'pick',
            onPressed: () => _pick(context, ref),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Pick'),
          ),
          FloatingActionButton.extended(
            heroTag: 'send',
            onPressed: picked.isEmpty ? null : () => _enqueue(context, ref),
            icon: const Icon(Icons.send),
            label: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final picker = ref.read(mediaPickerProvider);
    final source = await showModalBottomSheet<_PickSource>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Photos and videos'),
                subtitle: const Text('Uses the Android Photo Picker'),
                onTap: () => Navigator.of(context).pop(_PickSource.photoPicker),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Other files'),
                subtitle: const Text('Uses the system file browser'),
                onTap: () => Navigator.of(context).pop(_PickSource.files),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) {
      return;
    }
    final media = source == _PickSource.photoPicker
        ? await picker.pickMedia()
        : await picker.pickFiles();
    if (media.isEmpty) {
      return;
    }
    ref.read(pickedFilesProvider.notifier).add(media);
  }

  Future<void> _enqueue(BuildContext context, WidgetRef ref) async {
    final destinations =
        ref.read(destinationsProvider).value ?? const <Destination>[];
    final active = destinations.where((Destination d) => d.active).toList();
    if (active.isEmpty) {
      showFailure(
        context,
        const ValidationFailure('Add a destination before sending files.'),
      );
      return;
    }
    final destination = active.first;
    final picked = ref.read(pickedFilesProvider);
    await ref
        .read(uploadControllerProvider.notifier)
        .enqueue(media: picked, destination: destination);
    ref.read(pickedFilesProvider.notifier).clear();
    if (context.mounted) {
      showSuccess(context, '${picked.length} file(s) added to the queue.');
    }
  }
}

enum _PickSource { photoPicker, files }

class _DestinationSelector extends ConsumerWidget {
  const _DestinationSelector({required this.destinations});

  final AsyncValue<List<Destination>> destinations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = destinations.value ?? const <Destination>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.send_to_mobile_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              items.isEmpty
                  ? 'No destination yet'
                  : 'Destination: ${items.where((Destination d) => d.active).firstOrNull?.name ?? items.first.name}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionTab extends ConsumerWidget {
  const _SelectionTab({required this.picked});

  final List<PickedMedia> picked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (picked.isEmpty) {
      return const EmptyStateView(
        icon: Icons.add_photo_alternate_outlined,
        title: 'No file selected',
        message:
            'Pick photos, videos or other files. The source files are never '
            'modified or deleted.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: picked.length,
      itemBuilder: (BuildContext context, int index) {
        final media = picked[index];
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (media.kind == MediaKind.image)
                      Image.file(File(media.path), fit: BoxFit.cover)
                    else
                      ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Icon(
                          media.kind == MediaKind.video
                              ? Icons.movie_outlined
                              : Icons.insert_drive_file_outlined,
                          size: 40,
                        ),
                      ),
                    if (!media.isSupported)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Chip(
                          label: const Text('Unsupported'),
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .errorContainer,
                          labelStyle: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                child: Text(
                  media.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${_formatSize(media.sizeBytes)}'
                  '${media.extension.isEmpty ? '' : ' · ${media.extension}'}'
                  '${media.modifiedAt == null ? '' : ' · ${DateFormat.yMd().format(media.modifiedAt!)}'}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Remove from the selection',
                  onPressed: () =>
                      ref.read(pickedFilesProvider.notifier).removeAt(index),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QueueTab extends ConsumerWidget {
  const _QueueTab({required this.queue, required this.controller});

  final AsyncValue<List<QueueItem>> queue;
  final UploadController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return queue.when(
      skipLoadingOnRefresh: false,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => ErrorRetryView(
        failure: error is AppFailure ? error : UnknownFailure(error.toString()),
        onRetry: () => ref.invalidate(uploadControllerProvider),
      ),
      data: (List<QueueItem> items) {
        if (items.isEmpty) {
          return const EmptyStateView(
            icon: Icons.playlist_add,
            title: 'The queue is empty',
            message: 'Pick files and send them to Discord.',
          );
        }
        return Column(
          children: <Widget>[
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: items.length,
                onReorderItem: (int oldIndex, int newIndex) {
                  final ids = items.map((QueueItem item) => item.id).toList();
                  final moved = ids.removeAt(oldIndex);
                  ids.insert(newIndex, moved);
                  controller.reorder(ids);
                },
                itemBuilder: (BuildContext context, int index) {
                  final item = items[index];
                  return _QueueTile(key: ValueKey<int>(item.id), item: item);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.pause,
                      icon: const Icon(Icons.pause),
                      label: const Text('Pause'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: controller.send,
                      icon: const Icon(Icons.send),
                      label: const Text('Send'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QueueTile extends ConsumerWidget {
  const _QueueTile({required this.item, super.key});

  final QueueItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(uploadControllerProvider.notifier);
    final canRetry =
        item.state == QueueState.failed ||
        item.state == QueueState.cancelled ||
        item.state == QueueState.interrupted;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(
          item.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${_formatSize(item.sizeBytes)} · ${item.state.code}'),
            if (item.state == QueueState.uploading)
              LinearProgressIndicator(value: item.progress),
            if (item.errorMessage != null)
              Text(
                item.errorMessage!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (canRetry)
              IconButton(
                tooltip: 'Retry',
                onPressed: () => controller.retryItem(item.id),
                icon: const Icon(Icons.refresh),
              ),
            IconButton(
              tooltip: 'Remove',
              onPressed: () => controller.removeItem(item.id),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
}
