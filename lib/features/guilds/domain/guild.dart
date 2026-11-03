import '../../../core/utils/discord_permissions.dart';

/// A Discord server the signed in user is a member of.
class DiscordGuild {
  const DiscordGuild({
    required this.id,
    required this.name,
    required this.owner,
    required this.permissions,
    this.iconHash,
    this.memberCount,
    this.presenceCount,
  });

  final String id;
  final String name;
  final bool owner;
  final BigInt permissions;
  final String? iconHash;
  final int? memberCount;
  final int? presenceCount;

  /// True when the member owns the server or may administer it.
  bool get canAdminister => owner || PermissionBits.canAdminister(permissions);

  String? get iconUrl {
    final hash = iconHash;
    if (hash == null || hash.isEmpty) {
      return null;
    }
    return 'https://cdn.discordapp.com/icons/$id/$hash.png';
  }

  /// The initials shown when a server has no icon.
  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      final single = parts.first;
      return single.substring(0, single.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static DiscordGuild fromJson(Map<Object?, Object?> json) {
    return DiscordGuild(
      id: _string(json['id']),
      name: _string(json['name'], fallback: 'Unknown server'),
      owner: json['owner'] == true,
      permissions: PermissionBits.parse(json['permissions']),
      iconHash: _nullableString(json['icon']),
      memberCount: _nullableInt(json['approximate_member_count']),
      presenceCount: _nullableInt(json['approximate_presence_count']),
    );
  }

  @override
  bool operator ==(Object other) => other is DiscordGuild && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Keeps the servers the user may administer.
List<DiscordGuild> filterAdministeredGuilds(Iterable<DiscordGuild> guilds) =>
    guilds.where((guild) => guild.canAdminister).toList(growable: false);

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int? _nullableInt(Object? value) => value is int ? value : null;
