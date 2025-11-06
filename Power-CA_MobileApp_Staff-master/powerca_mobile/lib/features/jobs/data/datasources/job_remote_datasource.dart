import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/job_model.dart';

/// Remote data source for jobs
abstract class JobRemoteDataSource {
  Future<List<JobModel>> getJobs({
    required int staffId,
    String? status,
    int? limit,
    int? offset,
  });

  Future<JobModel> getJobById(int jobId);

  Future<Map<String, int>> getJobsCountByStatus(int staffId);
}

@LazySingleton(as: JobRemoteDataSource)
class JobRemoteDataSourceImpl implements JobRemoteDataSource {
  final SupabaseClient supabaseClient;

  JobRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<JobModel>> getJobs({
    required int staffId,
    String? status,
    int? limit,
    int? offset,
  }) async {
    try {
      // Get staff's org_id to filter jobs by organization
      // (jobshead has no staff_id column, so we filter by org instead)
      final staffResponse = await supabaseClient
          .from('mbstaff')
          .select('org_id')
          .eq('staff_id', staffId)
          .single();

      final orgId = staffResponse['org_id'];

      // Build query - fetch jobs for the staff's organization
      var filterQuery = supabaseClient
          .from('jobshead')
          .select('''
            job_id,
            work_desc,
            job_status,
            org_id,
            client_id,
            jobdate,
            targetdate,
            created_at,
            updated_at
          ''')
          .eq('org_id', orgId);

      // Apply status filter if provided
      if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
        filterQuery = filterQuery.eq('job_status', status);
      }

      // Build final query with ordering and pagination
      var finalQuery = filterQuery.order('updated_at', ascending: false);

      // Apply pagination
      if (limit != null) {
        finalQuery = finalQuery.limit(limit);
      }

      if (offset != null) {
        finalQuery = finalQuery.range(offset, offset + (limit ?? 20) - 1);
      }

      final response = await finalQuery;

      // Get unique client IDs to fetch client names
      final clientIds = response
          .map((item) => item['client_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      // Fetch client names (if any client IDs exist)
      final Map<dynamic, String> clientNamesMap = {};
      if (clientIds.isNotEmpty) {
        final clientsResponse = await supabaseClient
            .from('climaster')
            .select('client_id, clientname')
            .inFilter('client_id', clientIds);

        for (final client in clientsResponse) {
          clientNamesMap[client['client_id']] = client['clientname'] ?? 'Unknown Client';
        }
      }

      // Transform response to JobModel list
      final jobs = <JobModel>[];
      for (final item in response) {
        final clientName = clientNamesMap[item['client_id']] ?? 'Unknown Client';

        final job = JobModel.fromJson({
          ...item,
          'job_name': item['work_desc'] ?? 'Unnamed Job', // Map work_desc to job_name
          'jstartdate': item['jobdate'], // Map jobdate to jstartdate
          'jenddate': item['targetdate'], // Map targetdate to jenddate
          'client_name': clientName,
          'job_reference': 'REG${item['job_id']}', // Generate reference from job_id
        });
        jobs.add(job);
      }

      return jobs;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<JobModel> getJobById(int jobId) async {
    try {
      final response = await supabaseClient
          .from('jobshead')
          .select('''
            job_id,
            work_desc,
            job_status,
            org_id,
            client_id,
            jobdate,
            targetdate,
            created_at,
            updated_at
          ''')
          .eq('job_id', jobId)
          .single();

      // Fetch client name separately
      String clientName = 'Unknown Client';
      if (response['client_id'] != null) {
        final clientResponse = await supabaseClient
            .from('climaster')
            .select('clientname')
            .eq('client_id', response['client_id'])
            .maybeSingle();

        if (clientResponse != null) {
          clientName = clientResponse['clientname'] ?? 'Unknown Client';
        }
      }

      return JobModel.fromJson({
        ...response,
        'job_name': response['work_desc'] ?? 'Unnamed Job', // Map work_desc to job_name
        'jstartdate': response['jobdate'], // Map jobdate to jstartdate
        'jenddate': response['targetdate'], // Map targetdate to jenddate
        'client_name': clientName,
        'job_reference': 'REG$jobId',
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Map<String, int>> getJobsCountByStatus(int staffId) async {
    try {
      // Get staff's org_id to filter jobs by organization
      final staffResponse = await supabaseClient
          .from('mbstaff')
          .select('org_id')
          .eq('staff_id', staffId)
          .single();

      final orgId = staffResponse['org_id'];

      // Get all jobs for the staff's organization
      final response = await supabaseClient
          .from('jobshead')
          .select('job_status')
          .eq('org_id', orgId);

      // Count by status
      final Map<String, int> counts = {
        'All': 0,
        'Waiting': 0,
        'Planning': 0,
        'Progress': 0,
        'Work Done': 0,
        'Delivery': 0,
        'Closed': 0,
      };

      for (final item in response) {
        final status = item['job_status'] as String? ?? 'Waiting';
        counts['All'] = (counts['All'] ?? 0) + 1;

        // Normalize status name
        final normalizedStatus = _normalizeStatus(status);
        if (counts.containsKey(normalizedStatus)) {
          counts[normalizedStatus] = (counts[normalizedStatus] ?? 0) + 1;
        }
      }

      return counts;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  String _normalizeStatus(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('wait')) return 'Waiting';
    if (lower.contains('plan')) return 'Planning';
    if (lower.contains('progress') || lower.contains('in progress')) return 'Progress';
    if (lower.contains('work done') || lower.contains('done')) return 'Work Done';
    if (lower.contains('deliver')) return 'Delivery';
    if (lower.contains('close')) return 'Closed';
    return status;
  }
}
