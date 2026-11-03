import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';

/// Keeps the servers the user pinned to the top of the list.
class FavoritesRepository {
  FavoritesRepository(this._database);

  final AppDatabase _database;

  Future<List<String>> list() async {
    final rows = await (_database.select(
      _database.favoriteGuilds,
    )..orderBy([(row) => OrderingTerm.desc(row.pinnedAt)])).get();
    return rows.map((row) => row.guildId).toList(growable: false);
  }

  Stream<List<String>> watch() {
    return (_database.select(_database.favoriteGuilds)
          ..orderBy([(row) => OrderingTerm.desc(row.pinnedAt)]))
        .watch()
        .map((rows) => rows.map((row) => row.guildId).toList(growable: false));
  }

  Future<void> add(String guildId) async {
    await _database
        .into(_database.favoriteGuilds)
        .insert(
          FavoriteGuildsCompanion.insert(
            guildId: guildId,
            pinnedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> remove(String guildId) async {
    await (_database.delete(
      _database.favoriteGuilds,
    )..where((row) => row.guildId.equals(guildId))).go();
  }
}
