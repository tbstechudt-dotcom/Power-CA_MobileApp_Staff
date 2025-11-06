import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/work_diary_entry.dart';
import '../repositories/work_diary_repository.dart';

class GetEntriesByJobUseCase {
  final WorkDiaryRepository repository;

  GetEntriesByJobUseCase(this.repository);

  Future<Either<Failure, List<WorkDiaryEntry>>> call({
    required int jobId,
    int? limit,
    int? offset,
  }) async {
    return await repository.getEntriesByJob(
      jobId: jobId,
      limit: limit,
      offset: offset,
    );
  }
}
