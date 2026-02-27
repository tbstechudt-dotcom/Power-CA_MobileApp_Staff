import 'package:equatable/equatable.dart';

/// Events for the home/dashboard feature
abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load dashboard data
class LoadDashboardEvent extends HomeEvent {
  final int staffId;

  const LoadDashboardEvent(this.staffId);

  @override
  List<Object?> get props => [staffId];
}

/// Event to refresh dashboard data
class RefreshDashboardEvent extends HomeEvent {
  final int staffId;

  const RefreshDashboardEvent(this.staffId);

  @override
  List<Object?> get props => [staffId];
}
