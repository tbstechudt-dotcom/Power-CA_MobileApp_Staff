import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service for managing local notifications
/// Handles initialization, permission requests, and notification display
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  /// Call this once in main.dart before runApp
  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    debugPrint('NotificationService: Initialized');
  }

  /// Request notification permissions (Android 13+ and iOS)
  Future<bool> requestPermissions() async {
    bool granted = true;

    // Android 13+ requires explicit permission request
    final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final result = await androidPlugin.requestNotificationsPermission();
      granted = result ?? false;
    }

    // iOS permission request
    final iosPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      final result = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = result ?? false;
    }

    debugPrint('NotificationService: Permission granted = $granted');
    return granted;
  }

  /// Show a leave status notification (approved/rejected)
  Future<void> showLeaveStatusNotification({
    required int leaveId,
    required String status,
    required String leaveType,
    required String dateRange,
  }) async {
    if (!_isInitialized) {
      debugPrint('NotificationService: Not initialized, skipping notification');
      return;
    }

    final isApproved = status.toLowerCase() == 'approved';

    const androidDetails = AndroidNotificationDetails(
      'leave_notifications',
      'Leave Notifications',
      channelDescription: 'Notifications for leave request status updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      leaveId,
      'Leave Request ${isApproved ? 'Approved' : 'Rejected'}',
      '$leaveType ($dateRange) has been ${status.toLowerCase()}',
      details,
      payload: 'leave:$leaveId',
    );

    debugPrint('NotificationService: Showed leave notification for ID $leaveId');
  }

  /// Show a new pinboard reminder notification
  Future<void> showPinboardNotification({
    required String remId,
    required String title,
    required String clientName,
    required String dueDate,
  }) async {
    if (!_isInitialized) {
      debugPrint('NotificationService: Not initialized, skipping notification');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'pinboard_notifications',
      'Pinboard Notifications',
      channelDescription: 'Notifications for new pinboard reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      remId.hashCode,
      'New Reminder: $title',
      'For $clientName - Due: $dueDate',
      details,
      payload: 'pinboard:$remId',
    );

    debugPrint('NotificationService: Showed pinboard notification for ID $remId');
  }

  static const int _workLogReminderId = 9001;
  static const String _workLogReminderKey = 'work_log_reminder_last_shown';

  /// Remind the staff member to log today's work.
  ///
  /// Shown at most once per calendar day: the date it was last shown is
  /// stored in SharedPreferences and later calls on the same day are ignored.
  Future<void> showWorkLogReminder() async {
    if (!_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (prefs.getString(_workLogReminderKey) == today) {
      debugPrint('NotificationService: Work log reminder already shown today');
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'work_log_reminders',
        'Work Log Reminders',
        channelDescription: 'Daily reminder to log your work',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    await _flutterLocalNotificationsPlugin.show(
      _workLogReminderId,
      "Don't forget your work log",
      "You haven't logged any work for today yet.",
      details,
      payload: 'worklog:$today',
    );
    await prefs.setString(_workLogReminderKey, today);
    debugPrint('NotificationService: Showed work log reminder');
  }

  /// Remove the work log reminder (e.g. once today's work is logged).
  Future<void> cancelWorkLogReminder() async {
    if (!_isInitialized) return;
    await _flutterLocalNotificationsPlugin.cancel(_workLogReminderId);
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - navigate to relevant page
    // Payload format: "leave:123" or "pinboard:456"
    debugPrint(
        'NotificationService: Tapped notification with payload: ${response.payload}');

    // Navigation can be handled via global navigator key or callback
    // For now, just log the tap - navigation will be implemented if needed
    if (response.payload != null) {
      final parts = response.payload!.split(':');
      if (parts.length == 2) {
        final type = parts[0];
        final id = parts[1];
        debugPrint('NotificationService: Type=$type, ID=$id');
        // TODO: Navigate to relevant page if needed
      }
    }
  }
}
