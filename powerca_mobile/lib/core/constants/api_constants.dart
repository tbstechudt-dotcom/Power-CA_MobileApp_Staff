/// API Constants for PowerCA Mobile
///
/// Contains all API endpoints, base URLs, and API-related constants
class ApiConstants {
  // Supabase Configuration
  static const String supabaseUrl = 'https://jacqfogzgzvbjeizljqf.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key-here'; // TODO: Add from .env

  // Timeout
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Table Names (Supabase)
  static const String tableStaff = 'mbstaff';
  static const String tableJobs = 'jobshead';
  static const String tableTasks = 'jobtasks';
  static const String tableTaskChecklist = 'taskchecklist';
  static const String tableWorkDiary = 'workdiary';
  static const String tableClients = 'climaster';
  static const String tableClientUnits = 'cliunimaster';
  static const String tableReminders = 'reminder';
  static const String tableReminderDetails = 'remdetail';
  static const String tableLeaveRequests = 'learequest';
  static const String tableOrganizations = 'orgmaster';
  static const String tableLocations = 'locmaster';
  static const String tableContacts = 'conmaster';

  // Sync Metadata
  static const String tableSyncMetadata = '_sync_metadata';
  static const String tableSyncLog = '_sync_log';
}
