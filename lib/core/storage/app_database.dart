import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: <Type>[
    UploadQueueItems,
    UploadHistoryEntries,
    MediaDestinations,
    SettingEntries,
    FavoriteGuilds,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Used by the tests, which run against an in memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// After a restart an upload that was still running may actually have
  /// completed on the server, so it becomes interrupted and the user decides.
  Future<void> markInterruptedUploads() async {
    await (update(
      uploadQueueItems,
    )..where((row) => row.state.isIn(<String>['uploading', 'paused']))).write(
      const UploadQueueItemsCompanion(state: Value<String>('interrupted')),
    );
  }

  /// Files whose cached copy disappeared become source missing.
  Future<void> markMissingSources(bool Function(String path) exists) async {
    final rows = await select(uploadQueueItems).get();
    for (final row in rows) {
      if (row.state == 'completed' ||
          row.state == 'failed' ||
          row.state == 'cancelled') {
        continue;
      }
      if (!exists(row.sourcePath)) {
        await (update(
          uploadQueueItems,
        )..where((r) => r.id.equals(row.id))).write(
          const UploadQueueItemsCompanion(
            state: Value<String>('source_missing'),
            errorCode: Value<String>('source_missing'),
            errorMessage: Value<String>(
              'The selected file is no longer available on this device.',
            ),
          ),
        );
      }
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, 'discord_server_manager.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
