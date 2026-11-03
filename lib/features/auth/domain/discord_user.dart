/// The Discord user the app is signed in as.
class DiscordUser {
  const DiscordUser({
    required this.id,
    required this.username,
    required this.globalName,
    required this.avatarHash,
    required this.discriminator,
    required this.isBot,
  });

  final String id;
  final String username;
  final String? globalName;
  final String? avatarHash;
  final String discriminator;
  final bool isBot;

  String get displayName {
    final name = globalName;
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return username;
  }

  /// The initials shown when the user has no avatar.
  String get initials {
    final source = displayName.trim();
    if (source.isEmpty) {
      return '?';
    }
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return source.substring(0, source.length >= 2 ? 2 : 1).toUpperCase();
  }

  static DiscordUser fromJson(Map<Object?, Object?> json) {
    return DiscordUser(
      id: _string(json['id']),
      username: _string(json['username'], fallback: 'Unknown user'),
      globalName: _nullableString(json['global_name']),
      avatarHash: _nullableString(json['avatar']),
      discriminator: _string(json['discriminator'], fallback: '0'),
      isBot: json['bot'] == true,
    );
  }

  String? get avatarUrl {
    final hash = avatarHash;
    if (hash == null || hash.isEmpty) {
      return null;
    }
    final animated = hash.startsWith('a_');
    final plain = animated ? hash.substring(2) : hash;
    final extension = animated ? 'gif' : 'png';
    return 'https://cdn.discordapp.com/avatars/$id/$plain.$extension';
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
