import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job.dart';

/// Repository interface for job data
abstract class JobRepository {
  /// Get all jobs for a staff member
  Future<Either<Failure, List<Job>>> getJobs({
    required int staffId,
    String? status,
    int? limit,
    int? offset,
  });

  /// Get a single job by ID
  Future<Either<Failure, Job>> getJobById(int jobId);

  /// Get jobs count by status
  Future<Either<Failure, Map<String, int>>> getJobsCountByStatus(int staffId);
}
