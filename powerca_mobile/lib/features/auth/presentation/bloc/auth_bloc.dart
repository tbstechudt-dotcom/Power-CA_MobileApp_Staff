import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/priority_service.dart';
import '../../domain/usecases/get_current_staff_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Authentication BLoC
///
/// Manages authentication state and business logic
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignInUseCase signInUseCase;
  final SignOutUseCase signOutUseCase;
  final GetCurrentStaffUseCase getCurrentStaffUseCase;

  AuthBloc({
    required this.signInUseCase,
    required this.signOutUseCase,
    required this.getCurrentStaffUseCase,
  }) : super(const AuthInitial()) {
    // Handle Sign In
    on<SignInRequested>(_onSignInRequested);

    // Handle Sign Out
    on<SignOutRequested>(_onSignOutRequested);

    // Handle Auth Status Check
    on<AuthStatusChecked>(_onAuthStatusChecked);

    // Handle Current Staff Request
    on<CurrentStaffRequested>(_onCurrentStaffRequested);
  }

  /// Handle Sign In Request
  Future<void> _onSignInRequested(
    SignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await signInUseCase(
      username: event.username,
      password: event.password,
    );

    await result.fold(
      (failure) async => emit(AuthError(failure.message)),
      (staff) async {
        // Set staff ID in PriorityService for priority jobs persistence
        await PriorityService.setCurrentStaffId(staff.staffId);
        emit(Authenticated(staff));
      },
    );
  }

  /// Handle Sign Out Request
  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await signOutUseCase();

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(const Unauthenticated()),
    );
  }

  /// Handle Auth Status Check
  Future<void> _onAuthStatusChecked(
    AuthStatusChecked event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await getCurrentStaffUseCase();

    result.fold(
      (failure) => emit(const Unauthenticated()),
      (staff) async {
        if (staff != null) {
          // Set staff ID in PriorityService for priority jobs persistence
          await PriorityService.setCurrentStaffId(staff.staffId);
          emit(Authenticated(staff));
        } else {
          emit(const Unauthenticated());
        }
      },
    );
  }

  /// Handle Current Staff Request
  Future<void> _onCurrentStaffRequested(
    CurrentStaffRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await getCurrentStaffUseCase();

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (staff) async {
        if (staff != null) {
          // Set staff ID in PriorityService for priority jobs persistence
          await PriorityService.setCurrentStaffId(staff.staffId);
          emit(Authenticated(staff));
        } else {
          emit(const Unauthenticated());
        }
      },
    );
  }
}
