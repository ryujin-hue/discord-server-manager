import '../../../core/utils/discord_permissions.dart';
import 'models.dart';

/// The result of the permission inspection of one member in one channel.
class EffectivePermissions {
  const EffectivePermissions({
    required this.memberId,
    required this.channelId,
    required this.permissions,
    required this.isAdministrator,
  });

  final String memberId;
  final String channelId;
  final BigInt permissions;

  /// True when the member holds the administrator permission, in which case
  /// every permission is granted regardless of overwrites.
  final bool isAdministrator;

  bool has(BigInt permission) => PermissionBits.has(permissions, permission);

  bool get canSendMessages => has(PermissionBits.sendMessages);
  bool get canManageMessages => has(PermissionBits.manageMessages);
  bool get canManageChannels => has(PermissionBits.manageChannels);
  bool get canManageRoles => has(PermissionBits.manageRoles);
  bool get canKickMembers => has(PermissionBits.kickMembers);
  bool get canBanMembers => has(PermissionBits.banMembers);
  bool get canModerateMembers => has(PermissionBits.moderateMembers);
  bool get canViewChannel => has(PermissionBits.viewChannel);
  bool get canReadHistory => has(PermissionBits.readMessageHistory);
  bool get canManageGuild => has(PermissionBits.manageGuild);
  bool get canAddReactions => has(PermissionBits.addReactions);
  bool get canViewAuditLog => has(PermissionBits.viewAuditLog);
}

/// Computes the permissions a member holds in a channel.
///
/// The algorithm follows the order Discord applies: the base permissions come
/// from the @everyone role and the roles of the member, then the @everyone
/// overwrite, then the overwrites of the roles of the member and finally the
/// overwrite of the member itself. Every overwrite removes the denied bits
/// before it grants the allowed bits.
EffectivePermissions inspectMemberPermissions({
  required String memberId,
  required String channelId,
  required BigInt everyoneRolePermissions,
  required List<BigInt> memberRolePermissions,
  required List<String> memberRoleIds,
  required List<PermissionOverwrite> overwrites,
  String everyoneRoleId = '@everyone',
}) {
  final base = _basePermissions(everyoneRolePermissions, memberRolePermissions);

  if (PermissionBits.has(base, PermissionBits.administrator)) {
    return EffectivePermissions(
      memberId: memberId,
      channelId: channelId,
      permissions: allPermissions,
      isAdministrator: true,
    );
  }

  var permissions = base;

  final everyoneOverwrite = _overwriteFor(overwrites, everyoneRoleId);
  if (everyoneOverwrite != null) {
    permissions = _apply(permissions, everyoneOverwrite);
  }

  if (PermissionBits.has(permissions, PermissionBits.manageRoles)) {
    for (final roleId in memberRoleIds) {
      final overwrite = _overwriteFor(overwrites, roleId);
      if (overwrite != null) {
        permissions = _apply(permissions, overwrite);
      }
    }
  }

  final memberOverwrite = _overwriteFor(overwrites, memberId);
  if (memberOverwrite != null) {
    permissions = _apply(permissions, memberOverwrite);
  }

  return EffectivePermissions(
    memberId: memberId,
    channelId: channelId,
    permissions: permissions,
    isAdministrator: false,
  );
}

BigInt _basePermissions(
  BigInt everyoneRolePermissions,
  List<BigInt> memberRolePermissions,
) {
  var base = everyoneRolePermissions;
  for (final rolePermissions in memberRolePermissions) {
    base |= rolePermissions;
  }
  return base;
}

BigInt _apply(BigInt permissions, PermissionOverwrite overwrite) {
  final withoutDenied = permissions & ~overwrite.deny;
  return withoutDenied | overwrite.allow;
}

PermissionOverwrite? _overwriteFor(
  List<PermissionOverwrite> overwrites,
  String targetId,
) {
  for (final overwrite in overwrites) {
    if (overwrite.id == targetId) {
      return overwrite;
    }
  }
  return null;
}

/// Every permission bit this app knows about.
final BigInt allPermissions = _allPermissions();

BigInt _allPermissions() {
  final bits = <BigInt>[
    PermissionBits.createInstantInvite,
    PermissionBits.kickMembers,
    PermissionBits.banMembers,
    PermissionBits.administrator,
    PermissionBits.manageChannels,
    PermissionBits.manageGuild,
    PermissionBits.addReactions,
    PermissionBits.viewAuditLog,
    PermissionBits.prioritySpeaker,
    PermissionBits.stream,
    PermissionBits.viewChannel,
    PermissionBits.sendMessages,
    PermissionBits.sendTtsMessages,
    PermissionBits.manageMessages,
    PermissionBits.embedLinks,
    PermissionBits.attachFiles,
    PermissionBits.readMessageHistory,
    PermissionBits.mentionEveryone,
    PermissionBits.useExternalEmojis,
    PermissionBits.viewGuildInsights,
    PermissionBits.connect,
    PermissionBits.speak,
    PermissionBits.muteMembers,
    PermissionBits.deafenMembers,
    PermissionBits.moveMembers,
    PermissionBits.useVad,
    PermissionBits.changeNickname,
    PermissionBits.manageNicknames,
    PermissionBits.manageRoles,
    PermissionBits.manageWebhooks,
    PermissionBits.manageGuildExpressions,
    PermissionBits.useApplicationCommands,
    PermissionBits.requestToSpeak,
    PermissionBits.manageEvents,
    PermissionBits.manageThreads,
    PermissionBits.createPublicThreads,
    PermissionBits.createPrivateThreads,
    PermissionBits.useExternalStickers,
    PermissionBits.sendMessagesInThreads,
    PermissionBits.useEmbeddedActivities,
    PermissionBits.moderateMembers,
    PermissionBits.viewCreatorMonetizationAnalytics,
    PermissionBits.useSoundboard,
    PermissionBits.createGuildExpressions,
    PermissionBits.createEvents,
    PermissionBits.useExternalSounds,
    PermissionBits.sendVoiceMessages,
    PermissionBits.sendPolls,
    PermissionBits.useExternalApps,
  ];
  return bits.fold<BigInt>(BigInt.zero, (total, bit) => total | bit);
}
