import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
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
      // Clear cached staff data
      await localDataSource.clearCachedStaff();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
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
}
