import 'package:equatable/equatable.dart';

/// Base Auth Event
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Sign In Event
class SignInRequested extends AuthEvent {
  final String username;
  final String password;

  const SignInRequested({
    required this.username,
    required this.password,
  });

  @override
  List<Object?> get props => [username, password];
}

/// Sign Out Event
class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}

/// Check Auth Status Event
class AuthStatusChecked extends AuthEvent {
  const AuthStatusChecked();
}

/// Load Current Staff Event
class CurrentStaffRequested extends AuthEvent {
  const CurrentStaffRequested();
}
