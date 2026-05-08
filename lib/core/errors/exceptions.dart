/// Server Exception
/// Thrown when server returns an error
class ServerException implements Exception {
  final String message;
  final int? statusCode;

  ServerException(this.message, [this.statusCode]);

  @override
  String toString() => 'ServerException: $message (Status: $statusCode)';
}

/// Unauthorized Exception
/// Thrown when authentication fails or token is invalid
class UnauthorizedException implements Exception {
  final String message;

  UnauthorizedException(this.message);

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// Network Exception
/// Thrown when there's no internet connection
class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

/// Cache Exception
/// Thrown when local storage operations fail
class CacheException implements Exception {
  final String message;

  CacheException(this.message);

  @override
  String toString() => 'CacheException: $message';
}

/// Validation Exception
/// Thrown when input validation fails
class ValidationException implements Exception {
  final String message;
  final Map<String, String>? errors;

  ValidationException(this.message, [this.errors]);

  @override
  String toString() => 'ValidationException: $message';
}

/// Timeout Exception
/// Thrown when a request times out
class TimeoutException implements Exception {
  final String message;

  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
