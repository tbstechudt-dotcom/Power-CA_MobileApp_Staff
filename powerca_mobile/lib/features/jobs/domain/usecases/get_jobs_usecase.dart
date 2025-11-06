import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job.dart';
import '../repositories/job_repository.dart';

/// Use case for getting jobs list
@lazySingleton
class GetJobsUseCase {
  final JobRepository repository;

  GetJobsUseCase(this.repository);

  Future<Either<Failure, List<Job>>> call({
    required int staffId,
    String? status,
    int? limit,
    int? offset,
  }) {
    return repository.getJobs(
      staffId: staffId,
      status: status,
      limit: limit,
      offset: offset,
    );
  }
}
