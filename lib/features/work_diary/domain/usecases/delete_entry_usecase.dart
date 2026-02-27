import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/work_diary_repository.dart';

class DeleteEntryUseCase {
  final WorkDiaryRepository repository;

  DeleteEntryUseCase(this.repository);

  Future<Either<Failure, void>> call(int wdId) async {
    return await repository.deleteEntry(wdId);
  }
}
