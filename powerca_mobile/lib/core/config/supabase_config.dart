/// Supabase Configuration
///
/// Contains Supabase connection details
class SupabaseConfig {
  static const String url = 'https://jacqfogzgzvbjeizljqf.supabase.co';

  // Supabase ANON key (public - safe for client apps)
  // From: https://supabase.com/dashboard/project/jacqfogzgzvbjeizljqf/settings/api
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzA3NDIsImV4cCI6MjA3NzE0Njc0Mn0.MncHuyRmIvZCbHKcIkzq_qYwcqM0bXzWE71gTHPCFCo';

  // Database connection details (for direct PostgreSQL access if needed)
  static const String dbHost = 'db.jacqfogzgzvbjeizljqf.supabase.co';
  static const int dbPort = 5432;
  static const String dbName = 'postgres';
}
