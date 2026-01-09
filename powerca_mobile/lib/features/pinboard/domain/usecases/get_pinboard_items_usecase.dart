import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/pinboard_item.dart';
import '../repositories/pinboard_repository.dart';

class GetPinboardItemsUseCase {
  final PinboardRepository repository;

  GetPinboardItemsUseCase(this.repository);

  Future<Either<Failure, List<PinboardItem>>> call({
    PinboardCategory? category,
  }) {
    return repository.getPinboardItems(category: category);
  }
}
