import '../../../core/utils/discord_permissions.dart';

/// Read model of a server overview.
class ServerOverview {
  const ServerOverview({
    required this.guildId,
    required this.name,
    required this.iconUrl,
    required this.memberCount,
    required this.approximateMemberCount,
    required this.onlineCount,
    required this.channelCount,
    required this.textChannelCount,
    required this.categoryCount,
    required this.voiceChannelCount,
    required this.botPresent,
    required this.verificationLevel,
    required this.verificationLevelName,
    this.gateway = const GatewayStatus(),
  });

  final String guildId;
  final String name;
  final String? iconUrl;
  final int? memberCount;
  final int? approximateMemberCount;
  final int? onlineCount;
  final int channelCount;
  final int textChannelCount;
  final int categoryCount;
  final int voiceChannelCount;
  final bool botPresent;
  final int verificationLevel;
  final String verificationLevelName;
  final GatewayStatus gateway;

  static ServerOverview fromJson(Map<Object?, Object?> json) {
    return ServerOverview(
      guildId: _string(json['guildId']),
      name: _string(json['name'], fallback: 'Server'),
      iconUrl: _nullableString(json['iconUrl']),
      memberCount: _nullableInt(json['memberCount']),
      approximateMemberCount: _nullableInt(json['approximateMemberCount']),
      onlineCount: _nullableInt(json['onlineCount']),
      channelCount: _int(json['channelCount']),
      textChannelCount: _int(json['textChannelCount']),
      categoryCount: _int(json['categoryCount']),
      voiceChannelCount: _int(json['voiceChannelCount']),
      botPresent: json['botPresent'] == true,
      verificationLevel: _int(json['verificationLevel']),
      verificationLevelName: _string(
        json['verificationLevelName'],
        fallback: 'Unknown',
      ),
      gateway: GatewayStatus.fromJson(_map(json['gateway'])),
    );
  }
}

/// Connection state of the backend gateway.
class GatewayStatus {
  const GatewayStatus({this.connected = false, this.error});

  final bool connected;

  /// Machine readable reason, for example `privileged_intent_disabled`.
  final String? error;

  bool get isPrivilegedIntentDisabled => error == 'privileged_intent_disabled';

  static GatewayStatus fromJson(Map<Object?, Object?> json) {
    return GatewayStatus(
      connected: json['connected'] == true,
      error: _nullableString(json['error']),
    );
  }
}

/// The bot and gateway state of a server.
class ServerStatus {
  const ServerStatus({
    required this.botPresent,
    required this.verificationLevel,
    required this.gateway,
  });

  final bool botPresent;
  final int verificationLevel;
  final GatewayStatus gateway;

  static ServerStatus fromJson(Map<Object?, Object?> json) {
    return ServerStatus(
      botPresent: json['botPresent'] == true,
      verificationLevel: _int(json['verificationLevel']),
      gateway: GatewayStatus.fromJson(_map(json['gateway'])),
    );
  }
}

/// A native Discord auto moderation rule.
class AutoModRuleSummary {
  const AutoModRuleSummary({
    required this.id,
    required this.name,
    required this.enabled,
    required this.kind,
    required this.keywords,
    required this.regexPatterns,
    required this.presets,
    required this.allowList,
    this.mentionTotalLimit,
    this.alertChannelId,
  });

  final String id;
  final String name;
  final bool enabled;
  final String kind;
  final List<String> keywords;
  final List<String> regexPatterns;
  final List<String> presets;
  final List<String> allowList;
  final int? mentionTotalLimit;
  final String? alertChannelId;

  static AutoModRuleSummary fromJson(Map<Object?, Object?> json) {
    return AutoModRuleSummary(
      id: _string(json['id']),
      name: _string(json['name']),
      enabled: json['enabled'] != false,
      kind: _string(json['kind'], fallback: 'keyword'),
      keywords: _stringList(json['keywords']),
      regexPatterns: _stringList(json['regexPatterns']),
      presets: _stringList(json['presets']),
      allowList: _stringList(json['allowList']),
      mentionTotalLimit: _nullableInt(json['mentionTotalLimit']),
      alertChannelId: _nullableString(json['alertChannelId']),
    );
  }
}

/// A role of a server.
class ServerRole {
  const ServerRole({
    required this.id,
    required this.name,
    required this.permissions,
    required this.position,
    required this.color,
    required this.hoist,
    required this.mentionable,
  });

  final String id;
  final String name;
  final BigInt permissions;
  final int position;
  final int color;
  final bool hoist;
  final bool mentionable;

  static ServerRole fromJson(Map<Object?, Object?> json) {
    return ServerRole(
      id: _string(json['id']),
      name: _string(json['name'], fallback: 'Role'),
      permissions: PermissionBits.parse(json['permissions']),
      position: _int(json['position']),
      color: _int(json['color']),
      hoist: json['hoist'] == true,
      mentionable: json['mentionable'] == true,
    );
  }
}

/// A member of a server.
class ServerMember {
  const ServerMember({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.roles,
    this.avatarHash,
  });

  final String userId;
  final String username;
  final String displayName;
  final List<String> roles;
  final String? avatarHash;

  static ServerMember fromJson(Map<Object?, Object?> json) {
    final user = _map(json['user']);
    final nick = _nullableString(json['nick']);
    final username = _string(user['username'], fallback: 'Unknown');
    return ServerMember(
      userId: _string(user['id']),
      username: username,
      displayName: nick ?? username,
      roles: _stringList(json['roles']),
      avatarHash: _nullableString(user['avatar']),
    );
  }
}

/// A permission overwrite on a channel.
class PermissionOverwrite {
  const PermissionOverwrite({
    required this.id,
    required this.type,
    required this.allow,
    required this.deny,
  });

  final String id;
  final int type;
  final BigInt allow;
  final BigInt deny;

  static PermissionOverwrite fromJson(Map<Object?, Object?> json) {
    return PermissionOverwrite(
      id: _string(json['id']),
      type: _int(json['type']),
      allow: PermissionBits.parse(json['allow']),
      deny: PermissionBits.parse(json['deny']),
    );
  }
}

/// A channel or category of a server.
class ServerChannel {
  const ServerChannel({
    required this.id,
    required this.type,
    required this.name,
    required this.position,
    required this.overwrites,
    this.parentId,
    this.rateLimitPerUser,
  });

  final String id;

  /// Discord channel type, 0 is text, 2 is voice and 4 is a category.
  final int type;
  final String name;
  final int position;
  final List<PermissionOverwrite> overwrites;
  final String? parentId;
  final int? rateLimitPerUser;

  bool get isCategory => type == 4;
  bool get isText => type == 0;

  static ServerChannel fromJson(Map<Object?, Object?> json) {
    return ServerChannel(
      id: _string(json['id']),
      type: _int(json['type']),
      name: _string(json['name'], fallback: 'Channel'),
      position: _int(json['position']),
      overwrites: _list(json['permission_overwrites'])
          .map(PermissionOverwrite.fromJson)
          .toList(growable: false),
      parentId: _nullableString(json['parent_id']),
      rateLimitPerUser: _nullableInt(json['rate_limit_per_user']),
    );
  }
}

/// A scheduled announcement.
class ScheduledAnnouncement {
  const ScheduledAnnouncement({
    required this.id,
    required this.channelId,
    required this.content,
    required this.scheduledAt,
    required this.status,
    this.sentAt,
    this.error,
  });

  final String id;
  final String channelId;
  final String content;
  final DateTime scheduledAt;
  final String status;
  final DateTime? sentAt;
  final String? error;

  static ScheduledAnnouncement fromJson(Map<Object?, Object?> json) {
    return ScheduledAnnouncement(
      id: _string(json['id']),
      channelId: _string(json['channelId']),
      content: _string(json['content']),
      scheduledAt:
          DateTime.tryParse(_string(json['scheduledAt'])) ?? DateTime.now(),
      status: _string(json['status'], fallback: 'pending'),
      sentAt: _nullableDate(json['sentAt']),
      error: _nullableString(json['error']),
    );
  }
}

/// A server invite with the number of joins it produced.
class InviteSummary {
  const InviteSummary({
    required this.code,
    required this.uses,
    required this.joins,
    this.inviterId,
    this.channelId,
    this.createdAt,
  });

  final String code;
  final int uses;
  final int joins;
  final String? inviterId;
  final String? channelId;
  final DateTime? createdAt;

  static InviteSummary fromJson(Map<Object?, Object?> json) {
    return InviteSummary(
      code: _string(json['code']),
      uses: _int(json['uses']),
      joins: _int(json['joins']),
      inviterId: _nullableString(json['inviterId']),
      channelId: _nullableString(json['channelId']),
      createdAt: _nullableDate(json['createdAt']),
    );
  }
}

/// A join that was attributed to an invite.
class InviteJoin {
  const InviteJoin({
    required this.memberId,
    required this.joinedAt,
    this.inviteCode,
    this.inviterId,
  });

  final String memberId;
  final DateTime joinedAt;
  final String? inviteCode;
  final String? inviterId;

  static InviteJoin fromJson(Map<Object?, Object?> json) {
    return InviteJoin(
      memberId: _string(json['memberId']),
      joinedAt: DateTime.tryParse(_string(json['joinedAt'])) ?? DateTime.now(),
      inviteCode: _nullableString(json['inviteCode']),
      inviterId: _nullableString(json['inviterId']),
    );
  }
}

/// A custom emoji of a server.
class ServerEmoji {
  const ServerEmoji({
    required this.id,
    required this.name,
    required this.animated,
    required this.available,
  });

  final String id;
  final String? name;
  final bool animated;
  final bool available;

  String get displayName => name ?? 'unnamed';

  static ServerEmoji fromJson(Map<Object?, Object?> json) {
    return ServerEmoji(
      id: _string(json['id']),
      name: _nullableString(json['name']),
      animated: json['animated'] == true,
      available: json['available'] != false,
    );
  }
}

/// A sticker of a server.
class ServerSticker {
  const ServerSticker({
    required this.id,
    required this.name,
    required this.description,
    required this.tags,
  });

  final String id;
  final String name;
  final String? description;
  final String tags;

  static ServerSticker fromJson(Map<Object?, Object?> json) {
    return ServerSticker(
      id: _string(json['id']),
      name: _string(json['name']),
      description: _nullableString(json['description']),
      tags: _string(json['tags']),
    );
  }
}

/// One entry of the audit log.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.actionType,
    required this.createdAt,
    this.targetId,
    this.userId,
    this.reason,
  });

  final String id;
  final int actionType;
  final DateTime createdAt;
  final String? targetId;
  final String? userId;
  final String? reason;

  static AuditLogEntry fromJson(Map<Object?, Object?> json) {
    return AuditLogEntry(
      id: _string(json['id']),
      actionType: _int(json['actionType']),
      createdAt:
          DateTime.tryParse(_string(json['createdAt'])) ?? DateTime.now(),
      targetId: _nullableString(json['targetId']),
      userId: _nullableString(json['userId']),
      reason: _nullableString(json['reason']),
    );
  }
}

/// A message of a channel, used to pick the messages that are purged.
class RecentMessage {
  const RecentMessage({
    required this.id,
    required this.timestamp,
    required this.content,
    this.authorId,
    this.authorName,
  });

  final String id;
  final DateTime timestamp;
  final String content;
  final String? authorId;
  final String? authorName;

  /// Discord only deletes messages that are younger than fourteen days.
  bool get isTooOld =>
      DateTime.now().difference(timestamp) > const Duration(days: 14);

  static RecentMessage fromJson(Map<Object?, Object?> json) {
    return RecentMessage(
      id: _string(json['id']),
      timestamp:
          DateTime.tryParse(_string(json['timestamp'])) ?? DateTime.now(),
      content: _string(json['content']),
      authorId: _nullableString(json['authorId']),
      authorName: _nullableString(json['authorName']),
    );
  }
}

/// A warning issued from the app.
class WarningRecord {
  const WarningRecord({
    required this.id,
    required this.userId,
    required this.reason,
    required this.warnedBy,
    required this.createdAt,
  });

  final int id;
  final String userId;
  final String reason;
  final String warnedBy;
  final DateTime createdAt;

  static WarningRecord fromJson(Map<Object?, Object?> json) {
    return WarningRecord(
      id: _int(json['id']),
      userId: _string(json['userId']),
      reason: _string(json['reason']),
      warnedBy: _string(json['warnedBy']),
      createdAt:
          DateTime.tryParse(_string(json['createdAt'])) ?? DateTime.now(),
    );
  }
}

/// One collected insight point.
class InsightPoint {
  const InsightPoint({
    required this.day,
    required this.memberCount,
    required this.onlineCount,
    required this.channelCount,
  });

  final String day;
  final int memberCount;
  final int onlineCount;
  final int channelCount;

  static InsightPoint fromJson(Map<Object?, Object?> json) {
    return InsightPoint(
      day: _string(json['day']),
      memberCount: _int(json['memberCount']),
      onlineCount: _int(json['onlineCount']),
      channelCount: _int(json['channelCount']),
    );
  }
}

/// The per server settings that the gateway features read.
class ServerSettings {
  const ServerSettings({
    required this.welcomeEnabled,
    required this.welcomeChannelId,
    required this.welcomeMessage,
    required this.goodbyeEnabled,
    required this.goodbyeChannelId,
    required this.goodbyeMessage,
    required this.autoRoleIds,
    required this.moderationLogChannelId,
    required this.autoTimeoutThreshold,
    required this.autoTimeoutDurationSeconds,
    required this.lockedChannelIds,
  });

  final bool welcomeEnabled;
  final String? welcomeChannelId;
  final String welcomeMessage;
  final bool goodbyeEnabled;
  final String? goodbyeChannelId;
  final String goodbyeMessage;
  final List<String> autoRoleIds;
  final String? moderationLogChannelId;
  final int? autoTimeoutThreshold;
  final int? autoTimeoutDurationSeconds;
  final List<String> lockedChannelIds;

  static ServerSettings fromJson(Map<Object?, Object?> json) {
    return ServerSettings(
      welcomeEnabled: json['welcomeEnabled'] == true,
      welcomeChannelId: _nullableString(json['welcomeChannelId']),
      welcomeMessage: _string(
        json['welcomeMessage'],
        fallback: 'Welcome {user} to {server}!',
      ),
      goodbyeEnabled: json['goodbyeEnabled'] == true,
      goodbyeChannelId: _nullableString(json['goodbyeChannelId']),
      goodbyeMessage: _string(
        json['goodbyeMessage'],
        fallback: '{user} left {server}.',
      ),
      autoRoleIds: _stringList(json['autoRoleIds']),
      moderationLogChannelId: _nullableString(json['moderationLogChannelId']),
      autoTimeoutThreshold: _nullableInt(json['autoTimeoutThreshold']),
      autoTimeoutDurationSeconds: _nullableInt(
        json['autoTimeoutDurationSeconds'],
      ),
      lockedChannelIds: _stringList(json['lockedChannelIds']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int _int(Object? value) => value is int ? value : 0;

int? _nullableInt(Object? value) => value is int ? value : null;

DateTime? _nullableDate(Object? value) {
  if (value is! String) {
    return null;
  }
  return DateTime.tryParse(value);
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.whereType<String>().toList(growable: false);
}

Map<Object?, Object?> _map(Object? value) =>
    value is Map ? value : const <Object?, Object?>{};

List<Map<Object?, Object?>> _list(Object? value) {
  if (value is! List) {
    return const <Map<Object?, Object?>>[];
  }
  return value.whereType<Map<Object?, Object?>>().toList(growable: false);
}
