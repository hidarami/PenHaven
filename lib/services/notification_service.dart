import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION SERVICE
// Handles local push notifications for:
//   - Time capsules ready to open
//   - Task deadlines (1h before)
//
// Uses flutter_local_notifications. No backend required.
// All data stays local.
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'flow_main';
  static const _channelName = 'Flow';
  static const _channelDesc = 'Reminders and updates from Flow';

  static const _androidChannel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.defaultImportance,
  );

  // ── IDs ──────────────────────────────────────────────────────────────────
  static const int _capsuleReadyId = 1001;
  static const int _taskBaseId = 3000; // task notifications start here

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.local);
      } catch (_) {}

      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[NotificationService] init failed: $e');
    }
  }

  Future<bool> requestPermission() async {
    if (!_initialized) await init();
    try {
      if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        return await ios?.requestPermissions(
                alert: true, badge: true, sound: true) ??
            false;
      }
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? false;
      }
    } catch (_) {}
    return false;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  NotificationDetails get _details => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      );

  // ── Immediate notifications ───────────────────────────────────────────────

  Future<void> showTimeCapsuleReady(String preview) async {
    if (!_initialized) await init();
    final body = preview.length > 70
        ? '${preview.substring(0, 70)}…'
        : preview;
    try {
      await _plugin.show(
          _capsuleReadyId, '⏳ Time Capsule Ready', body, _details);
    } catch (e) {
      debugPrint('[NotificationService] showTimeCapsuleReady: $e');
    }
  }

  Future<void> showMilestone(int words) async {
    if (!_initialized) await init();
    final label = words >= 5000
        ? 'Five thousand words'
        : words >= 2000
            ? 'Two thousand words'
            : words >= 1000
                ? 'One thousand words'
                : 'Five hundred words';
    try {
      await _plugin.show(
          4001, '✦ $label', 'Keep writing. This is real.', _details);
    } catch (e) {
      debugPrint('[NotificationService] showMilestone: $e');
    }
  }

  // ── Scheduled notifications ───────────────────────────────────────────────

  Future<void> scheduleTaskDeadline({
    required String taskId,
    required String title,
    required DateTime deadline,
  }) async {
    if (!_initialized) await init();
    final notifyAt = deadline.subtract(const Duration(hours: 1));
    if (notifyAt.isBefore(DateTime.now())) return;

    // Use hashCode to get consistent int ID from string task id
    final notifId = _taskBaseId + (taskId.hashCode.abs() % 900);

    try {
      await _plugin.zonedSchedule(
        notifId,
        '📝 Task due soon',
        title,
        tz.TZDateTime.from(notifyAt, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('[NotificationService] scheduleTaskDeadline: $e');
    }
  }

  Future<void> cancelTask(String taskId) async {
    final notifId = _taskBaseId + (taskId.hashCode.abs() % 900);
    await _plugin.cancel(notifId);
  }

  Future<void> cancelAll() async => _plugin.cancelAll();
}