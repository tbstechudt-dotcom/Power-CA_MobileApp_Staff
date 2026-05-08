import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Callback type for session invalidation events
typedef SessionInvalidatedCallback = void Function(String deviceName, String message);

/// Callback type for login request events (another device wants to login)
typedef LoginRequestCallback = void Function(int requestId, String deviceName);

/// Result of a login request
enum LoginRequestResult { approved, denied, expired, error }

/// Service for managing single-device sessions
/// Ensures only one device can be logged in at a time per staff member
/// Includes real-time listening for instant session invalidation alerts
/// Supports permission-based login where existing device must approve new logins
class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  final _supabase = Supabase.instance.client;
  final _deviceInfo = DeviceInfoPlugin();

  static const String _deviceIdKey = 'DEVICE_SESSION_ID';

  String? _cachedDeviceId;
  RealtimeChannel? _sessionChannel;
  RealtimeChannel? _loginRequestChannel;
  int? _listeningStaffId;
  SessionInvalidatedCallback? _onSessionInvalidated;
  LoginRequestCallback? _onLoginRequest;

  /// Get unique device identifier
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    try {
      String deviceId;

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Use Android ID as unique identifier
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Use identifier for vendor
        deviceId = iosInfo.identifierForVendor ?? 'unknown_ios';
      } else {
        // Fallback for web/desktop
        deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }

      _cachedDeviceId = deviceId;
      return deviceId;
    } catch (e) {
      debugPrint('SessionService: Error getting device ID: $e');
      return 'error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Get device name for display
  Future<String> getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.name;
      }
      return 'Unknown Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }

  /// Register this device as the active session for a staff member
  /// Returns true if successful, false if failed
  Future<bool> registerSession(int staffId) async {
    try {
      final deviceId = await getDeviceId();
      final deviceName = await getDeviceName();

      debugPrint('SessionService: Registering session for staff $staffId on device $deviceId');

      // Upsert session - this will invalidate any existing session for this staff
      await _supabase.from('staff_sessions').upsert({
        'staff_id': staffId,
        'device_id': deviceId,
        'device_name': deviceName,
        'last_active': DateTime.now().toIso8601String(),
        'is_active': true,
      }, onConflict: 'staff_id',);

      // Save device ID locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceIdKey, deviceId);

      debugPrint('SessionService: Session registered successfully');
      return true;
    } catch (e) {
      debugPrint('SessionService: Error registering session: $e');
      return false;
    }
  }

  /// Check if this device's session is still valid
  /// Returns null if valid, or a message if session was invalidated
  Future<String?> validateSession(int staffId) async {
    try {
      final deviceId = await getDeviceId();

      // Get the current active session for this staff
      final response = await _supabase
          .from('staff_sessions')
          .select()
          .eq('staff_id', staffId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        // No active session - this shouldn't happen normally
        debugPrint('SessionService: No active session found');
        return null; // Allow login
      }

      final activeDeviceId = response['device_id'] as String?;

      if (activeDeviceId != deviceId) {
        // Session was taken over by another device
        final otherDeviceName = response['device_name'] as String? ?? 'another device';
        debugPrint('SessionService: Session invalidated - active on $otherDeviceName');
        return 'Your account is now logged in on $otherDeviceName. You have been logged out.';
      }

      // Update last active timestamp
      await _updateLastActive(staffId, deviceId);

      return null; // Session is valid
    } catch (e) {
      debugPrint('SessionService: Error validating session: $e');
      // On error, don't block the user
      return null;
    }
  }

  /// Update last active timestamp
  Future<void> _updateLastActive(int staffId, String deviceId) async {
    try {
      await _supabase.from('staff_sessions').update({
        'last_active': DateTime.now().toIso8601String(),
      }).eq('staff_id', staffId).eq('device_id', deviceId);
    } catch (e) {
      debugPrint('SessionService: Error updating last active: $e');
    }
  }

  /// Clear session on logout
  Future<void> clearSession(int staffId) async {
    try {
      final deviceId = await getDeviceId();

      await _supabase.from('staff_sessions').update({
        'is_active': false,
      }).eq('staff_id', staffId).eq('device_id', deviceId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdKey);

      debugPrint('SessionService: Session cleared');
    } catch (e) {
      debugPrint('SessionService: Error clearing session: $e');
    }
  }

  /// Get info about the currently active session for a staff member
  Future<Map<String, dynamic>?> getActiveSessionInfo(int staffId) async {
    try {
      final response = await _supabase
          .from('staff_sessions')
          .select()
          .eq('staff_id', staffId)
          .eq('is_active', true)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('SessionService: Error getting session info: $e');
      return null;
    }
  }

  /// Start listening for real-time session changes
  /// When another device logs in, the callback is triggered immediately
  Future<void> startSessionListener({
    required int staffId,
    required SessionInvalidatedCallback onSessionInvalidated,
  }) async {
    // Stop any existing listener
    await stopSessionListener();

    _listeningStaffId = staffId;
    _onSessionInvalidated = onSessionInvalidated;
    final currentDeviceId = await getDeviceId();

    debugPrint('SessionService: Starting real-time session listener for staff $staffId');

    // Subscribe to changes on the staff_sessions table for this staff member
    _sessionChannel = _supabase
        .channel('staff_sessions_$staffId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'staff_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'staff_id',
            value: staffId,
          ),
          callback: (payload) {
            debugPrint('SessionService: Received session update: ${payload.newRecord}');
            _handleSessionUpdate(payload.newRecord, currentDeviceId);
          },
        )
        .subscribe((status, [error]) {
          debugPrint('SessionService: Realtime subscription status: $status');
          if (error != null) {
            debugPrint('SessionService: Realtime error: $error');
          }
        });
  }

  /// Handle incoming session update from Supabase Realtime
  void _handleSessionUpdate(Map<String, dynamic> newRecord, String currentDeviceId) {
    final newDeviceId = newRecord['device_id'] as String?;
    final newDeviceName = newRecord['device_name'] as String? ?? 'another device';
    final isActive = newRecord['is_active'] as bool? ?? false;

    debugPrint('SessionService: Session update - newDeviceId: $newDeviceId, currentDeviceId: $currentDeviceId');

    // Check if session was taken over by a different device
    if (isActive && newDeviceId != null && newDeviceId != currentDeviceId) {
      debugPrint('SessionService: Session taken over by $newDeviceName!');

      // Trigger the callback to notify the app
      _onSessionInvalidated?.call(
        newDeviceName,
        'Your account was just signed in on $newDeviceName. You will be logged out for security.',
      );
    }
  }

  /// Stop listening for session changes
  Future<void> stopSessionListener() async {
    if (_sessionChannel != null) {
      debugPrint('SessionService: Stopping real-time session listener');
      await _supabase.removeChannel(_sessionChannel!);
      _sessionChannel = null;
      _listeningStaffId = null;
      _onSessionInvalidated = null;
    }
  }

  /// Check if currently listening for a specific staff
  bool isListening(int staffId) {
    return _sessionChannel != null && _listeningStaffId == staffId;
  }

  // ============================================================
  // PERMISSION-BASED LOGIN FLOW
  // ============================================================

  /// Check if there's an active session for this staff on another device
  /// Returns the session info if exists, null if no active session
  Future<Map<String, dynamic>?> checkExistingSession(int staffId) async {
    try {
      final deviceId = await getDeviceId();
      final response = await _supabase
          .from('staff_sessions')
          .select()
          .eq('staff_id', staffId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;

      // Check if it's a different device
      final activeDeviceId = response['device_id'] as String?;
      if (activeDeviceId == deviceId) {
        return null; // Same device, no need for permission
      }

      return response;
    } catch (e) {
      debugPrint('SessionService: Error checking existing session: $e');
      return null;
    }
  }

  /// Create a login request and wait for approval from existing device
  /// Returns the request ID if created successfully
  Future<int?> createLoginRequest(int staffId) async {
    try {
      final deviceId = await getDeviceId();
      final deviceName = await getDeviceName();

      // Get the current device that needs to approve
      final existingSession = await checkExistingSession(staffId);
      final currentDeviceId = existingSession?['device_id'] as String?;

      debugPrint('SessionService: Creating login request for staff $staffId from $deviceName');

      final response = await _supabase.from('login_requests').insert({
        'staff_id': staffId,
        'requesting_device_id': deviceId,
        'requesting_device_name': deviceName,
        'current_device_id': currentDeviceId,
        'status': 'pending',
      }).select().single();

      final requestId = response['id'] as int;
      debugPrint('SessionService: Login request created with ID $requestId');
      return requestId;
    } catch (e) {
      debugPrint('SessionService: Error creating login request: $e');
      return null;
    }
  }

  /// Wait for login request approval (called by requesting device)
  /// Returns the result after approval/denial/timeout
  Future<LoginRequestResult> waitForLoginApproval(int requestId, {Duration timeout = const Duration(minutes: 2)}) async {
    final completer = Completer<LoginRequestResult>();

    debugPrint('SessionService: Waiting for approval on request $requestId');

    // Subscribe to changes on this specific request
    final channel = _supabase
        .channel('login_request_$requestId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'login_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: requestId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            debugPrint('SessionService: Login request status changed to: $status');

            if (!completer.isCompleted) {
              if (status == 'approved') {
                completer.complete(LoginRequestResult.approved);
              } else if (status == 'denied') {
                completer.complete(LoginRequestResult.denied);
              } else if (status == 'expired') {
                completer.complete(LoginRequestResult.expired);
              }
            }
          },
        )
        .subscribe();

    // Set timeout
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(LoginRequestResult.expired);
      }
    });

    try {
      final result = await completer.future;
      await _supabase.removeChannel(channel);
      return result;
    } catch (e) {
      await _supabase.removeChannel(channel);
      return LoginRequestResult.error;
    }
  }

  /// Start listening for incoming login requests (called by logged-in device)
  Future<void> startLoginRequestListener({
    required int staffId,
    required LoginRequestCallback onLoginRequest,
  }) async {
    await stopLoginRequestListener();

    _onLoginRequest = onLoginRequest;
    final currentDeviceId = await getDeviceId();

    debugPrint('SessionService: Starting login request listener for staff $staffId');

    _loginRequestChannel = _supabase
        .channel('login_requests_$staffId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'login_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'staff_id',
            value: staffId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final requestingDeviceId = newRecord['requesting_device_id'] as String?;
            final requestingDeviceName = newRecord['requesting_device_name'] as String? ?? 'Unknown Device';
            final requestId = newRecord['id'] as int;
            final status = newRecord['status'] as String?;

            debugPrint('SessionService: Received login request from $requestingDeviceName');

            // Only notify if it's a pending request from a different device
            if (status == 'pending' && requestingDeviceId != currentDeviceId) {
              _onLoginRequest?.call(requestId, requestingDeviceName);
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('SessionService: Login request listener status: $status');
        });
  }

  /// Stop listening for login requests
  Future<void> stopLoginRequestListener() async {
    if (_loginRequestChannel != null) {
      debugPrint('SessionService: Stopping login request listener');
      await _supabase.removeChannel(_loginRequestChannel!);
      _loginRequestChannel = null;
      _onLoginRequest = null;
    }
  }

  /// Approve a login request (called by current device)
  /// This allows the new device to login and logs out the current device
  Future<bool> approveLoginRequest(int requestId) async {
    try {
      debugPrint('SessionService: Approving login request $requestId');

      await _supabase.from('login_requests').update({
        'status': 'approved',
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      return true;
    } catch (e) {
      debugPrint('SessionService: Error approving login request: $e');
      return false;
    }
  }

  /// Deny a login request (called by current device)
  /// This blocks the new device from logging in
  Future<bool> denyLoginRequest(int requestId) async {
    try {
      debugPrint('SessionService: Denying login request $requestId');

      await _supabase.from('login_requests').update({
        'status': 'denied',
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      return true;
    } catch (e) {
      debugPrint('SessionService: Error denying login request: $e');
      return false;
    }
  }

  /// Cancel a pending login request (called by requesting device)
  Future<void> cancelLoginRequest(int requestId) async {
    try {
      await _supabase.from('login_requests').update({
        'status': 'expired',
      }).eq('id', requestId);
    } catch (e) {
      debugPrint('SessionService: Error canceling login request: $e');
    }
  }
}
