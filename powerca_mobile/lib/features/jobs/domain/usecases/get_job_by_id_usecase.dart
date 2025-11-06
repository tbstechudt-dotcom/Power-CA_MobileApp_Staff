import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job.dart';
import '../repositories/job_repository.dart';

/// Use case for getting a single job by ID
@lazySingleton
class GetJobByIdUseCase {
  final JobRepository repository;

  GetJobByIdUseCase(this.repository);

  Future<Either<Failure, Job>> call(int jobId) {
    return repository.getJobById(jobId);
  }
}
