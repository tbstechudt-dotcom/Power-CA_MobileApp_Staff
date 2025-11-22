import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage priority job selections for staff
/// Priority jobs are stored locally and used to filter daily entry forms
class PriorityService {
  static const String _priorityJobsKey = 'priority_job_ids';

  /// Get all priority job IDs for the current staff
  static Future<Set<int>> getPriorityJobIds() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jobIds = prefs.getStringList(_priorityJobsKey);
    if (jobIds == null) return {};
    return jobIds.map((id) => int.parse(id)).toSet();
  }

  /// Add a job to priority list
  static Future<void> addPriorityJob(int jobId) async {
    final prefs = await SharedPreferences.getInstance();
    final jobIds = await getPriorityJobIds();
    jobIds.add(jobId);
    await prefs.setStringList(
      _priorityJobsKey,
      jobIds.map((id) => id.toString()).toList(),
    );
  }

  /// Remove a job from priority list
  static Future<void> removePriorityJob(int jobId) async {
    final prefs = await SharedPreferences.getInstance();
    final jobIds = await getPriorityJobIds();
    jobIds.remove(jobId);
    await prefs.setStringList(
      _priorityJobsKey,
      jobIds.map((id) => id.toString()).toList(),
    );
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

  /// Clear all priority jobs
  static Future<void> clearAllPriorities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_priorityJobsKey);
  }

  /// Get count of priority jobs
  static Future<int> getPriorityCount() async {
    final jobIds = await getPriorityJobIds();
    return jobIds.length;
  }
}
