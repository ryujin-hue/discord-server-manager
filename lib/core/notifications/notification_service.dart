import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows the notifications of the app.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String channelId = 'dsm_uploads';
  static const String channelName = 'Uploads';

  bool _initialized = false;

  /// Prepares the notification channels.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Asks the user for the permission to show notifications.
  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Notifies that an upload finished or failed.
  Future<void> showUploadResult({
    required int id,
    required String fileName,
    required bool success,
    String? detail,
  }) async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(
      id: id,
      title: success ? 'Upload finished' : 'Upload failed',
      body: success
          ? '$fileName was sent to Discord.'
          : '$fileName could not be sent.${detail == null ? '' : ' $detail'}',
      notificationDetails: details,
    );
  }
}
