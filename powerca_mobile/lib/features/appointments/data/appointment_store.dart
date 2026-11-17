import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/entities/staff.dart';
import '../domain/appointment.dart';

/// Reads and writes `j_appointments` in Supabase.
///
/// Widgets listen to [instance]; it notifies after every write so the Home
/// card reloads.
class AppointmentStore extends ChangeNotifier {
  AppointmentStore._();
  static final AppointmentStore instance = AppointmentStore._();

  static const _table = 'j_appointments';

  SupabaseClient get _db => Supabase.instance.client;

  /// `user_create` / `user_modify` are varchar(15).
  String _user(Staff s) => s.username.length > 15 ? s.username.substring(0, 15) : s.username;

  /// Active appointments of [staffId] still waiting for an outcome, soonest
  /// first. Includes past meetings (up to [lookBackDays]) so their outcome
  /// can still be recorded.
  Future<List<Appointment>> open(int staffId, {int lookBackDays = 30}) async {
    final from = DateTime.now().subtract(Duration(days: lookBackDays));
    final rows = await _db
        .from(_table)
        .select()
        .eq('sporgid', staffId)
        .eq('appo_status', 'A')
        .eq('appoactstatus', 0)
        .gte('appo_mdate', pgDate(from))
        .order('appo_mdate')
        .order('appo_time');
    return _withNames(List<Map<String, dynamic>>.from(rows));
  }

  Future<Appointment?> byId(int id) async {
    final row = await _db.from(_table).select().eq('appo_id', id).maybeSingle();
    if (row == null) return null;
    return (await _withNames([row])).first;
  }

  /// First active appointment of [staffId] overlapping the slot, ignoring
  /// [exceptId].
  Future<Appointment?> findClash(
    int staffId,
    DateTime start,
    int durationMinutes, {
    int? exceptId,
  }) async {
    final rows = await _db
        .from(_table)
        .select()
        .eq('sporgid', staffId)
        .eq('appo_status', 'A')
        .eq('appo_mdate', pgDate(start));
    final end = start.add(Duration(minutes: durationMinutes));
    final list = await _withNames(List<Map<String, dynamic>>.from(rows));
    for (final a in list) {
      if (a.id != exceptId && a.meetingTime != null && a.overlaps(start, end)) return a;
    }
    return null;
  }

  /// Inserts a new appointment and returns it.
  Future<Appointment> create({
    required Staff staff,
    required MeetMode mode,
    required MeetWith meetWith,
    required int partyId,
    required String partyName,
    required DateTime start,
    required int durationMinutes,
    String? purpose,
  }) async {
    final now = DateTime.now();
    final row = await _db
        .from(_table)
        .insert({
          'org_id': staff.orgId,
          'loc_id': staff.locId,
          'con_id': staff.conId,
          'year_id': financialYearId(start),
          'appmeetmode': mode.code,
          'appo_isclientexist': meetWith.code,
          'client_id': meetWith == MeetWith.existingClient ? partyId : null,
          'appo_con_id': meetWith == MeetWith.newContact ? partyId : null,
          'appo_rdate': pgDate(now),
          'sporgid': staff.staffId,
          'appo_mdate': pgDate(start),
          'appo_time': pgTime(start.hour, start.minute),
          'appo_duration': durationMinutes,
          'appo_remarks': _clean(purpose),
          'user_create': _user(staff),
          'user_create_dt': pgDate(now),
          'source': 'M',
        })
        .select()
        .single();
    notifyListeners();
    return Appointment.fromRow(row, partyName: partyName);
  }

  /// Updates the appointment details of an existing, still active row.
  Future<Appointment> update(
    Appointment a, {
    required Staff staff,
    required MeetMode mode,
    required MeetWith meetWith,
    required int partyId,
    required String partyName,
    required DateTime start,
    required int durationMinutes,
    String? purpose,
  }) async {
    final row = await _db
        .from(_table)
        .update({
          'appmeetmode': mode.code,
          'appo_isclientexist': meetWith.code,
          'client_id': meetWith == MeetWith.existingClient ? partyId : null,
          'appo_con_id': meetWith == MeetWith.newContact ? partyId : null,
          'year_id': financialYearId(start),
          'appo_mdate': pgDate(start),
          'appo_time': pgTime(start.hour, start.minute),
          'appo_duration': durationMinutes,
          'appo_remarks': _clean(purpose),
          ..._modified(staff),
        })
        .eq('appo_id', a.id)
        .select()
        .single();
    notifyListeners();
    return Appointment.fromRow(row, partyName: partyName);
  }

  /// Saves the outcome. When [rescheduleTo] is set, the current row becomes
  /// `R` (rescheduled) and a copy is inserted for the new date/time; the new
  /// appointment is returned. Otherwise the updated row is returned.
  Future<Appointment> saveOutcome(
    Appointment a, {
    required Staff staff,
    required Duration timeSpent,
    required String keyPerson,
    DateTime? rescheduleTo,
  }) async {
    final now = DateTime.now();
    final updated = await _db
        .from(_table)
        .update({
          'appacttimespent': pgTime(timeSpent.inHours, timeSpent.inMinutes % 60),
          'appclikeyperson': _clean(keyPerson),
          'appisreschedule': rescheduleTo == null ? 'N' : 'Y',
          'appreschdate': rescheduleTo == null ? null : pgDate(rescheduleTo),
          if (rescheduleTo != null) 'appo_status': 'R',
          'appoactstatus': 1,
          ..._modified(staff),
        })
        .eq('appo_id', a.id)
        .select()
        .single();

    if (rescheduleTo == null) {
      notifyListeners();
      return Appointment.fromRow(updated, partyName: a.partyName);
    }

    final copy = Map<String, dynamic>.from(updated)
      ..remove('appo_id')
      ..remove('created_at')
      ..remove('updated_at')
      ..addAll({
        'year_id': financialYearId(rescheduleTo),
        'appo_rdate': pgDate(now),
        'appo_mdate': pgDate(rescheduleTo),
        'appo_time': pgTime(rescheduleTo.hour, rescheduleTo.minute),
        'appacttimespent': null,
        'appclikeyperson': null,
        'appisreschedule': 'N',
        'appreschdate': null,
        'appo_status': 'A',
        'appoactstatus': 0,
        'user_create': _user(staff),
        'user_create_dt': pgDate(now),
        'user_modify': null,
        'user_modify_dt': null,
        'source': 'M',
      });
    final inserted = await _db.from(_table).insert(copy).select().single();
    notifyListeners();
    return Appointment.fromRow(inserted, partyName: a.partyName);
  }

  Future<void> cancel(Appointment a, {required Staff staff}) async {
    await _db.from(_table).update({'appo_status': 'C', ..._modified(staff)}).eq('appo_id', a.id);
    notifyListeners();
  }

  Map<String, dynamic> _modified(Staff staff) => {
        'user_modify': _user(staff),
        'user_modify_dt': pgDate(DateTime.now()),
      };

  String? _clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  /// Resolves client / contact names for the rows.
  Future<List<Appointment>> _withNames(List<Map<String, dynamic>> rows) async {
    final clientIds = <int>{};
    final contactIds = <int>{};
    for (final r in rows) {
      final c = r['client_id'];
      final k = r['appo_con_id'];
      if (c != null) clientIds.add((c as num).toInt());
      if (k != null) contactIds.add((k as num).toInt());
    }
    final clientNames = <int, String>{};
    final contactNames = <int, String>{};
    if (clientIds.isNotEmpty) {
      final res = await _db
          .from('climaster')
          .select('client_id, clientname')
          .inFilter('client_id', clientIds.toList());
      for (final c in res) {
        clientNames[(c['client_id'] as num).toInt()] = (c['clientname'] ?? '').toString().trim();
      }
    }
    if (contactIds.isNotEmpty) {
      final res = await _db
          .from('contactperson')
          .select('con_id, conname')
          .inFilter('con_id', contactIds.toList());
      for (final c in res) {
        contactNames[(c['con_id'] as num).toInt()] = (c['conname'] ?? '').toString().trim();
      }
    }
    return rows.map((r) {
      final a = Appointment.fromRow(r);
      final name = a.meetWith == MeetWith.existingClient
          ? clientNames[a.clientId]
          : contactNames[a.contactId];
      return a.withPartyName(
        (name == null || name.isEmpty)
            ? (a.meetWith == MeetWith.existingClient ? 'Client' : 'Contact')
            : name,
      );
    }).toList();
  }
}
