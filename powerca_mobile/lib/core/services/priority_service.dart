import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage priority job selections for staff
/// Priority jobs are stored LOCALLY per staff member - NOT shared with other staff
/// Each staff member has their own separate priority list
class PriorityService {
  static const String _priorityJobsKeyPrefix = 'priority_job_ids_staff_';
  static const String _staffIdKey = 'current_staff_id';

  /// Get current staff ID from local storage
  static Future<int?> _getCurrentStaffId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_staffIdKey);
  }

  /// Set current staff ID (call this when user logs in)
  static Future<void> setCurrentStaffId(int staffId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_staffIdKey, staffId);
    debugPrint('PriorityService: Set current staff ID to $staffId');
  }

  /// Get the storage key for the current staff's priorities
  static Future<String> _getStaffPriorityKey() async {
    final staffId = await _getCurrentStaffId();
    if (staffId == null) {
      debugPrint('PriorityService: Warning - No staff ID found, using default key');
      return '${_priorityJobsKeyPrefix}unknown';
    }
    return '$_priorityJobsKeyPrefix$staffId';
  }

  /// Get all priority job IDs for the current staff (STAFF-SPECIFIC)
  static Future<Set<int>> getPriorityJobIds() async {
    try {
      final staffId = await _getCurrentStaffId();
      if (staffId == null) {
        debugPrint('PriorityService: No staff ID found, returning empty set');
        return {};
      }

      final prefs = await SharedPreferences.getInstance();
      final key = '$_priorityJobsKeyPrefix$staffId';
      final List<String>? jobIds = prefs.getStringList(key);

      if (jobIds == null || jobIds.isEmpty) {
        debugPrint('PriorityService: No priority jobs found for staff $staffId');
        return {};
      }

      final result = jobIds.map((id) => int.parse(id)).toSet();
      debugPrint('PriorityService: Loaded ${result.length} priority jobs for staff $staffId');
      return result;
    } catch (e) {
      debugPrint('PriorityService: Error loading priorities: $e');
      return {};
    }
  }

  /// Save priority job IDs for the current staff
  static Future<void> _savePriorityJobIds(Set<int> jobIds) async {
    try {
      final key = await _getStaffPriorityKey();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        key,
        jobIds.map((id) => id.toString()).toList(),
      );
      debugPrint('PriorityService: Saved ${jobIds.length} priority jobs');
    } catch (e) {
      debugPrint('PriorityService: Error saving priorities: $e');
    }
  }

  /// Add a job to priority list (STAFF-SPECIFIC - only affects current staff)
  static Future<void> addPriorityJob(int jobId) async {
    try {
      final jobIds = await getPriorityJobIds();
      jobIds.add(jobId);
      await _savePriorityJobIds(jobIds);

      final staffId = await _getCurrentStaffId();
      debugPrint('PriorityService: Added job $jobId to priority for staff $staffId');
    } catch (e) {
      debugPrint('PriorityService: Error adding priority: $e');
    }
  }

  /// Remove a job from priority list (STAFF-SPECIFIC - only affects current staff)
  static Future<void> removePriorityJob(int jobId) async {
    try {
      final jobIds = await getPriorityJobIds();
      jobIds.remove(jobId);
      await _savePriorityJobIds(jobIds);

      final staffId = await _getCurrentStaffId();
      debugPrint('PriorityService: Removed job $jobId from priority for staff $staffId');
    } catch (e) {
      debugPrint('PriorityService: Error removing priority: $e');
    }
  }

  /// Toggle priority status for a job (STAFF-SPECIFIC)
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

  /// Check if a job is marked as priority for current staff
  static Future<bool> isPriorityJob(int jobId) async {
    final jobIds = await getPriorityJobIds();
    return jobIds.contains(jobId);
  }

  /// Clear all priority jobs for current staff only
  static Future<void> clearAllPriorities() async {
    try {
      final key = await _getStaffPriorityKey();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);

      final staffId = await _getCurrentStaffId();
      debugPrint('PriorityService: Cleared all priorities for staff $staffId');
    } catch (e) {
      debugPrint('PriorityService: Error clearing priorities: $e');
    }
  }

  /// Get count of priority jobs for current staff
  static Future<int> getPriorityCount() async {
    final jobIds = await getPriorityJobIds();
    return jobIds.length;
  }

  /// Clear priority data when user logs out
  static Future<void> clearOnLogout() async {
    // Don't clear the priority data - just clear the current staff ID
    // This way, when the same user logs back in, their priorities are preserved
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_staffIdKey);
    debugPrint('PriorityService: Cleared staff ID on logout');
  }
}
