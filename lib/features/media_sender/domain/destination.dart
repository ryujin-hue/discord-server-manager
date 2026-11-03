/// A destination the media sender can upload to.
enum DestinationType {
  webhook,
  bot;

  String get code => switch (this) {
    DestinationType.webhook => 'webhook',
    DestinationType.bot => 'bot',
  };

  static DestinationType fromCode(String code) =>
      code == 'bot' ? DestinationType.bot : DestinationType.webhook;
}

/// A webhook or a bot channel the user can send media to.
class Destination {
  const Destination({
    required this.id,
    required this.name,
    required this.type,
    required this.active,
    required this.createdAt,
    this.guildId,
    this.channelId,
  });

  final String id;
  final String name;
  final DestinationType type;
  final bool active;
  final DateTime createdAt;
  final String? guildId;
  final String? channelId;

  /// The channel the destination points at, when it has one.
  String? get targetChannelId => channelId;
}
