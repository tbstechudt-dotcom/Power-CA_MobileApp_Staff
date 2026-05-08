import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/comment.dart';
import '../repositories/pinboard_repository.dart';

class GetCommentsUseCase {
  final PinboardRepository repository;

  GetCommentsUseCase(this.repository);

  Future<Either<Failure, List<Comment>>> call(String pinboardItemId) {
    return repository.getComments(pinboardItemId);
  }
}
