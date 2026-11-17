import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns raw exceptions into short, user-friendly messages.
///
/// ```dart
/// } catch (e) {
///   setState(() => _error = ErrorMessages.friendly(e));
/// }
/// ```
class ErrorMessages {
  static const noInternet =
      'No internet connection. Check your network and try again.';
  static const timedOut =
      'The request timed out. Check your connection and try again.';
  static const server =
      'The server is having trouble right now. Please try again shortly.';
  static const generic = 'Something went wrong. Please try again.';

  /// True when [error] looks like a connectivity problem.
  static bool isNetwork(Object error) {
    if (error is SocketException || error is HttpException) return true;
    final s = error.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('network is unreachable') ||
        s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('connection closed') ||
        s.contains('clientexception') ||
        s.contains('xmlhttprequest error') ||
        s.contains('no address associated');
  }

  /// True when [error] is a timeout.
  static bool isTimeout(Object error) {
    if (error is TimeoutException) return true;
    final s = error.toString().toLowerCase();
    return s.contains('timeoutexception') || s.contains('timed out');
  }

  static String friendly(Object? error) {
    if (error == null) return generic;
    if (isTimeout(error)) return timedOut;
    if (isNetwork(error)) return noInternet;
    if (error is PostgrestException) {
      final code = int.tryParse(error.code ?? '');
      if (code != null && code >= 500) return server;
      return generic;
    }
    if (error is AuthException) {
      return error.message.isNotEmpty ? error.message : generic;
    }
    final s = error.toString().toLowerCase();
    if (s.contains('503') || s.contains('502') || s.contains('500')) {
      return server;
    }
    return generic;
  }
}
