import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
      settings: initSettings,
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
      id: leaveId,
      title: 'Leave Request ${isApproved ? 'Approved' : 'Rejected'}',
      body: '$leaveType ($dateRange) has been ${status.toLowerCase()}',
      notificationDetails: details,
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
      id: remId.hashCode,
      title: 'New Reminder: $title',
      body: 'For $clientName - Due: $dueDate',
      notificationDetails: details,
      payload: 'pinboard:$remId',
    );

    debugPrint('NotificationService: Showed pinboard notification for ID $remId');
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
