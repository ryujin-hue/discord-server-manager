import '../../../core/storage/app_database.dart';
import '../domain/app_settings.dart';

/// Reads and writes the user settings in the local database.
class SettingsRepository {
  SettingsRepository(this._database);

  final AppDatabase _database;

  Future<AppSettings> load() async {
    final rows = await _database.select(_database.settingEntries).get();
    final values = <String, String>{for (final row in rows) row.key: row.value};
    return AppSettings.fromStorage(values);
  }

  Future<void> save(AppSettings settings) async {
    final values = settings.toStorage();
    await _database.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _database.settingEntries,
        values.entries
            .map(
              (entry) => SettingEntriesCompanion.insert(
                key: entry.key,
                value: entry.value,
              ),
            )
            .toList(growable: false),
      );
    });
  }

  /// Removes every setting so the app falls back to the defaults.
  Future<void> reset() async {
    await _database.delete(_database.settingEntries).go();
  }
}
