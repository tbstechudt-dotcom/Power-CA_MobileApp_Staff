import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/work_diary_entry.dart';
import '../repositories/work_diary_repository.dart';

class AddEntryUseCase {
  final WorkDiaryRepository repository;

  AddEntryUseCase(this.repository);

  Future<Either<Failure, WorkDiaryEntry>> call(WorkDiaryEntry entry) async {
    return await repository.addEntry(entry);
  }
}
