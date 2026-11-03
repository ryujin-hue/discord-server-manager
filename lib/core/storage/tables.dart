import 'package:drift/drift.dart';

/// The upload queue. Rows survive a restart so an interrupted upload can be
/// detected and the user can decide what to do with it.
class UploadQueueItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get destinationId => text()();
  TextColumn get destinationName => text()();
  TextColumn get sourcePath => text()();
  TextColumn get fileName => text()();
  IntColumn get sizeBytes => integer()();
  TextColumn get mimeType => text().nullable()();
  TextColumn get kind => text()();
  TextColumn get state => text()();
  RealColumn get progress => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

/// One row per finished upload.
class UploadHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fileName => text()();
  TextColumn get destinationName => text()();
  TextColumn get destinationType => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get sizeBytes => integer()();
  TextColumn get status => text()();
  TextColumn get errorText => text().nullable()();
}

/// A webhook or bot destination. The secret itself lives in the secure
/// storage, only the key that points to it is stored here.
class MediaDestinations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get secretKey => text()();
  TextColumn get guildId => text().nullable()();
  TextColumn get channelId => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Key value store for the user settings.
class SettingEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Servers the user pinned to the top of the server list.
class FavoriteGuilds extends Table {
  TextColumn get guildId => text()();
  DateTimeColumn get pinnedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {guildId};
}
