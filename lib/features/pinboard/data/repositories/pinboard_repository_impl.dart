import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/pinboard_item.dart';
import '../../domain/repositories/pinboard_repository.dart';
import '../datasources/pinboard_remote_datasource.dart';

class PinboardRepositoryImpl implements PinboardRepository {
  final PinboardRemoteDataSource remoteDataSource;
  final SupabaseClient supabaseClient;

  PinboardRepositoryImpl({
    required this.remoteDataSource,
    required this.supabaseClient,
  });

  @override
  Future<Either<Failure, List<PinboardItem>>> getPinboardItems({
    PinboardCategory? category,
  }) async {
    try {
      final items = await remoteDataSource.getPinboardItems(
        category: category,
      );
      return Right(items);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PinboardItem>> getPinboardItemById(String id) async {
    try {
      final item = await remoteDataSource.getPinboardItemById(id);
      return Right(item);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Comment>>> getComments(
      String pinboardItemId) async {
    try {
      final comments = await remoteDataSource.getComments(pinboardItemId);
      return Right(comments);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Comment>> addComment({
    required String pinboardItemId,
    required String content,
  }) async {
    try {
      final currentUser = supabaseClient.auth.currentUser;
      if (currentUser == null) {
        return const Left(
            AuthenticationFailure('User not authenticated'));
      }

      // Get user details from mbstaff table
      final userResponse = await supabaseClient
          .from('mbstaff')
          .select('staff_name')
          .eq('email', currentUser.email ?? '')
          .maybeSingle();

      final authorName =
          userResponse?['staff_name'] ?? currentUser.email ?? 'Anonymous';

      final comment = await remoteDataSource.addComment(
        pinboardItemId: pinboardItemId,
        content: content,
        authorId: currentUser.id,
        authorName: authorName,
      );

      return Right(comment);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleLike(String pinboardItemId) async {
    try {
      final currentUser = supabaseClient.auth.currentUser;
      if (currentUser == null) {
        return const Left(
            AuthenticationFailure('User not authenticated'));
      }

      await remoteDataSource.toggleLike(
        pinboardItemId: pinboardItemId,
        userId: currentUser.id,
      );

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PinboardItem>> createPinboardItem({
    required String title,
    required String description,
    String? imageUrl,
    String? location,
    required DateTime eventDate,
    required PinboardCategory category,
  }) async {
    try {
      final currentUser = supabaseClient.auth.currentUser;
      if (currentUser == null) {
        return const Left(
            AuthenticationFailure('User not authenticated'));
      }

      // Get user details from mbstaff table
      final userResponse = await supabaseClient
          .from('mbstaff')
          .select('staff_name')
          .eq('email', currentUser.email ?? '')
          .maybeSingle();

      final authorName =
          userResponse?['staff_name'] ?? currentUser.email ?? 'Anonymous';

      final item = await remoteDataSource.createPinboardItem(
        title: title,
        description: description,
        imageUrl: imageUrl,
        location: location,
        eventDate: eventDate,
        category: category,
        authorId: currentUser.id,
        authorName: authorName,
      );

      return Right(item);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
