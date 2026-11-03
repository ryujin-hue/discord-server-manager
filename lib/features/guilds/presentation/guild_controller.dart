import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/favorites_repository.dart';
import '../domain/guild.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(databaseProvider)),
);

/// The pinned servers, newest pin first.
final favoriteGuildsProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(favoritesRepositoryProvider).watch(),
);

/// The servers the user administers.
class GuildsController extends AsyncNotifier<List<DiscordGuild>> {
  @override
  Future<List<DiscordGuild>> build() async {
    final guilds = await ref.watch(discordApiProvider).listGuilds();
    return filterAdministeredGuilds(guilds);
  }

  /// Reloads the list, for example after a pull to refresh.
  Future<void> reload() async {
    state = const AsyncValue<List<DiscordGuild>>.loading();
    state = await AsyncValue.guard(() async {
      final guilds = await ref.read(discordApiProvider).listGuilds();
      return filterAdministeredGuilds(guilds);
    });
  }

  Future<void> toggleFavorite(String guildId) async {
    final repository = ref.read(favoritesRepositoryProvider);
    final favorites = await repository.list();
    if (favorites.contains(guildId)) {
      await repository.remove(guildId);
    } else {
      await repository.add(guildId);
    }
  }
}

final guildsControllerProvider =
    AsyncNotifierProvider<GuildsController, List<DiscordGuild>>(
      GuildsController.new,
    );

/// The search term of the server list.
class GuildSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final guildSearchQueryProvider = NotifierProvider<GuildSearchQuery, String>(
  GuildSearchQuery.new,
);
