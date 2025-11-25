import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to manage priority job selections for staff
/// Priority jobs are stored in Supabase database for persistence across sessions
/// Falls back to local storage if database fails
class PriorityService {
  static const String _priorityJobsKey = 'priority_job_ids';
  static const String _staffIdKey = 'current_staff_id';

  /// Get the Supabase client
  static SupabaseClient get _supabase => Supabase.instance.client;

  /// Get current staff ID from local storage
  static Future<int?> _getCurrentStaffId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_staffIdKey);
  }

  /// Set current staff ID (call this when user logs in)
  static Future<void> setCurrentStaffId(int staffId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_staffIdKey, staffId);
  }

  /// Get all priority job IDs for the current staff from database
  static Future<Set<int>> getPriorityJobIds() async {
    try {
      final staffId = await _getCurrentStaffId();
      if (staffId == null) {
        debugPrint('PriorityService: No staff ID found, returning empty set');
        return {};
      }

      // Get jobs where is_priority = true for the current staff
      final response = await _supabase
          .from('jobshead')
          .select('job_id')
          .eq('sporg_id', staffId)
          .eq('is_priority', true);

      final jobIds = (response as List)
          .map((row) => row['job_id'] as int)
          .toSet();

      debugPrint('PriorityService: Loaded ${jobIds.length} priority jobs from database for staff $staffId');
      return jobIds;
    } catch (e) {
      debugPrint('PriorityService: Error loading from database: $e');
      // Fall back to local storage
      return _getLocalPriorityJobIds();
    }
  }

  /// Get priority job IDs from local storage (fallback)
  static Future<Set<int>> _getLocalPriorityJobIds() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jobIds = prefs.getStringList(_priorityJobsKey);
    if (jobIds == null) return {};
    return jobIds.map((id) => int.parse(id)).toSet();
  }

  /// Save priority job IDs to local storage (backup)
  static Future<void> _saveLocalPriorityJobIds(Set<int> jobIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _priorityJobsKey,
      jobIds.map((id) => id.toString()).toList(),
    );
  }

  /// Add a job to priority list
  static Future<void> addPriorityJob(int jobId) async {
    try {
      // Update is_priority = true in jobshead table
      await _supabase
          .from('jobshead')
          .update({'is_priority': true})
          .eq('job_id', jobId);

      debugPrint('PriorityService: Set is_priority=true for job $jobId');

      // Also save to local storage as backup
      final jobIds = await getPriorityJobIds();
      jobIds.add(jobId);
      await _saveLocalPriorityJobIds(jobIds);
    } catch (e) {
      debugPrint('PriorityService: Error adding priority: $e');
      // Fall back to local storage only
      final prefs = await SharedPreferences.getInstance();
      final jobIds = await _getLocalPriorityJobIds();
      jobIds.add(jobId);
      await prefs.setStringList(
        _priorityJobsKey,
        jobIds.map((id) => id.toString()).toList(),
      );
    }
  }

  /// Remove a job from priority list
  static Future<void> removePriorityJob(int jobId) async {
    try {
      // Update is_priority = false in jobshead table
      await _supabase
          .from('jobshead')
          .update({'is_priority': false})
          .eq('job_id', jobId);

      debugPrint('PriorityService: Set is_priority=false for job $jobId');

      // Also update local storage
      final jobIds = await getPriorityJobIds();
      jobIds.remove(jobId);
      await _saveLocalPriorityJobIds(jobIds);
    } catch (e) {
      debugPrint('PriorityService: Error removing priority: $e');
      // Fall back to local storage only
      final prefs = await SharedPreferences.getInstance();
      final jobIds = await _getLocalPriorityJobIds();
      jobIds.remove(jobId);
      await prefs.setStringList(
        _priorityJobsKey,
        jobIds.map((id) => id.toString()).toList(),
      );
    }
  }

  /// Toggle priority status for a job
  static Future<bool> togglePriorityJob(int jobId) async {
    final jobIds = await getPriorityJobIds();
    if (jobIds.contains(jobId)) {
      await removePriorityJob(jobId);
      return false;
    } else {
      await addPriorityJob(jobId);
      return true;
    }
  }

  /// Check if a job is marked as priority
  static Future<bool> isPriorityJob(int jobId) async {
    final jobIds = await getPriorityJobIds();
    return jobIds.contains(jobId);
  }

  /// Clear all priority jobs for current staff
  static Future<void> clearAllPriorities() async {
    try {
      final staffId = await _getCurrentStaffId();
      if (staffId != null) {
        // Set is_priority = false for all jobs of the current staff
        await _supabase
            .from('jobshead')
            .update({'is_priority': false})
            .eq('sporg_id', staffId)
            .eq('is_priority', true);
        debugPrint('PriorityService: Cleared all priorities for staff $staffId');
      }
    } catch (e) {
      debugPrint('PriorityService: Error clearing priorities: $e');
    }

    // Also clear local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_priorityJobsKey);
  }

  /// Get count of priority jobs
  static Future<int> getPriorityCount() async {
    final jobIds = await getPriorityJobIds();
    return jobIds.length;
  }
}
