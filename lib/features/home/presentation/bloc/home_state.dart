import 'package:equatable/equatable.dart';

import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/recent_activity.dart';

/// States for the home/dashboard feature
abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class HomeInitial extends HomeState {}

/// Loading dashboard data
class HomeLoading extends HomeState {}

/// Dashboard data loaded successfully
class HomeLoaded extends HomeState {
  final DashboardStats stats;
  final List<RecentActivity> activities;

  const HomeLoaded({
    required this.stats,
    required this.activities,
  });

  @override
  List<Object?> get props => [stats, activities];
}

/// Error loading dashboard data
class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}
