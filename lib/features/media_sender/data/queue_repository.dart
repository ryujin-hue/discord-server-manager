import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/picked_media.dart';
import '../domain/queue_item.dart';
import '../domain/queue_state.dart';

/// Persists the upload queue.
class QueueRepository {
  QueueRepository(this._database);

  final AppDatabase _database;

  Future<List<QueueItem>> list() async {
    final rows =
        await (_database.select(_database.uploadQueueItems)..orderBy([
              (row) => OrderingTerm.asc(row.position),
              (row) => OrderingTerm.asc(row.id),
            ]))
            .get();
    return rows.map(_toItem).toList(growable: false);
  }

  Future<List<QueueItem>> listByState(QueueState state) async {
    final rows =
        await (_database.select(_database.uploadQueueItems)
              ..where((row) => row.state.equals(state.code))
              ..orderBy([
                (row) => OrderingTerm.asc(row.position),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    return rows.map(_toItem).toList(growable: false);
  }

  Future<QueueItem> add({
    required String destinationId,
    required String destinationName,
    required PickedMedia media,
  }) async {
    final nextPosition = await _nextPosition();
    final id = await _database
        .into(_database.uploadQueueItems)
        .insert(
          UploadQueueItemsCompanion.insert(
            destinationId: destinationId,
            destinationName: destinationName,
            sourcePath: media.path,
            fileName: media.name,
            sizeBytes: media.sizeBytes,
            mimeType: Value(media.mimeType),
            kind: media.kind.name,
            state: QueueState.pending.code,
            createdAt: DateTime.now(),
            position: Value(nextPosition),
          ),
        );
    final row = await (_database.select(
      _database.uploadQueueItems,
    )..where((entry) => entry.id.equals(id))).getSingle();
    return _toItem(row);
  }

  Future<void> updateState(
    int id,
    QueueState state, {
    double? progress,
    String? errorCode,
    String? errorMessage,
  }) async {
    final now = DateTime.now();
    await (_database.update(
      _database.uploadQueueItems,
    )..where((row) => row.id.equals(id))).write(
      UploadQueueItemsCompanion(
        state: Value(state.code),
        progress: progress == null
            ? const Value<double>.absent()
            : Value(progress),
        errorCode: Value(errorCode),
        errorMessage: Value(errorMessage),
        startedAt: state == QueueState.uploading
            ? Value(now)
            : const Value.absent(),
        finishedAt: state.isFinal ? Value(now) : const Value.absent(),
      ),
    );
  }

  Future<void> updateProgress(int id, double progress) async {
    await (_database.update(_database.uploadQueueItems)
          ..where((row) => row.id.equals(id)))
        .write(UploadQueueItemsCompanion(progress: Value(progress)));
  }

  Future<void> remove(int id) async {
    await (_database.delete(
      _database.uploadQueueItems,
    )..where((row) => row.id.equals(id))).go();
  }

  Future<void> removeMany(Iterable<int> ids) async {
    final idList = ids.toList(growable: false);
    if (idList.isEmpty) {
      return;
    }
    await (_database.delete(
      _database.uploadQueueItems,
    )..where((row) => row.id.isIn(idList))).go();
  }

  /// Removes every item that reached a final state.
  Future<void> clearCompleted() async {
    await (_database.delete(_database.uploadQueueItems)..where(
          (row) => row.state.isIn(<String>['completed', 'failed', 'cancelled']),
        ))
        .go();
  }

  /// Writes the new order of the queue.
  Future<void> reorder(List<int> orderedIds) async {
    for (var index = 0; index < orderedIds.length; index += 1) {
      await (_database.update(_database.uploadQueueItems)
            ..where((row) => row.id.equals(orderedIds[index])))
          .write(UploadQueueItemsCompanion(position: Value(index)));
    }
  }

  Future<void> markInterrupted() => _database.markInterruptedUploads();

  Future<void> markMissingSources(bool Function(String path) exists) =>
      _database.markMissingSources(exists);

  Future<int> _nextPosition() async {
    final row = await _database
        .customSelect(
          'SELECT COALESCE(MAX(position), -1) AS max_position FROM upload_queue_items',
        )
        .getSingle();
    final value = row.data['max_position'];
    if (value is int) {
      return value + 1;
    }
    return 0;
  }

  static QueueItem _toItem(UploadQueueItem row) {
    return QueueItem(
      id: row.id,
      destinationId: row.destinationId,
      destinationName: row.destinationName,
      sourcePath: row.sourcePath,
      fileName: row.fileName,
      sizeBytes: row.sizeBytes,
      mimeType: row.mimeType,
      kind: row.kind,
      state: QueueState.fromCode(row.state),
      progress: row.progress,
      createdAt: row.createdAt,
      startedAt: row.startedAt,
      finishedAt: row.finishedAt,
      errorCode: row.errorCode,
      errorMessage: row.errorMessage,
      position: row.position,
    );
  }
}
