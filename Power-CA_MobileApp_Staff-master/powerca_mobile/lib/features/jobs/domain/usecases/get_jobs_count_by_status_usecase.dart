import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/job_repository.dart';

/// Use case for getting job counts by status
@lazySingleton
class GetJobsCountByStatusUseCase {
  final JobRepository repository;

  GetJobsCountByStatusUseCase(this.repository);

  Future<Either<Failure, Map<String, int>>> call(int staffId) {
    return repository.getJobsCountByStatus(staffId);
  }
}
