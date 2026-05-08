import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/dashboard_stats.dart';
import '../repositories/home_repository.dart';

/// Use case for getting dashboard statistics
@lazySingleton
class GetDashboardStatsUseCase {
  final HomeRepository repository;

  GetDashboardStatsUseCase(this.repository);

  Future<Either<Failure, DashboardStats>> call(int staffId) {
    return repository.getDashboardStats(staffId);
  }
}
