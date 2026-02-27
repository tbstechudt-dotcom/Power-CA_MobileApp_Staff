import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/usecases/get_dashboard_stats_usecase.dart';
import '../../domain/usecases/get_recent_activities_usecase.dart';
import 'home_event.dart';
import 'home_state.dart';

@injectable
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetDashboardStatsUseCase getDashboardStats;
  final GetRecentActivitiesUseCase getRecentActivities;

  HomeBloc({
    required this.getDashboardStats,
    required this.getRecentActivities,
  }) : super(HomeInitial()) {
    on<LoadDashboardEvent>(_onLoadDashboard);
    on<RefreshDashboardEvent>(_onRefreshDashboard);
  }

  Future<void> _onLoadDashboard(
    LoadDashboardEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoading());
    await _loadDashboardData(event.staffId, emit);
  }

  Future<void> _onRefreshDashboard(
    RefreshDashboardEvent event,
    Emitter<HomeState> emit,
  ) async {
    // Don't show loading indicator for refresh
    await _loadDashboardData(event.staffId, emit);
  }

  Future<void> _loadDashboardData(
    int staffId,
    Emitter<HomeState> emit,
  ) async {
    final statsResult = await getDashboardStats(staffId);
    final activitiesResult = await getRecentActivities(staffId);

    statsResult.fold(
      (failure) => emit(HomeError(failure.message)),
      (stats) {
        activitiesResult.fold(
          (failure) => emit(HomeError(failure.message)),
          (activities) => emit(
            HomeLoaded(
              stats: stats,
              activities: activities,
            ),
          ),
        );
      },
    );
  }
}
