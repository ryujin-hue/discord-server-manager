/// The theme the user picked.
enum AppThemeMode {
  system,
  light,
  dark;

  String get code => switch (this) {
    AppThemeMode.system => 'system',
    AppThemeMode.light => 'light',
    AppThemeMode.dark => 'dark',
  };

  static AppThemeMode fromCode(String? code) {
    for (final mode in AppThemeMode.values) {
      if (mode.code == code) {
        return mode;
      }
    }
    return AppThemeMode.system;
  }
}

/// The user settings of the app.
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.notificationsEnabled,
    required this.uploadConcurrency,
    required this.sizeLimitBytes,
    required this.maxFilesPerMessage,
    required this.groupFiles,
  });

  /// The default upload limit. Discord raises its own limit from time to
  /// time, so the value stays editable.
  static const int defaultSizeLimitBytes = 10 * 1024 * 1024;

  /// Discord accepts at most ten files in one message.
  static const int hardMaxFilesPerMessage = 10;

  final AppThemeMode themeMode;
  final bool notificationsEnabled;

  /// How many files are uploaded at the same time.
  final int uploadConcurrency;

  /// The maximum size of a single file.
  final int sizeLimitBytes;

  /// How many files are grouped into one message.
  final int maxFilesPerMessage;

  /// True when several files are sent as one message.
  final bool groupFiles;

  static const AppSettings defaults = AppSettings(
    themeMode: AppThemeMode.system,
    notificationsEnabled: true,
    uploadConcurrency: 1,
    sizeLimitBytes: defaultSizeLimitBytes,
    maxFilesPerMessage: 1,
    groupFiles: false,
  );

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? notificationsEnabled,
    int? uploadConcurrency,
    int? sizeLimitBytes,
    int? maxFilesPerMessage,
    bool? groupFiles,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      uploadConcurrency: uploadConcurrency ?? this.uploadConcurrency,
      sizeLimitBytes: sizeLimitBytes ?? this.sizeLimitBytes,
      maxFilesPerMessage: maxFilesPerMessage ?? this.maxFilesPerMessage,
      groupFiles: groupFiles ?? this.groupFiles,
    );
  }

  Map<String, String> toStorage() => <String, String>{
    'themeMode': themeMode.code,
    'notificationsEnabled': notificationsEnabled.toString(),
    'uploadConcurrency': uploadConcurrency.toString(),
    'sizeLimitBytes': sizeLimitBytes.toString(),
    'maxFilesPerMessage': maxFilesPerMessage.toString(),
    'groupFiles': groupFiles.toString(),
  };

  static AppSettings fromStorage(Map<String, String> values) {
    final defaults = AppSettings.defaults;
    return AppSettings(
      themeMode: AppThemeMode.fromCode(values['themeMode']),
      notificationsEnabled: values['notificationsEnabled'] != 'false',
      uploadConcurrency: _intInRange(
        values['uploadConcurrency'],
        defaults.uploadConcurrency,
        1,
        3,
      ),
      sizeLimitBytes: _intInRange(
        values['sizeLimitBytes'],
        defaults.sizeLimitBytes,
        1024 * 1024,
        512 * 1024 * 1024,
      ),
      maxFilesPerMessage: _intInRange(
        values['maxFilesPerMessage'],
        defaults.maxFilesPerMessage,
        1,
        hardMaxFilesPerMessage,
      ),
      groupFiles: values['groupFiles'] == 'true',
    );
  }

  static int _intInRange(String? raw, int fallback, int min, int max) {
    final parsed = int.tryParse(raw ?? '');
    if (parsed == null) {
      return fallback;
    }
    if (parsed < min) {
      return min;
    }
    if (parsed > max) {
      return max;
    }
    return parsed;
  }
}
