/// Discord permission bits as of API v10.
class PermissionBits {
  const PermissionBits._();

  static final BigInt createInstantInvite = BigInt.one << 0;
  static final BigInt kickMembers = BigInt.one << 1;
  static final BigInt banMembers = BigInt.one << 2;
  static final BigInt administrator = BigInt.one << 3;
  static final BigInt manageChannels = BigInt.one << 4;
  static final BigInt manageGuild = BigInt.one << 5;
  static final BigInt addReactions = BigInt.one << 6;
  static final BigInt viewAuditLog = BigInt.one << 7;
  static final BigInt prioritySpeaker = BigInt.one << 8;
  static final BigInt stream = BigInt.one << 9;
  static final BigInt viewChannel = BigInt.one << 10;
  static final BigInt sendMessages = BigInt.one << 11;
  static final BigInt sendTtsMessages = BigInt.one << 12;
  static final BigInt manageMessages = BigInt.one << 13;
  static final BigInt embedLinks = BigInt.one << 14;
  static final BigInt attachFiles = BigInt.one << 15;
  static final BigInt readMessageHistory = BigInt.one << 16;
  static final BigInt mentionEveryone = BigInt.one << 17;
  static final BigInt useExternalEmojis = BigInt.one << 18;
  static final BigInt viewGuildInsights = BigInt.one << 19;
  static final BigInt connect = BigInt.one << 20;
  static final BigInt speak = BigInt.one << 21;
  static final BigInt muteMembers = BigInt.one << 22;
  static final BigInt deafenMembers = BigInt.one << 23;
  static final BigInt moveMembers = BigInt.one << 24;
  static final BigInt useVad = BigInt.one << 25;
  static final BigInt changeNickname = BigInt.one << 26;
  static final BigInt manageNicknames = BigInt.one << 27;
  static final BigInt manageRoles = BigInt.one << 28;
  static final BigInt manageWebhooks = BigInt.one << 29;
  static final BigInt manageGuildExpressions = BigInt.one << 30;
  static final BigInt useApplicationCommands = BigInt.one << 31;
  static final BigInt requestToSpeak = BigInt.one << 32;
  static final BigInt manageEvents = BigInt.one << 33;
  static final BigInt manageThreads = BigInt.one << 34;
  static final BigInt createPublicThreads = BigInt.one << 35;
  static final BigInt createPrivateThreads = BigInt.one << 36;
  static final BigInt useExternalStickers = BigInt.one << 37;
  static final BigInt sendMessagesInThreads = BigInt.one << 38;
  static final BigInt useEmbeddedActivities = BigInt.one << 39;
  static final BigInt moderateMembers = BigInt.one << 40;
  static final BigInt viewCreatorMonetizationAnalytics = BigInt.one << 41;
  static final BigInt useSoundboard = BigInt.one << 42;
  static final BigInt createGuildExpressions = BigInt.one << 43;
  static final BigInt createEvents = BigInt.one << 44;
  static final BigInt useExternalSounds = BigInt.one << 45;
  static final BigInt sendVoiceMessages = BigInt.one << 46;
  static final BigInt sendPolls = BigInt.one << 47;
  static final BigInt useExternalApps = BigInt.one << 48;

  /// True when the permission set contains the given bit. Administrator
  /// implies every other permission.
  static bool has(BigInt permissions, BigInt permission) {
    if ((permissions & administrator) == administrator) {
      return true;
    }
    return (permissions & permission) == permission;
  }

  /// True when the member may administer the server.
  static bool canAdminister(BigInt permissions) =>
      has(permissions, administrator) || has(permissions, manageGuild);

  /// Parses the permission field Discord returns, which is a decimal string.
  static BigInt parse(Object? raw) {
    if (raw is BigInt) {
      return raw;
    }
    if (raw is int) {
      return BigInt.from(raw);
    }
    if (raw is String) {
      return BigInt.tryParse(raw) ?? BigInt.zero;
    }
    return BigInt.zero;
  }
}

/// The permission set the bot needs for the REST features and the gateway
/// handlers of this app. Administrator is intentionally not part of it.
class BotPermissions {
  const BotPermissions._();

  /// Each entry documents why the bit is required.
  static const Map<String, String> reasons = <String, String>{
    'CREATE_INSTANT_INVITE':
        'The invite tracker reads the invite list of a server.',
    'KICK_MEMBERS': 'Kicking a member is part of the moderation tools.',
    'BAN_MEMBERS': 'Banning a member is part of the moderation tools.',
    'MANAGE_CHANNELS':
        'Channels and categories are created, renamed and deleted.',
    'MANAGE_GUILD':
        'The verification level and the server settings are changed.',
    'ADD_REACTIONS': 'Reaction roles are granted when a reaction is added.',
    'VIEW_AUDIT_LOG': 'The audit log is shown in the server tools tab.',
    'VIEW_CHANNEL': 'Every server feature reads channels and members.',
    'SEND_MESSAGES':
        'Welcome messages, announcements and the moderation log are sent.',
    'MANAGE_MESSAGES': 'Purging messages deletes up to 100 messages per call.',
    'READ_MESSAGE_HISTORY':
        'Purging needs the history, and reactions need the message.',
    'MANAGE_ROLES': 'Roles are created, edited and granted by the role tools.',
    'MANAGE_GUILD_EXPRESSIONS':
        'Emojis and stickers are managed in the server tools tab.',
    'USE_APPLICATION_COMMANDS':
        'The bot registers slash commands for the server.',
    'MODERATE_MEMBERS':
        'Timing a member out requires the moderate members permission.',
  };

  /// The permission bits in the order they are documented.
  static final List<BigInt> bits = <BigInt>[
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

  /// The integer used in the bot invite URL.
  static BigInt get integer =>
      bits.fold<BigInt>(BigInt.zero, (total, bit) => total | bit);

  /// The human readable bit list shown next to the invite button.
  static List<String> get names => reasons.keys.toList(growable: false);
}
