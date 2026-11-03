import 'package:drift/drift.dart';

import '../../../core/security/secret_store.dart';
import '../../../core/storage/app_database.dart';
import '../domain/destination.dart';

/// Stores the destinations and keeps their secrets in the secure storage.
class DestinationRepository {
  DestinationRepository(this._database, this._secrets);

  final AppDatabase _database;
  final SecretStorage _secrets;

  /// The key under which the secret of a destination is stored.
  static String secretKeyFor(String destinationId) => 'secret.$destinationId';

  Future<List<Destination>> list() async {
    final rows = await _database.select(_database.mediaDestinations).get();
    return rows
        .map(
          (row) => Destination(
            id: row.id,
            name: row.name,
            type: DestinationType.fromCode(row.type),
            active: row.active,
            createdAt: row.createdAt,
            guildId: row.guildId,
            channelId: row.channelId,
          ),
        )
        .toList(growable: false);
  }

  Future<Destination> addWebhook({
    required String id,
    required String name,
    required String url,
  }) async {
    final secretKey = secretKeyFor(id);
    await _secrets.write(secretKey, url);
    final now = DateTime.now();
    await _database
        .into(_database.mediaDestinations)
        .insert(
          MediaDestinationsCompanion.insert(
            id: id,
            name: name,
            type: DestinationType.webhook.code,
            secretKey: secretKey,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return Destination(
      id: id,
      name: name,
      type: DestinationType.webhook,
      active: true,
      createdAt: now,
    );
  }

  Future<Destination> addBot({
    required String id,
    required String name,
    required String token,
    required String guildId,
    required String channelId,
  }) async {
    final secretKey = secretKeyFor(id);
    await _secrets.write(secretKey, token);
    final now = DateTime.now();
    await _database
        .into(_database.mediaDestinations)
        .insert(
          MediaDestinationsCompanion.insert(
            id: id,
            name: name,
            type: DestinationType.bot.code,
            secretKey: secretKey,
            guildId: Value(guildId),
            channelId: Value(channelId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return Destination(
      id: id,
      name: name,
      type: DestinationType.bot,
      active: true,
      createdAt: now,
      guildId: guildId,
      channelId: channelId,
    );
  }

  Future<void> rename(String id, String name) async {
    await (_database.update(
      _database.mediaDestinations,
    )..where((row) => row.id.equals(id))).write(
      MediaDestinationsCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setActive(String id, bool active) async {
    await (_database.update(
      _database.mediaDestinations,
    )..where((row) => row.id.equals(id))).write(
      MediaDestinationsCompanion(
        active: Value(active),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Removes the destination and the secret that belongs to it.
  Future<void> delete(String id) async {
    final row = await (_database.select(
      _database.mediaDestinations,
    )..where((entry) => entry.id.equals(id))).getSingleOrNull();
    await (_database.delete(
      _database.mediaDestinations,
    )..where((entry) => entry.id.equals(id))).go();
    if (row != null) {
      await _secrets.delete(row.secretKey);
    }
  }

  /// The secret of a destination, for example the webhook URL or the bot token.
  Future<String?> secretOf(Destination destination) async {
    final row = await (_database.select(
      _database.mediaDestinations,
    )..where((entry) => entry.id.equals(destination.id))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _secrets.read(row.secretKey);
  }

  /// Replaces the secret of a destination.
  Future<void> replaceSecret(String id, String value) async {
    final row = await (_database.select(
      _database.mediaDestinations,
    )..where((entry) => entry.id.equals(id))).getSingleOrNull();
    if (row == null) {
      return;
    }
    await _secrets.write(row.secretKey, value);
  }
}
