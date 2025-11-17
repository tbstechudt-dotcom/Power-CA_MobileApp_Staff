import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/network_info.dart';

// Auth
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_current_staff_usecase.dart';
import '../../features/auth/domain/usecases/sign_in_usecase.dart';
import '../../features/auth/domain/usecases/sign_out_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

// Home
import '../../features/home/data/datasources/home_remote_datasource.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/domain/usecases/get_dashboard_stats_usecase.dart';
import '../../features/home/domain/usecases/get_recent_activities_usecase.dart';
import '../../features/home/presentation/bloc/home_bloc.dart';

// Work Diary
import '../../features/work_diary/data/datasources/work_diary_remote_datasource.dart';
import '../../features/work_diary/data/repositories/work_diary_repository_impl.dart';
import '../../features/work_diary/domain/repositories/work_diary_repository.dart';
import '../../features/work_diary/domain/usecases/get_entries_by_job_usecase.dart';
import '../../features/work_diary/domain/usecases/get_entries_by_staff_usecase.dart';
import '../../features/work_diary/domain/usecases/add_entry_usecase.dart';
import '../../features/work_diary/domain/usecases/update_entry_usecase.dart';
import '../../features/work_diary/domain/usecases/delete_entry_usecase.dart';
import '../../features/work_diary/domain/usecases/get_total_hours_by_job_usecase.dart';
import '../../features/work_diary/presentation/bloc/work_diary_bloc.dart';

final getIt = GetIt.instance;

/// Initialize all dependencies
/// Call this in main() before runApp()
Future<void> configureDependencies() async {
  // External Dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  const secureStorage = FlutterSecureStorage();
  getIt.registerSingleton<FlutterSecureStorage>(secureStorage);

  final connectivity = Connectivity();
  getIt.registerSingleton<Connectivity>(connectivity);

  // Network Info
  getIt.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(getIt<Connectivity>()),
  );

  // Supabase Client (already initialized in main.dart)
  getIt.registerSingleton<SupabaseClient>(Supabase.instance.client);

  // ========================================
  // AUTH FEATURE
  // ========================================

  // Data Sources
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      supabaseClient: getIt<SupabaseClient>(),
    ),
  );

  getIt.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(
      sharedPreferences: getIt<SharedPreferences>(),
    ),
  );

  // Repository
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt<AuthRemoteDataSource>(),
      localDataSource: getIt<AuthLocalDataSource>(),
    ),
  );

  // Use Cases
  getIt.registerLazySingleton<SignInUseCase>(
    () => SignInUseCase(getIt<AuthRepository>()),
  );

  getIt.registerLazySingleton<SignOutUseCase>(
    () => SignOutUseCase(getIt<AuthRepository>()),
  );

  getIt.registerLazySingleton<GetCurrentStaffUseCase>(
    () => GetCurrentStaffUseCase(getIt<AuthRepository>()),
  );

  // BLoC
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(
      signInUseCase: getIt<SignInUseCase>(),
      signOutUseCase: getIt<SignOutUseCase>(),
      getCurrentStaffUseCase: getIt<GetCurrentStaffUseCase>(),
    ),
  );

  // ========================================
  // HOME FEATURE
  // ========================================

  // Data Sources
  getIt.registerLazySingleton<HomeRemoteDataSource>(
    () => HomeRemoteDataSourceImpl(
      supabaseClient: getIt<SupabaseClient>(),
    ),
  );

  // Repository
  getIt.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(
      remoteDataSource: getIt<HomeRemoteDataSource>(),
    ),
  );

  // Use Cases
  getIt.registerLazySingleton<GetDashboardStatsUseCase>(
    () => GetDashboardStatsUseCase(getIt<HomeRepository>()),
  );

  getIt.registerLazySingleton<GetRecentActivitiesUseCase>(
    () => GetRecentActivitiesUseCase(getIt<HomeRepository>()),
  );

  // BLoC
  getIt.registerFactory<HomeBloc>(
    () => HomeBloc(
      getDashboardStats: getIt<GetDashboardStatsUseCase>(),
      getRecentActivities: getIt<GetRecentActivitiesUseCase>(),
    ),
  );

  // ========================================
  // WORK DIARY FEATURE
  // ========================================

  // Data Sources
  getIt.registerLazySingleton<WorkDiaryRemoteDataSource>(
    () => WorkDiaryRemoteDataSourceImpl(
      supabaseClient: getIt<SupabaseClient>(),
    ),
  );

  // Repository
  getIt.registerLazySingleton<WorkDiaryRepository>(
    () => WorkDiaryRepositoryImpl(
      remoteDataSource: getIt<WorkDiaryRemoteDataSource>(),
    ),
  );

  // Use Cases
  getIt.registerLazySingleton<GetEntriesByJobUseCase>(
    () => GetEntriesByJobUseCase(getIt<WorkDiaryRepository>()),
  );

  getIt.registerLazySingleton<GetEntriesByStaffUseCase>(
    () => GetEntriesByStaffUseCase(getIt<WorkDiaryRepository>()),
  );

  getIt.registerLazySingleton<AddEntryUseCase>(
    () => AddEntryUseCase(getIt<WorkDiaryRepository>()),
  );

  getIt.registerLazySingleton<UpdateEntryUseCase>(
    () => UpdateEntryUseCase(getIt<WorkDiaryRepository>()),
  );

  getIt.registerLazySingleton<DeleteEntryUseCase>(
    () => DeleteEntryUseCase(getIt<WorkDiaryRepository>()),
  );

  getIt.registerLazySingleton<GetTotalHoursByJobUseCase>(
    () => GetTotalHoursByJobUseCase(getIt<WorkDiaryRepository>()),
  );

  // BLoC
  getIt.registerFactory<WorkDiaryBloc>(
    () => WorkDiaryBloc(
      getEntriesByJob: getIt<GetEntriesByJobUseCase>(),
      addEntry: getIt<AddEntryUseCase>(),
      updateEntry: getIt<UpdateEntryUseCase>(),
      deleteEntry: getIt<DeleteEntryUseCase>(),
      getTotalHoursByJob: getIt<GetTotalHoursByJobUseCase>(),
    ),
  );

}

/// Reset all dependencies (useful for testing)
Future<void> resetDependencies() async {
  await getIt.reset();
}
