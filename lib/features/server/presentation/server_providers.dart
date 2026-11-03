import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/server_repository.dart';
import '../domain/models.dart';

/// The repository that calls the backend for every server operation.
final serverRepositoryProvider = Provider<ServerRepository>(
  (ref) => ServerRepository(ref.watch(backendApiProvider)),
);

/// The bot and gateway state of one server.
final serverStatusProvider = FutureProvider.family<ServerStatus, String>(
  (ref, guildId) => ref.watch(serverRepositoryProvider).status(guildId),
);

/// The overview of one server.
final serverOverviewProvider = FutureProvider.family<ServerOverview, String>(
  (ref, guildId) => ref.watch(serverRepositoryProvider).overview(guildId),
);

/// The channels of one server.
final serverChannelsProvider =
    FutureProvider.family<List<ServerChannel>, String>(
      (ref, guildId) => ref.watch(serverRepositoryProvider).channels(guildId),
    );

/// The roles of one server.
final serverRolesProvider = FutureProvider.family<List<ServerRole>, String>(
  (ref, guildId) => ref.watch(serverRepositoryProvider).roles(guildId),
);

/// The members of one server.
final serverMembersProvider = FutureProvider.family<List<ServerMember>, String>(
  (ref, guildId) => ref.watch(serverRepositoryProvider).members(guildId),
);

/// The recent messages of a channel.
final recentMessagesProvider =
    FutureProvider.family<
      List<RecentMessage>,
      ({String guildId, String channelId})
    >(
      (ref, key) => ref
          .watch(serverRepositoryProvider)
          .recentMessages(key.guildId, channelId: key.channelId),
    );

/// The settings of one server.
final serverSettingsProvider = FutureProvider.family<ServerSettings, String>(
  (ref, guildId) => ref.watch(serverRepositoryProvider).settings(guildId),
);

/// The insights collected for one server.
final serverInsightsProvider =
    FutureProvider.family<List<InsightPoint>, String>(
      (ref, guildId) => ref.watch(serverRepositoryProvider).insights(guildId),
    );

/// The server that is currently open. The tabs read it to know which server
/// they belong to.
class CurrentGuildId extends Notifier<String> {
  @override
  String build() => '';

  void set(String guildId) => state = guildId;
}

final currentGuildIdProvider = NotifierProvider<CurrentGuildId, String>(
  CurrentGuildId.new,
);
