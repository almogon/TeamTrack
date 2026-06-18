import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class MatchNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'match_alerts';
  static const _channelName = 'Match Alerts';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> initialize() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestSoundPermission: true,
        ),
      ),
    );
  }

  static Future<void> showHalftimeAlert(String opponent) => _plugin.show(
        1,
        'Halftime!',
        'vs $opponent — break time',
        _details,
      );

  static Future<void> showQuarterBreak(String opponent, int quarter) =>
      _plugin.show(
        2,
        'Q$quarter ended',
        'vs $opponent — quarter break',
        _details,
      );

  static Future<void> showMatchEnd(String opponent) => _plugin.show(
        3,
        'Full time!',
        'vs $opponent — match finished',
        _details,
      );
}
