import 'package:equatable/equatable.dart';

/// Base Failure class
/// All failures extend this class
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

/// Server Failure
/// When the server returns an error (5xx, 4xx)
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Network Failure
/// When there's no internet connection
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Authentication Failure
/// When authentication fails (login, token refresh, etc.)
class AuthenticationFailure extends Failure {
  const AuthenticationFailure(super.message);
}

/// Cache Failure
/// When local storage operations fail
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Validation Failure
/// When input validation fails
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Timeout Failure
/// When a request times out
class TimeoutFailure extends Failure {
  const TimeoutFailure(super.message);
}

/// Permission Failure
/// When permission is denied (camera, storage, etc.)
class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

/// Invalid Credentials Failure
/// When username or password is incorrect
class InvalidCredentialsFailure extends AuthenticationFailure {
  const InvalidCredentialsFailure() : super('Incorrect username or password. Please check your credentials and try again.');
}

/// User Not Found Failure
/// When the user doesn't exist in the system
class UserNotFoundFailure extends AuthenticationFailure {
  const UserNotFoundFailure() : super('Username not found. Please check your username and try again.');
}

/// Inactive User Failure
/// When user account is deactivated
class InactiveUserFailure extends AuthenticationFailure {
  const InactiveUserFailure() : super('User account is inactive');
}

/// Session Expired Failure
/// When user session has expired
class SessionExpiredFailure extends AuthenticationFailure {
  const SessionExpiredFailure() : super('Session expired. Please sign in again');
}

/// Unauthorized Failure
/// When user doesn't have permission for the action
class UnauthorizedFailure extends AuthenticationFailure {
  const UnauthorizedFailure() : super('Unauthorized access');
}
