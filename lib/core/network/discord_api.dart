import 'package:dio/dio.dart';

import '../../features/auth/domain/discord_user.dart';
import '../../features/guilds/domain/guild.dart';

/// Calls the Discord API on behalf of the signed in user.
class DiscordApi {
  DiscordApi(this._dio);

  final Dio _dio;

  static const String baseUrl = 'https://discord.com/api/v10';

  /// The page size Discord uses for the guild list.
  static const int guildPageSize = 200;

  Future<DiscordUser> currentUser() async {
    final response = await _dio.get<Object?>('$baseUrl/users/@me');
    return DiscordUser.fromJson(_asMap(response.data));
  }

  /// Lists every server of the user. Discord returns at most 200 servers per
  /// page, so the list is followed with the `after` parameter until a page
  /// returns fewer entries than the page size.
  Future<List<DiscordGuild>> listGuilds() async {
    final guilds = <DiscordGuild>[];
    String? after;

    for (;;) {
      final response = await _dio.get<Object?>(
        '$baseUrl/users/@me/guilds',
        queryParameters: <String, Object?>{
          'with_counts': true,
          'limit': guildPageSize,
          'after': ?after,
        },
      );
      final data = response.data;
      if (data is! List) {
        break;
      }
      final page = data
          .whereType<Map<Object?, Object?>>()
          .map(DiscordGuild.fromJson)
          .toList(growable: false);
      guilds.addAll(page);
      if (page.length < guildPageSize) {
        return guilds;
      }
      final last = page.last;
      after = last.id;
    }

    return guilds;
  }

  static Map<Object?, Object?> _asMap(Object? data) =>
      data is Map ? data : const <Object?, Object?>{};
}
