/// The kind of a picked file.
enum MediaKind {
  image,
  video,
  file;

  static MediaKind fromName(String? name, String? mimeType) {
    final lowerName = (name ?? '').toLowerCase();
    final lowerMime = (mimeType ?? '').toLowerCase();
    if (lowerMime.startsWith('image/') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.webp')) {
      return MediaKind.image;
    }
    if (lowerMime.startsWith('video/') ||
        lowerName.endsWith('.mp4') ||
        lowerName.endsWith('.mov') ||
        lowerName.endsWith('.mkv') ||
        lowerName.endsWith('.webm')) {
      return MediaKind.video;
    }
    return MediaKind.file;
  }
}

/// A file the user picked on the device.
class PickedMedia {
  const PickedMedia({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.kind,
    this.mimeType,
    this.modifiedAt,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final MediaKind kind;
  final String? mimeType;
  final DateTime? modifiedAt;

  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) {
      return '';
    }
    return name.substring(dot + 1).toLowerCase();
  }

  /// Discord accepts these formats for uploads.
  static const Set<String> supportedImageExtensions = <String>{
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
  };

  static const Set<String> supportedVideoExtensions = <String>{
    'mp4',
    'mov',
    'mkv',
    'webm',
  };

  /// True when Discord is able to send the file as it is.
  bool get isSupported {
    switch (kind) {
      case MediaKind.image:
        return supportedImageExtensions.contains(extension);
      case MediaKind.video:
        return supportedVideoExtensions.contains(extension);
      case MediaKind.file:
        return true;
    }
  }
}
