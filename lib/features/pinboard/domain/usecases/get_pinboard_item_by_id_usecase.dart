import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/pinboard_item.dart';
import '../repositories/pinboard_repository.dart';

class GetPinboardItemByIdUseCase {
  final PinboardRepository repository;

  GetPinboardItemByIdUseCase(this.repository);

  Future<Either<Failure, PinboardItem>> call(String id) {
    return repository.getPinboardItemById(id);
  }
}
