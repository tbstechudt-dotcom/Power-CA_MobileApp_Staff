import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/pinboard_repository.dart';

class ToggleLikeUseCase {
  final PinboardRepository repository;

  ToggleLikeUseCase(this.repository);

  Future<Either<Failure, void>> call(String pinboardItemId) {
    return repository.toggleLike(pinboardItemId);
  }
}
