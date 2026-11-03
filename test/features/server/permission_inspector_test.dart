import 'package:discord_server_manager/core/utils/discord_permissions.dart';
import 'package:discord_server_manager/features/server/domain/models.dart';
import 'package:discord_server_manager/features/server/domain/permission_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('permission inspector', () {
    test(
      'the base permissions come from the role of everyone and the member',
      () {
        final result = inspectMemberPermissions(
          memberId: 'user-1',
          channelId: 'channel-1',
          everyoneRolePermissions: PermissionBits.viewChannel,
          memberRolePermissions: <BigInt>[PermissionBits.sendMessages],
          memberRoleIds: const <String>['role-1'],
          overwrites: const <PermissionOverwrite>[],
        );

        expect(result.canViewChannel, isTrue);
        expect(result.canSendMessages, isTrue);
        expect(result.canManageMessages, isFalse);
      },
    );

    test('an administrator holds every permission', () {
      final result = inspectMemberPermissions(
        memberId: 'user-1',
        channelId: 'channel-1',
        everyoneRolePermissions: PermissionBits.administrator,
        memberRolePermissions: const <BigInt>[],
        memberRoleIds: const <String>[],
        overwrites: <PermissionOverwrite>[
          PermissionOverwrite(
            id: 'user-1',
            type: 1,
            allow: BigInt.zero,
            deny: PermissionBits.sendMessages,
          ),
        ],
      );

      expect(result.isAdministrator, isTrue);
      expect(result.canSendMessages, isTrue);
      expect(result.permissions, allPermissions);
    });

    test('the overwrite of everyone denies before it allows', () {
      final result = inspectMemberPermissions(
        memberId: 'user-1',
        channelId: 'channel-1',
        everyoneRolePermissions:
            PermissionBits.sendMessages | PermissionBits.viewChannel,
        memberRolePermissions: const <BigInt>[],
        memberRoleIds: const <String>[],
        overwrites: <PermissionOverwrite>[
          PermissionOverwrite(
            id: '@everyone',
            type: 0,
            allow: PermissionBits.viewChannel,
            deny: PermissionBits.sendMessages,
          ),
        ],
      );

      expect(result.canSendMessages, isFalse);
      expect(result.canViewChannel, isTrue);
    });

    test('the overwrite of the member has the last word', () {
      final result = inspectMemberPermissions(
        memberId: 'user-1',
        channelId: 'channel-1',
        everyoneRolePermissions: BigInt.zero,
        memberRolePermissions: const <BigInt>[],
        memberRoleIds: const <String>[],
        overwrites: <PermissionOverwrite>[
          PermissionOverwrite(
            id: 'user-1',
            type: 1,
            allow: PermissionBits.sendMessages,
            deny: BigInt.zero,
          ),
        ],
      );

      expect(result.canSendMessages, isTrue);
    });

    test(
      'a role overwrite is only applied with the manage roles permission',
      () {
        final overwrite = PermissionOverwrite(
          id: 'role-1',
          type: 0,
          allow: BigInt.zero,
          deny: PermissionBits.sendMessages,
        );

        final withoutManageRoles = inspectMemberPermissions(
          memberId: 'user-1',
          channelId: 'channel-1',
          everyoneRolePermissions:
              PermissionBits.viewChannel | PermissionBits.sendMessages,
          memberRolePermissions: const <BigInt>[],
          memberRoleIds: const <String>['role-1'],
          overwrites: <PermissionOverwrite>[overwrite],
        );
        expect(withoutManageRoles.canSendMessages, isTrue);

        final withManageRoles = inspectMemberPermissions(
          memberId: 'user-1',
          channelId: 'channel-1',
          everyoneRolePermissions:
              PermissionBits.viewChannel |
              PermissionBits.sendMessages |
              PermissionBits.manageRoles,
          memberRolePermissions: const <BigInt>[],
          memberRoleIds: const <String>['role-1'],
          overwrites: <PermissionOverwrite>[overwrite],
        );
        expect(withManageRoles.canSendMessages, isFalse);
      },
    );

    test('the result carries the member and the channel', () {
      final result = inspectMemberPermissions(
        memberId: 'user-7',
        channelId: 'channel-9',
        everyoneRolePermissions: BigInt.zero,
        memberRolePermissions: const <BigInt>[],
        memberRoleIds: const <String>[],
        overwrites: const <PermissionOverwrite>[],
      );
      expect(result.memberId, 'user-7');
      expect(result.channelId, 'channel-9');
    });
  });
}
