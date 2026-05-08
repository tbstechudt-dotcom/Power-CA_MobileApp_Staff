import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/work_diary_entry.dart';
import '../repositories/work_diary_repository.dart';

class GetEntriesByStaffUseCase {
  final WorkDiaryRepository repository;

  GetEntriesByStaffUseCase(this.repository);

  Future<Either<Failure, List<WorkDiaryEntry>>> call({
    required int staffId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    return await repository.getEntriesByStaff(
      staffId: staffId,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      offset: offset,
    );
  }
}
