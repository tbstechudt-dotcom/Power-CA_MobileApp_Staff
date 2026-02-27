import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/comment.dart';
import '../repositories/pinboard_repository.dart';

class AddCommentUseCase {
  final PinboardRepository repository;

  AddCommentUseCase(this.repository);

  Future<Either<Failure, Comment>> call({
    required String pinboardItemId,
    required String content,
  }) {
    return repository.addComment(
      pinboardItemId: pinboardItemId,
      content: content,
    );
  }
}
