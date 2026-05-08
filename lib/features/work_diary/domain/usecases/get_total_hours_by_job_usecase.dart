import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/work_diary_repository.dart';

class GetTotalHoursByJobUseCase {
  final WorkDiaryRepository repository;

  GetTotalHoursByJobUseCase(this.repository);

  Future<Either<Failure, double>> call(int jobId) async {
    return await repository.getTotalHoursByJob(jobId);
  }
}
