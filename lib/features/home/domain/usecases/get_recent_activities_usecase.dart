import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/recent_activity.dart';
import '../repositories/home_repository.dart';

/// Use case for getting recent activities
@lazySingleton
class GetRecentActivitiesUseCase {
  final HomeRepository repository;

  GetRecentActivitiesUseCase(this.repository);

  Future<Either<Failure, List<RecentActivity>>> call(int staffId, {int limit = 10}) {
    return repository.getRecentActivities(staffId, limit: limit);
  }
}
