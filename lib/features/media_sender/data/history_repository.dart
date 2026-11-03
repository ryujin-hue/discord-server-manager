import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';

/// The filter of the history screen.
enum HistoryFilter {
  all,
  successful,
  failed,
  cancelled;

  String get code => switch (this) {
    HistoryFilter.all => 'all',
    HistoryFilter.successful => 'successful',
    HistoryFilter.failed => 'failed',
    HistoryFilter.cancelled => 'cancelled',
  };

  static HistoryFilter fromCode(String code) {
    for (final filter in HistoryFilter.values) {
      if (filter.code == code) {
        return filter;
      }
    }
    return HistoryFilter.all;
  }
}

/// One finished upload.
class HistoryRecord {
  const HistoryRecord({
    required this.id,
    required this.fileName,
    required this.destinationName,
    required this.destinationType,
    required this.startedAt,
    required this.sizeBytes,
    required this.status,
    this.endedAt,
    this.durationMs,
    this.errorText,
  });

  final int id;
  final String fileName;
  final String destinationName;
  final String destinationType;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMs;
  final int sizeBytes;
  final String status;
  final String? errorText;

  bool get isSuccessful => status == 'completed';
}

/// Stores the history of the finished uploads.
class HistoryRepository {
  HistoryRepository(this._database);

  final AppDatabase _database;

  Future<void> add(HistoryRecord record) async {
    await _database
        .into(_database.uploadHistoryEntries)
        .insert(
          UploadHistoryEntriesCompanion.insert(
            fileName: record.fileName,
            destinationName: record.destinationName,
            destinationType: record.destinationType,
            startedAt: record.startedAt,
            endedAt: Value(record.endedAt),
            durationMs: Value(record.durationMs),
            sizeBytes: record.sizeBytes,
            status: record.status,
            errorText: Value(record.errorText),
          ),
        );
  }

  Future<List<HistoryRecord>> list({
    HistoryFilter filter = HistoryFilter.all,
    String query = '',
  }) async {
    final statement = _database.select(_database.uploadHistoryEntries)
      ..orderBy([(row) => OrderingTerm.desc(row.startedAt)]);
    if (filter != HistoryFilter.all) {
      final status = switch (filter) {
        HistoryFilter.successful => 'completed',
        HistoryFilter.failed => 'failed',
        HistoryFilter.cancelled => 'cancelled',
        HistoryFilter.all => 'completed',
      };
      statement.where((row) => row.status.equals(status));
    }
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isNotEmpty) {
      statement.where((row) => row.fileName.lower().like('%$trimmed%'));
    }
    final rows = await statement.get();
    return rows
        .map(
          (row) => HistoryRecord(
            id: row.id,
            fileName: row.fileName,
            destinationName: row.destinationName,
            destinationType: row.destinationType,
            startedAt: row.startedAt,
            endedAt: row.endedAt,
            durationMs: row.durationMs,
            sizeBytes: row.sizeBytes,
            status: row.status,
            errorText: row.errorText,
          ),
        )
        .toList(growable: false);
  }

  Future<void> clear() async {
    await _database.delete(_database.uploadHistoryEntries).go();
  }
}
