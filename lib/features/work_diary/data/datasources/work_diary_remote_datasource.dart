import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/work_diary_entry_model.dart';

abstract class WorkDiaryRemoteDataSource {
  /// Get all work diary entries for a specific job
  Future<List<WorkDiaryEntryModel>> getEntriesByJob({
    required int jobId,
    int? limit,
    int? offset,
  });

  /// Get all work diary entries for a specific staff member
  Future<List<WorkDiaryEntryModel>> getEntriesByStaff({
    required int staffId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  });

  /// Get a single work diary entry by ID
  Future<WorkDiaryEntryModel> getEntryById(int wdId);

  /// Add a new work diary entry
  Future<WorkDiaryEntryModel> addEntry(WorkDiaryEntryModel entry);

  /// Update an existing work diary entry
  Future<WorkDiaryEntryModel> updateEntry(WorkDiaryEntryModel entry);

  /// Delete a work diary entry
  Future<void> deleteEntry(int wdId);

  /// Get total hours worked for a job
  Future<double> getTotalHoursByJob(int jobId);

  /// Get total hours worked by staff in a date range
  Future<double> getTotalHoursByStaff({
    required int staffId,
    DateTime? startDate,
    DateTime? endDate,
  });
}

class WorkDiaryRemoteDataSourceImpl implements WorkDiaryRemoteDataSource {
  final SupabaseClient supabaseClient;

  WorkDiaryRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<WorkDiaryEntryModel>> getEntriesByJob({
    required int jobId,
    int? limit,
    int? offset,
  }) async {
    try {
      var query = supabaseClient
          .from('workdiary')
          .select('''
            wd_id,
            job_id,
            staff_id,
            wd_date,
            actual_hrs,
            wd_notes,
            created_at,
            updated_at,
            jobshead!inner(job_name),
            jobtasks(task_name)
          ''')
          .eq('job_id', jobId)
          .order('wd_date', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 20) - 1);
      }

      final response = await query;

      return (response as List)
          .map((entry) => WorkDiaryEntryModel.fromJson(entry))
          .toList();
    } catch (e) {
      throw Exception('Failed to get work diary entries by job: $e');
    }
  }

  @override
  Future<List<WorkDiaryEntryModel>> getEntriesByStaff({
    required int staffId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    try {
      // Build filter query
      var filterQuery = supabaseClient
          .from('workdiary')
          .select('''
            wd_id,
            job_id,
            staff_id,
            wd_date,
            actual_hrs,
            wd_notes,
            created_at,
            updated_at,
            jobshead!inner(job_name),
            jobtasks(task_name)
          ''')
          .eq('staff_id', staffId);

      if (startDate != null) {
        filterQuery = filterQuery.gte('wd_date', startDate.toIso8601String());
      }

      if (endDate != null) {
        filterQuery = filterQuery.lte('wd_date', endDate.toIso8601String());
      }

      // Apply transform operations
      var finalQuery = filterQuery.order('wd_date', ascending: false);

      if (limit != null) {
        finalQuery = finalQuery.limit(limit);
      }

      if (offset != null) {
        finalQuery = finalQuery.range(offset, offset + (limit ?? 20) - 1);
      }

      final response = await finalQuery;

      return (response as List)
          .map((entry) => WorkDiaryEntryModel.fromJson(entry))
          .toList();
    } catch (e) {
      throw Exception('Failed to get work diary entries by staff: $e');
    }
  }

  @override
  Future<WorkDiaryEntryModel> getEntryById(int wdId) async {
    try {
      final response = await supabaseClient
          .from('workdiary')
          .select('''
            wd_id,
            job_id,
            staff_id,
            wd_date,
            actual_hrs,
            wd_notes,
            created_at,
            updated_at,
            jobshead!inner(job_name),
            jobtasks(task_name)
          ''')
          .eq('wd_id', wdId)
          .single();

      return WorkDiaryEntryModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get work diary entry: $e');
    }
  }

  @override
  Future<WorkDiaryEntryModel> addEntry(WorkDiaryEntryModel entry) async {
    try {
      final response = await supabaseClient
          .from('workdiary')
          .insert(entry.toJson())
          .select('''
            wd_id,
            job_id,
            staff_id,
            wd_date,
            actual_hrs,
            wd_notes,
            created_at,
            updated_at,
            jobshead!inner(job_name),
            jobtasks(task_name)
          ''')
          .single();

      return WorkDiaryEntryModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add work diary entry: $e');
    }
  }

  @override
  Future<WorkDiaryEntryModel> updateEntry(WorkDiaryEntryModel entry) async {
    try {
      if (entry.wdId == null) {
        throw Exception('Cannot update entry without wd_id');
      }

      final response = await supabaseClient
          .from('workdiary')
          .update(entry.toJson())
          .eq('wd_id', entry.wdId!)
          .select('''
            wd_id,
            job_id,
            staff_id,
            wd_date,
            actual_hrs,
            wd_notes,
            created_at,
            updated_at,
            jobshead!inner(job_name),
            jobtasks(task_name)
          ''')
          .single();

      return WorkDiaryEntryModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update work diary entry: $e');
    }
  }

  @override
  Future<void> deleteEntry(int wdId) async {
    try {
      await supabaseClient.from('workdiary').delete().eq('wd_id', wdId);
    } catch (e) {
      throw Exception('Failed to delete work diary entry: $e');
    }
  }

  @override
  Future<double> getTotalHoursByJob(int jobId) async {
    try {
      final response = await supabaseClient
          .from('workdiary')
          .select('actual_hrs')
          .eq('job_id', jobId);

      if (response.isEmpty) {
        return 0.0;
      }

      double total = 0.0;
      for (final entry in response) {
        total += (entry['actual_hrs'] as num?)?.toDouble() ?? 0.0;
      }

      return total;
    } catch (e) {
      throw Exception('Failed to get total hours by job: $e');
    }
  }

  @override
  Future<double> getTotalHoursByStaff({
    required int staffId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = supabaseClient
          .from('workdiary')
          .select('actual_hrs')
          .eq('staff_id', staffId);

      if (startDate != null) {
        query = query.gte('wd_date', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('wd_date', endDate.toIso8601String());
      }

      final response = await query;

      if (response.isEmpty) {
        return 0.0;
      }

      double total = 0.0;
      for (final entry in response) {
        total += (entry['actual_hrs'] as num?)?.toDouble() ?? 0.0;
      }

      return total;
    } catch (e) {
      throw Exception('Failed to get total hours by staff: $e');
    }
  }
}
