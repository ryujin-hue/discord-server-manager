import 'package:discord_server_manager/core/utils/discord_permissions.dart';
import 'package:discord_server_manager/features/guilds/domain/guild.dart';
import 'package:flutter_test/flutter_test.dart';

DiscordGuild buildGuild({
  String id = 'guild-1',
  bool owner = false,
  String permissions = '0',
}) {
  return DiscordGuild(
    id: id,
    name: 'Guild $id',
    owner: owner,
    permissions: PermissionBits.parse(permissions),
  );
}

void main() {
  group('permission filter', () {
    test('keeps a guild the user owns', () {
      final kept = filterAdministeredGuilds(<DiscordGuild>[
        buildGuild(id: 'owned', owner: true),
      ]);
      expect(kept.map((DiscordGuild g) => g.id), <String>['owned']);
    });

    test('keeps a guild with the administrator permission', () {
      final kept = filterAdministeredGuilds(<DiscordGuild>[
        buildGuild(id: 'admin', permissions: '8'),
      ]);
      expect(kept.map((DiscordGuild g) => g.id), <String>['admin']);
    });

    test('keeps a guild with the manage guild permission', () {
      final kept = filterAdministeredGuilds(<DiscordGuild>[
        buildGuild(id: 'manager', permissions: '32'),
      ]);
      expect(kept.map((DiscordGuild g) => g.id), <String>['manager']);
    });

    test('drops a guild without any administration permission', () {
      final kept = filterAdministeredGuilds(<DiscordGuild>[
        buildGuild(id: 'member', permissions: '1024'),
        buildGuild(id: 'moderator', permissions: '2052'),
      ]);
      expect(kept, isEmpty);
    });

    test('parses the permission string as a big integer', () {
      final guild = buildGuild(permissions: '1099511627776');
      expect(guild.permissions, PermissionBits.moderateMembers);
      expect(guild.canAdminister, isFalse);
    });

    test('reads the guilds from the Discord payload', () {
      final guild = DiscordGuild.fromJson(<Object?, Object?>{
        'id': '123',
        'name': 'Test',
        'owner': false,
        'permissions': '32',
        'icon': 'abc',
        'approximate_member_count': 42,
      });
      expect(guild.id, '123');
      expect(guild.name, 'Test');
      expect(guild.owner, isFalse);
      expect(guild.permissions, PermissionBits.manageGuild);
      expect(guild.memberCount, 42);
      expect(guild.iconUrl, isNotNull);
    });

    test('falls back to the initials when there is no icon', () {
      final guild = buildGuild(id: 'guild-1');
      expect(guild.iconUrl, isNull);
      expect(guild.initials, 'GG');
    });
  });

  group('bot permissions', () {
    test('never contains the administrator permission', () {
      expect(
        BotPermissions.integer & PermissionBits.administrator,
        BigInt.zero,
      );
    });

    test('contains every permission the features need', () {
      final required = <BigInt>[
        PermissionBits.createInstantInvite,
        PermissionBits.kickMembers,
        PermissionBits.banMembers,
        PermissionBits.manageChannels,
        PermissionBits.manageGuild,
        PermissionBits.addReactions,
        PermissionBits.viewAuditLog,
        PermissionBits.viewChannel,
        PermissionBits.sendMessages,
        PermissionBits.manageMessages,
        PermissionBits.readMessageHistory,
        PermissionBits.manageRoles,
        PermissionBits.manageGuildExpressions,
        PermissionBits.useApplicationCommands,
        PermissionBits.moderateMembers,
      ];
      for (final permission in required) {
        expect(
          BotPermissions.integer & permission,
          permission,
          reason: 'the permission $permission is missing',
        );
      }
    });

    test('documents every bit it grants', () {
      expect(BotPermissions.reasons.keys.toSet(), BotPermissions.names.toSet());
    });
  });
}
