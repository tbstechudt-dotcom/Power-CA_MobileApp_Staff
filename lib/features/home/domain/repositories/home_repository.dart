import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/dashboard_stats.dart';
import '../entities/recent_activity.dart';

/// Repository interface for home/dashboard data
abstract class HomeRepository {
  /// Get dashboard statistics for the current user
  Future<Either<Failure, DashboardStats>> getDashboardStats(int staffId);

  /// Get recent activities for the current user
  Future<Either<Failure, List<RecentActivity>>> getRecentActivities(int staffId, {int limit = 10});
}
