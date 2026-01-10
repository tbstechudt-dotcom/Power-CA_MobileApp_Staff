import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/session_service.dart';
import '../../domain/entities/staff.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/staff_model.dart';

/// Authentication Repository Implementation
///
/// Implements authentication business logic using remote and local data sources
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  final _sessionService = SessionService();

  @override
  Future<Either<Failure, Staff>> signIn({
    required String username,
    required String password,
  }) async {
    try {
      // Authenticate with Supabase
      final staffModel = await remoteDataSource.signIn(
        username: username,
        password: password,
      );

      // Cache the authenticated staff
      await localDataSource.cacheStaff(staffModel);

      // NOTE: Session registration is now separate via registerDeviceSession()
      // This allows for permission-based login where existing device must approve
      debugPrint('AuthRepository: Staff authenticated - ${staffModel.staffId}');

      // Return the staff entity
      return Right(staffModel.toEntity());
    } on Exception catch (e) {
      // Map exceptions to specific failures
      final message = e.toString().toLowerCase();

      if (message.contains('user not found') || message.contains('username not found')) {
        return const Left(UserNotFoundFailure());
      } else if (message.contains('invalid password') ||
                 message.contains('invalid username or password') ||
                 message.contains('incorrect password') ||
                 message.contains('wrong password')) {
        return const Left(InvalidCredentialsFailure());
      } else if (message.contains('inactive') || message.contains('deactivated')) {
        return const Left(InactiveUserFailure());
      } else if (message.contains('network') || message.contains('connection')) {
        return const Left(NetworkFailure('Unable to connect. Please check your internet connection.'));
      } else {
        // Generic auth error - provide user-friendly message
        return const Left(AuthenticationFailure('Login failed. Please check your credentials and try again.'));
      }
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      // Get current staff to clear their session
      final cachedStaff = await localDataSource.getCachedStaff();
      if (cachedStaff != null) {
        await _sessionService.clearSession(cachedStaff.staffId);
        debugPrint('AuthRepository: Session cleared for staff ${cachedStaff.staffId}');
      }

      // Clear cached staff data
      await localDataSource.clearCachedStaff();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  /// Validate if current session is still active on this device
  /// Returns error message if session was invalidated by another device login
  @override
  Future<String?> validateSession() async {
    try {
      final cachedStaff = await localDataSource.getCachedStaff();
      if (cachedStaff == null) return null;

      return await _sessionService.validateSession(cachedStaff.staffId);
    } catch (e) {
      debugPrint('AuthRepository: Error validating session: $e');
      return null;
    }
  }

  @override
  Future<Either<Failure, Staff?>> getCurrentStaff() async {
    try {
      // Get cached staff
      final staffModel = await localDataSource.getCachedStaff();

      if (staffModel == null) {
        return const Right(null);
      }

      return Right(staffModel.toEntity());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<bool> isSignedIn() async {
    try {
      return await localDataSource.isStaffCached();
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Either<Failure, void>> saveStaffSession(Staff staff) async {
    try {
      final staffModel = StaffModel.fromEntity(staff);
      await localDataSource.cacheStaff(staffModel);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearStaffSession() async {
    try {
      await localDataSource.clearCachedStaff();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Map<String, dynamic>?> checkExistingSession(int staffId) async {
    try {
      return await _sessionService.checkExistingSession(staffId);
    } catch (e) {
      debugPrint('AuthRepository: Error checking existing session: $e');
      return null;
    }
  }

  @override
  Future<int?> createLoginRequest(int staffId) async {
    try {
      return await _sessionService.createLoginRequest(staffId);
    } catch (e) {
      debugPrint('AuthRepository: Error creating login request: $e');
      return null;
    }
  }

  @override
  Future<String> waitForLoginApproval(int requestId) async {
    try {
      final result = await _sessionService.waitForLoginApproval(requestId);
      return result.name; // Returns 'approved', 'denied', 'expired', or 'error'
    } catch (e) {
      debugPrint('AuthRepository: Error waiting for approval: $e');
      return 'error';
    }
  }

  @override
  Future<void> cancelLoginRequest(int requestId) async {
    try {
      await _sessionService.cancelLoginRequest(requestId);
    } catch (e) {
      debugPrint('AuthRepository: Error canceling login request: $e');
    }
  }

  @override
  Future<bool> registerDeviceSession(int staffId) async {
    try {
      final result = await _sessionService.registerSession(staffId);
      debugPrint('AuthRepository: Device session registered for staff $staffId: $result');
      return result;
    } catch (e) {
      debugPrint('AuthRepository: Error registering device session: $e');
      return false;
    }
  }
}
