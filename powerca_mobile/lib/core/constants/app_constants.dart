/// Application Constants
class AppConstants {
  static const String appName = 'PowerCA';
  static const String appTagline = 'Auditor WorkLog';
  static const String appVersion = '1.0.0';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Date Formats
  static const String dateFormat = 'dd-MM-yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd-MM-yyyy HH:mm';
  static const String displayDateFormat = 'dd MMM yyyy';
  static const String apiDateFormat = 'yyyy-MM-dd';

  // Job Status
  static const String jobStatusPending = 'P';
  static const String jobStatusInProgress = 'I';
  static const String jobStatusCompleted = 'C';
  static const String jobStatusOnHold = 'H';

  // Task Status
  static const String taskStatusPending = 'P';
  static const String taskStatusInProgress = 'I';
  static const String taskStatusCompleted = 'C';

  // Staff Types
  static const int staffTypeAdmin = 0;
  static const int staffTypeSenior = 1;
  static const int staffTypeJunior = 2;

  // Data Source
  static const String sourceDesktop = 'D'; // Desktop-created
  static const String sourceMobile = 'M';  // Mobile-created
  static const String sourceSynced = 'S';  // Synced

  // Error Messages
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'No internet connection. Please check your network.';
  static const String errorTimeout = 'Request timeout. Please try again.';
  static const String errorUnauthorized = 'Session expired. Please login again.';
  static const String errorServerError = 'Server error. Please try again later.';

  // Success Messages
  static const String successLogin = 'Login successful';
  static const String successLogout = 'Logged out successfully';
  static const String successDataSaved = 'Data saved successfully';
  static const String successDataDeleted = 'Data deleted successfully';
}

/// Storage Keys for SharedPreferences and SecureStorage
class StorageConstants {
  // Secure Storage Keys (flutter_secure_storage)
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';

  // SharedPreferences Keys
  static const String keyUserId = 'user_id';
  static const String keyStaffId = 'staff_id';
  static const String keyUserName = 'user_name';
  static const String keyUserEmail = 'user_email';
  static const String keyStaffType = 'staff_type';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyLastSyncTime = 'last_sync_time';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';

  // Cache Keys
  static const String cacheKeyJobs = 'cache_jobs';
  static const String cacheKeyClients = 'cache_clients';
  static const String cacheKeyDashboard = 'cache_dashboard';
}

/// App Routes
class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';

  static const String dashboard = '/dashboard';

  static const String jobs = '/jobs';
  static const String jobDetail = '/jobs/:id';
  static const String createJob = '/jobs/create';

  static const String workDiary = '/work-diary';
  static const String logTime = '/work-diary/log';

  static const String clients = '/clients';
  static const String clientDetail = '/clients/:id';

  static const String reminders = '/reminders';
  static const String calendar = '/calendar';

  static const String team = '/team';
  static const String staffProfile = '/staff/:id';

  static const String leave = '/leave';
  static const String applyLeave = '/leave/apply';

  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String syncDashboard = '/settings/sync';
}
