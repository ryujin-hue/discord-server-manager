import '../../../core/network/backend_api.dart';
import '../domain/models.dart';

/// Calls the backend for every server operation. The backend executes the
/// actions with its own bot token, the user token only proves the right to
/// administer the server.
class ServerRepository {
  ServerRepository(this._api);

  final BackendApi _api;

  Future<ServerOverview> overview(String guildId) async {
    final data = await _api.getMap('/guilds/$guildId/overview');
    return ServerOverview.fromJson(data);
  }

  Future<ServerStatus> status(String guildId) async {
    final data = await _api.getMap('/guilds/$guildId/status');
    return ServerStatus.fromJson(data);
  }

  Future<void> setVerificationLevel(String guildId, int level) async {
    await _api.putMap(
      '/guilds/$guildId/verification',
      body: <String, Object?>{'level': level},
    );
  }

  Future<List<InsightPoint>> insights(String guildId) async {
    final data = await _api.getMap('/guilds/$guildId/insights');
    final points = data['points'];
    if (points is! List) {
      return const <InsightPoint>[];
    }
    return points
        .whereType<Map<Object?, Object?>>()
        .map(InsightPoint.fromJson)
        .toList(growable: false);
  }

  Future<void> ban(
    String guildId, {
    required String userId,
    String? reason,
    int deleteMessageSeconds = 0,
  }) async {
    final reasonText = _reason(reason);
    await _api.postMap(
      '/guilds/$guildId/moderation/ban',
      body: <String, Object?>{
        'userId': userId,
        'confirm': true,
        'deleteMessageSeconds': deleteMessageSeconds,
        'reason': ?reasonText,
      },
    );
  }

  Future<void> unban(String guildId, {required String userId}) async {
    await _api.postMap(
      '/guilds/$guildId/moderation/unban',
      body: <String, Object?>{'userId': userId},
    );
  }

  Future<void> kick(
    String guildId, {
    required String userId,
    String? reason,
  }) async {
    final reasonText = _reason(reason);
    await _api.postMap(
      '/guilds/$guildId/moderation/kick',
      body: <String, Object?>{
        'userId': userId,
        'confirm': true,
        'reason': ?reasonText,
      },
    );
  }

  Future<void> timeout(
    String guildId, {
    required String userId,
    required int durationSeconds,
    String? reason,
  }) async {
    final reasonText = _reason(reason);
    await _api.postMap(
      '/guilds/$guildId/moderation/timeout',
      body: <String, Object?>{
        'userId': userId,
        'durationSeconds': durationSeconds,
        'confirm': true,
        'reason': ?reasonText,
      },
    );
  }

  Future<void> clearTimeout(String guildId, {required String userId}) async {
    await _api.postMap(
      '/guilds/$guildId/moderation/clear-timeout',
      body: <String, Object?>{'userId': userId},
    );
  }

  Future<void> purge(
    String guildId, {
    required String channelId,
    required List<String> messageIds,
  }) async {
    await _api.postMap(
      '/guilds/$guildId/moderation/purge',
      body: <String, Object?>{
        'channelId': channelId,
        'messageIds': messageIds,
        'confirm': true,
      },
    );
  }

  Future<void> lockChannels(String guildId, List<String> channelIds) async {
    await _api.postMap(
      '/guilds/$guildId/moderation/lockdown',
      body: <String, Object?>{'channelIds': channelIds, 'confirm': true},
    );
  }

  Future<void> unlockChannels(String guildId, List<String> channelIds) async {
    await _api.postMap(
      '/guilds/$guildId/moderation/unlock',
      body: <String, Object?>{'channelIds': channelIds, 'confirm': true},
    );
  }

  Future<void> setSlowmode(
    String guildId, {
    required String channelId,
    required int seconds,
  }) async {
    await _api.postMap(
      '/guilds/$guildId/moderation/slowmode',
      body: <String, Object?>{'channelId': channelId, 'seconds': seconds},
    );
  }

  Future<void> setMassSlowmode(String guildId, int seconds) async {
    await _api.postMap(
      '/guilds/$guildId/moderation/mass-slowmode',
      body: <String, Object?>{'seconds': seconds},
    );
  }

  Future<List<WarningRecord>> warnings(String guildId) async {
    final data = await _api.getMap('/guilds/$guildId/moderation/warnings');
    final warnings = data['warnings'];
    if (warnings is! List) {
      return const <WarningRecord>[];
    }
    return warnings
        .whereType<Map<Object?, Object?>>()
        .map(WarningRecord.fromJson)
        .toList(growable: false);
  }

  Future<void> issueWarning(
    String guildId, {
    required String userId,
    required String reason,
    bool autoTimeout = false,
  }) async {
    await _api.postMap(
      '/guilds/$guildId/moderation/warnings',
      body: <String, Object?>{
        'userId': userId,
        'reason': reason,
        'autoTimeout': autoTimeout,
      },
    );
  }

  Future<List<AutoModRuleSummary>> autoModRules(String guildId) async {
    final data = await _api.getMap('/guilds/$guildId/automod/rules');
    final rules = data['rules'];
    if (rules is! List) {
      return const <AutoModRuleSummary>[];
    }
    return rules
        .whereType<Map<Object?, Object?>>()
        .map(AutoModRuleSummary.fromJson)
        .toList(growable: false);
  }

  static String? _reason(String? reason) {
    if (reason == null || reason.isEmpty) {
      return null;
    }
    return reason;
  }

  Future<void> createAutoModRule(
    String guildId, {
    required String name,
    required String kind,
    List<String> keywords = const <String>[],
    List<String> regexPatterns = const <String>[],
    int mentionTotalLimit = 5,
    List<String> allowList = const <String>[],
    String? alertChannelId,
    bool enabled = true,
  }) async {
    await _api.postMap(
      '/guilds/$guildId/automod/rules',
      body: <String, Object?>{
        'name': name,
        'kind': kind,
        'keywords': keywords,
        'regexPatterns': regexPatterns,
        'mentionTotalLimit': mentionTotalLimit,
        'allowList': allowList,
        'alertChannelId': alertChannelId,
        'enabled': enabled,
      },
    );
  }

  Future<void> updateAutoModRule(
    String guildId,
    String ruleId, {
    required String name,
    required String kind,
    List<String> keywords = const <String>[],
    List<String> regexPatterns = const <String>[],
    int mentionTotalLimit = 5,
    List<String> allowList = const <String>[],
    String? alertChannelId,
    bool enabled = true,
  }) async {
    await _api.patchMap(
      '/guilds/$guildId/automod/rules/$ruleId',
      body: <String, Object?>{
        'name': name,
        'kind': kind,
        'keywords': keywords,
        'regexPatterns': regexPatterns,
        'mentionTotalLimit': mentionTotalLimit,
        'allowList': allowList,
        'alertChannelId': alertChannelId,
        'enabled': enabled,
      },
    );
  }

  Future<void> deleteAutoModRule(String guildId, String ruleId) async {
    await _api.delete('/guilds/$guildId/automod/rules/$ruleId');
  }

  Future<List<ServerRole>> roles(String guildId) async {
    final data = await _api.getMap('/guilds/$guildId/roles');
    final roles = data['roles'];
    if (roles is! List) {
      return const <ServerRole>[];
    }
    return roles
        .whereType<Map<Object?, Object?>>()
        .map(ServerRole.fromJson)
        .toList(growable: false);
  }

  Future<void> createRole(
    String guildId, {
    required String name,
    int? color,
    String? permissions,
  }) async {
    await _api.postMap(
      '/guilds/$guildId/roles',
      body: <String, Object?>{
        'name': name,
        'color': ?color,
        'permissions': ?permissions,
      },
    );
  }

  Future<void> updateRole(
    String guildId,
    String roleId, {
    String? name,
    int? color,
    String? permissions,
  }) async {
    await _api.patchMap(
      '/guilds/$guildId/roles/$roleId',
      body: <String, Object?>{
        'name': ?name,
        'color': ?color,
        'permissions': ?permissions,
      },
    );
  }

  Future<void> deleteRole(String guildId, String roleId) async {
    await _api.delete('/guilds/$guildId/roles/$roleId');
  }

  Future<List<ServerMember>> members(String guildId, {int limit = 100}) async {
    final data = await _api.getMap(
      '/guilds/$guildId/members',
      query: <String, Object?>{'limit': limit},
    );
    final members = data['members'];
    if (members is! List) {
      return const <ServerMember>[];
    }
    return members
        .whereType<Map<Object?, Object?>>()
        .map(ServerMember.fromJson)
        .toList(growable: false);
  }

  /// The permissions Discord computes for a member in a channel.
  Future<String> memberPermissions(
    String guildId, {
    required String userId,
    required String channelId,
  }) async {
    final data = await _api.getMap(
      '/guilds/$guildId/members/$userId/permissions',
      query: <String, Object?>{'channelId': channelId},
    );
    final inspection = data['inspection'];
    if (inspection is Map) {
      final permissions = inspection['permissions'];
      if (permissions is String) {
        return permissions;
      }
    }
    return '0';
  }

  Future<List<ServerChannel>> channels(String guildId) async {
    final data = await _api.getMap('/guilds/$guildId/channels');
    final channels = data['channels'];
    if (channels is! List) {
      return const <ServerChannel>[];
    }
    return channels
        .whereType<Map<Object?, Object?>>()
        .map(ServerChannel.fromJson)
        .toList(growable: false);
  }

  Future<List<RecentMessage>> recentMessages(
    String guildId, {
    required String channelId,
    int limit = 50,
  }) async {
    final data = await _api.getMap(
      '/guilds/$guildId/channels/$channelId/messages',
      query: <String, Object?>{'limit': limit},
    );
    final messages = data['messages'];
    if (messages is! List) {
      return const <RecentMessage>[];
    }
    return messages
        .whereType<Map<Object?, Object?>>()
        .map(RecentMessage.fromJson)
        .toList(growable: false);
  }

  Future<void> createChannel(
    String guildId, {
    required String name,
    required int type,
    String? parentId,
  }) async {
    await _api.postMap(
      '/guilds/$guildId/channels',
      body: <String, Object?>{
        'name': name,
        'type': type,
        'parentId': ?parentId,
      },
    );
  }

  Future<void> updateChannel(
    String guildId,
    String channelId, {
    String? name,
    String? parentId,
    int? rateLimitPerUser,
  }) async {
    await _api.patchMap(
      '/guilds/$guildId/channels/$channelId',
      body: <String, Object?>{
        'name': ?name,
        'parentId': ?parentId,
        'rateLimitPerUser': ?rateLimitPerUser,
      },
    );
  }

  Future<void> deleteChannel(String guildId, String channelId) async {
    await _api.delete('/guilds/$guildId/channels/$channelId');
  }

  Future<void> createOverwrite(
    String guildId,
    String channelId, {
    required String targetId,
    required int type,
    required String allow,
    required String deny,
  }) async {
    await _api.putMap(
      '/guilds/$guildId/channels/$channelId/overwrites/$targetId',
      body: <String, Object?>{'type': type, 'allow': allow, 'deny': deny},
    );
  }

  Future<void> deleteOverwrite(
    String guildId,
    String channelId,
    String targetId,
  ) async {
    await _api.delete(
      '/guilds/$guildId/channels/$channelId/overwrites/$targetId',
    );
  }

  Future<List<ScheduledAnnouncement>> announcements(String guildId) async {
    final data = await _api.getMap('/guilds/$guildId/engagement/announcements');
    final announcements = data['announcements'];
    if (announcements is! List) {
      return const <ScheduledAnnouncement>[];
    }
    return announcements
        .whereType<Map<Object?, Object?>>()
        .map(ScheduledAnnouncement.fromJson)
        .toList(growable: false);
  }

  Future<void> scheduleAnnouncement(
    String guildId, {
    required String channelId,
    required String content,
    required DateTime scheduledAt,
  }) async {
    await _api.postMap(
      '/guilds/$guildId/engagement/announcements',
      body: <String, Object?>{
        'channelId': channelId,
        'content': content,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> cancelAnnouncement(String guildId, String announcementId) async {
    await _api.postMap(
      '/guilds/$guildId/engagement/announcements/$announcementId/cancel',
    );
  }

  Future<List<InviteSummary>> invites(String guildId) async {
    final data = await _api.getMap('/guilds/$guildId/engagement/invites');
    final invites = data['invites'];
    if (invites is! List) {
      return const <InviteSummary>[];
    }
    return invites
        .whereType<Map<Object?, Object?>>()
        .map(InviteSummary.fromJson)
        .toList(growable: false);
  }

  Future<List<InviteJoin>> inviteJoins(String guildId) async {
    final data = await _api.getMap('/guilds/$guildId/engagement/joins');
    final joins = data['joins'];
    if (joins is! List) {
      return const <InviteJoin>[];
    }
    return joins
        .whereType<Map<Object?, Object?>>()
        .map(InviteJoin.fromJson)
        .toList(growable: false);
  }

  Future<String> postReactionRole(
    String guildId, {
    required String channelId,
    required String content,
    required List<({String emoji, String roleId})> bindings,
  }) async {
    final data = await _api.postMap(
      '/guilds/$guildId/engagement/reaction-role',
      body: <String, Object?>{
        'channelId': channelId,
        'content': content,
        'bindings': bindings
            .map(
              (binding) => <String, Object?>{
                'emoji': binding.emoji,
                'roleId': binding.roleId,
              },
            )
            .toList(growable: false),
      },
    );
    final messageId = data['messageId'];
    return messageId is String ? messageId : '';
  }

  Future<String> postButtonRole(
    String guildId, {
    required String channelId,
    required String content,
    required List<({String roleId, String label})> buttons,
  }) async {
    final data = await _api.postMap(
      '/guilds/$guildId/engagement/button-role',
      body: <String, Object?>{
        'channelId': channelId,
        'content': content,
        'buttons': buttons
            .map(
              (button) => <String, Object?>{
                'roleId': button.roleId,
                'label': button.label,
              },
            )
            .toList(growable: false),
      },
    );
    final messageId = data['messageId'];
    return messageId is String ? messageId : '';
  }

  Future<List<ServerEmoji>> emojis(String guildId) async {
    final data = await _api.getMap('/guilds/$guildId/tools/emojis');
    final emojis = data['emojis'];
    if (emojis is! List) {
      return const <ServerEmoji>[];
    }
    return emojis
        .whereType<Map<Object?, Object?>>()
        .map(ServerEmoji.fromJson)
        .toList(growable: false);
  }

  Future<void> deleteEmoji(String guildId, String emojiId) async {
    await _api.delete('/guilds/$guildId/tools/emojis/$emojiId');
  }

  Future<List<ServerSticker>> stickers(String guildId) async {
    final data = await _api.getMap('/guilds/$guildId/tools/stickers');
    final stickers = data['stickers'];
    if (stickers is! List) {
      return const <ServerSticker>[];
    }
    return stickers
        .whereType<Map<Object?, Object?>>()
        .map(ServerSticker.fromJson)
        .toList(growable: false);
  }

  Future<void> deleteSticker(String guildId, String stickerId) async {
    await _api.delete('/guilds/$guildId/tools/stickers/$stickerId');
  }

  Future<List<AuditLogEntry>> auditLog(String guildId, {int limit = 50}) async {
    final data = await _api.getMap(
      '/guilds/$guildId/tools/audit-log',
      query: <String, Object?>{'limit': limit},
    );
    final entries = data['entries'];
    if (entries is! List) {
      return const <AuditLogEntry>[];
    }
    return entries
        .whereType<Map<Object?, Object?>>()
        .map(AuditLogEntry.fromJson)
        .toList(growable: false);
  }

  Future<Map<Object?, Object?>> exportBackup(String guildId) async {
    final data = await _api.getMap('/guilds/$guildId/tools/backup');
    final backup = data['backup'];
    return backup is Map ? backup : const <Object?, Object?>{};
  }

  Future<void> restoreBackup(
    String guildId,
    Map<Object?, Object?> backup,
  ) async {
    await _api.postMap(
      '/guilds/$guildId/tools/backup/restore',
      body: <String, Object?>{'backup': backup},
    );
  }

  Future<ServerSettings> settings(String guildId) async {
    final data = await _api.getMap('/guilds/$guildId/settings');
    final settings = data['settings'];
    return ServerSettings.fromJson(
      settings is Map ? settings : const <Object?, Object?>{},
    );
  }

  Future<void> updateSettings(
    String guildId,
    Map<String, Object?> patch,
  ) async {
    await _api.putMap('/guilds/$guildId/settings', body: patch);
  }
}
