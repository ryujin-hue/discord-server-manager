import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../data/history_repository.dart';
import 'upload_controller.dart';

/// The filter of the history.
class HistoryFilterController extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => HistoryFilter.all;

  void set(HistoryFilter filter) => state = filter;
}

final historyFilterProvider =
    NotifierProvider<HistoryFilterController, HistoryFilter>(
      HistoryFilterController.new,
    );

/// The search term of the history.
class HistorySearchController extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final historySearchProvider = NotifierProvider<HistorySearchController, String>(
  HistorySearchController.new,
);

/// The history of the finished uploads.
class HistoryController extends AsyncNotifier<List<HistoryRecord>> {
  @override
  Future<List<HistoryRecord>> build() async {
    final filter = ref.watch(historyFilterProvider);
    final query = ref.watch(historySearchProvider);
    return ref
        .watch(historyRepositoryProvider)
        .list(filter: filter, query: query);
  }

  Future<void> clear() async {
    await ref.read(historyRepositoryProvider).clear();
    ref.invalidateSelf();
  }
}

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, List<HistoryRecord>>(
      HistoryController.new,
    );

/// The history of the uploads.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyControllerProvider);
    final filter = ref.watch(historyFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Clear the history',
            onPressed: () async {
              final confirmed = await confirmDestructive(
                context,
                title: 'Clear the history',
                message: 'Every entry of the history is removed.',
                confirmLabel: 'Clear',
              );
              if (!confirmed) {
                return;
              }
              await ref.read(historyControllerProvider.notifier).clear();
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (String value) =>
                  ref.read(historySearchProvider.notifier).set(value),
              decoration: const InputDecoration(
                hintText: 'Search by file name',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: HistoryFilter.values
                    .map(
                      (HistoryFilter value) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_filterLabel(value)),
                          selected: filter == value,
                          onSelected: (bool selected) => ref
                              .read(historyFilterProvider.notifier)
                              .set(value),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: history.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) => ErrorRetryView(
                failure: error is AppFailure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () => ref.invalidate(historyControllerProvider),
              ),
              data: (List<HistoryRecord> items) {
                if (items.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.history,
                    title: 'Nothing sent yet',
                    message: 'The finished uploads appear here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final record = items[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          record.isSuccessful
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: record.isSuccessful
                              ? const Color(0xFF57F287)
                              : Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          record.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${record.destinationName} · '
                          '${_formatSize(record.sizeBytes)} · '
                          '${record.durationMs == null ? '—' : '${record.durationMs} ms'}'
                          '${record.errorText == null ? '' : '\n${record.errorText}'}',
                        ),
                        isThreeLine: record.errorText != null,
                        trailing: Text(
                          DateFormat.Hm().format(record.startedAt.toLocal()),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _filterLabel(HistoryFilter filter) => switch (filter) {
    HistoryFilter.all => 'All',
    HistoryFilter.successful => 'Successful',
    HistoryFilter.failed => 'Failed',
    HistoryFilter.cancelled => 'Cancelled',
  };
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
