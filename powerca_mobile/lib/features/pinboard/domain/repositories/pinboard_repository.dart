import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/comment.dart';
import '../entities/pinboard_item.dart';

abstract class PinboardRepository {
  Future<Either<Failure, List<PinboardItem>>> getPinboardItems({
    PinboardCategory? category,
  });

  Future<Either<Failure, PinboardItem>> getPinboardItemById(String id);

  Future<Either<Failure, List<Comment>>> getComments(String pinboardItemId);

  Future<Either<Failure, Comment>> addComment({
    required String pinboardItemId,
    required String content,
  });

  Future<Either<Failure, void>> toggleLike(String pinboardItemId);

  Future<Either<Failure, PinboardItem>> createPinboardItem({
    required String title,
    required String description,
    String? imageUrl,
    String? location,
    required DateTime eventDate,
    required PinboardCategory category,
  });
}
