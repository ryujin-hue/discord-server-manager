import 'package:dio/dio.dart';
import 'package:discord_server_manager/core/network/discord_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_adapter.dart';

void main() {
  test('a page of 200 guilds triggers a second request', () async {
    var call = 0;
    final adapter = MockAdapter((RequestOptions options) async {
      call += 1;
      final after = options.queryParameters['after'];
      if (after == null) {
        return jsonResponse(
          List<Object?>.generate(
            200,
            (int index) => <Object?, Object?>{
              'id': 'guild-$index',
              'name': 'Guild $index',
              'owner': index == 199,
              'permissions': '8',
            },
          ),
        );
      }
      return jsonResponse(<Object?>[
        <Object?, Object?>{
          'id': 'guild-200',
          'name': 'Guild 200',
          'owner': true,
          'permissions': '8',
        },
      ]);
    });

    final dio = Dio(BaseOptions(baseUrl: 'https://discord.com/api/v10'));
    dio.httpClientAdapter = adapter;

    final guilds = await DiscordApi(dio).listGuilds();

    expect(guilds.length, 201);
    expect(call, 2);
    expect(adapter.requests[1].queryParameters['after'], 'guild-199');
    expect(adapter.requests[0].queryParameters['limit'], 200);
    expect(adapter.requests[0].queryParameters['with_counts'], true);
  });

  test('a short page ends the pagination', () async {
    var call = 0;
    final adapter = MockAdapter((RequestOptions options) async {
      call += 1;
      return jsonResponse(<Object?>[
        <Object?, Object?>{
          'id': 'guild-1',
          'name': 'Guild 1',
          'owner': true,
          'permissions': '8',
        },
      ]);
    });

    final dio = Dio(BaseOptions(baseUrl: 'https://discord.com/api/v10'))
      ..httpClientAdapter = adapter;

    final guilds = await DiscordApi(dio).listGuilds();

    expect(guilds.length, 1);
    expect(call, 1);
  });

  test('reads the current user', () async {
    final adapter = MockAdapter((RequestOptions options) async {
      return jsonResponse(<Object?, Object?>{
        'id': 'user-1',
        'username': 'ada',
        'global_name': 'Ada',
        'avatar': 'a_hash',
      });
    });

    final dio = Dio(BaseOptions(baseUrl: 'https://discord.com/api/v10'))
      ..httpClientAdapter = adapter;

    final user = await DiscordApi(dio).currentUser();

    expect(user.id, 'user-1');
    expect(user.displayName, 'Ada');
    expect(user.avatarUrl, contains('.gif'));
  });
}
