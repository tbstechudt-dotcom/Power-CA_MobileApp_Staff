import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/work_diary_entry.dart';
import '../repositories/work_diary_repository.dart';

class UpdateEntryUseCase {
  final WorkDiaryRepository repository;

  UpdateEntryUseCase(this.repository);

  Future<Either<Failure, WorkDiaryEntry>> call(WorkDiaryEntry entry) async {
    return await repository.updateEntry(entry);
  }
}
