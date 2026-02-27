import 'package:equatable/equatable.dart';
import '../../domain/entities/staff.dart';

/// Base Auth State
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial State
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading State
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Authenticated State
class Authenticated extends AuthState {
  final Staff staff;

  const Authenticated(this.staff);

  @override
  List<Object?> get props => [staff];
}

/// Unauthenticated State
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// Auth Error State
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
