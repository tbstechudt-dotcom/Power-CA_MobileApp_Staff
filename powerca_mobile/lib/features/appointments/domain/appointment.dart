import 'package:flutter/material.dart';

/// How the meeting takes place (`appmeetmode`).
enum MeetMode {
  direct('D', 'Direct', Icons.handshake_outlined),
  virtual('V', 'Virtual', Icons.videocam_outlined);

  final String code;
  final String label;
  final IconData icon;
  const MeetMode(this.code, this.label, this.icon);

  static MeetMode fromCode(String? c) =>
      values.firstWhere((m) => m.code == c?.trim(), orElse: () => MeetMode.direct);
}

/// Who the meeting is with (`appo_isclientexist`).
enum MeetWith {
  existingClient('E', 'Existing client'),
  newContact('N', 'New contact');

  final String code;
  final String label;
  const MeetWith(this.code, this.label);

  static MeetWith fromCode(String? c) =>
      values.firstWhere((m) => m.code == c?.trim(), orElse: () => MeetWith.existingClient);
}

/// `appo_status`.
enum AppointmentStatus {
  active('A', 'Active'),
  rescheduled('R', 'Rescheduled'),
  cancelled('C', 'Cancelled');

  final String code;
  final String label;
  const AppointmentStatus(this.code, this.label);

  static AppointmentStatus fromCode(String? c) =>
      values.firstWhere((s) => s.code == c?.trim(), orElse: () => AppointmentStatus.active);
}

/// A row of `mbappointments`.
@immutable
class Appointment {
  final int id; // appo_id
  final int orgId;
  final int locId;
  final int conId; // staff con_id (from login)
  final int yearId;
  final int staffId; // sporgid
  final MeetMode mode;
  final MeetWith meetWith;
  final int? clientId;
  final int? contactId; // appo_con_id
  final DateTime meetingDate; // appo_mdate (date only)
  final TimeOfDay? meetingTime; // appo_time
  final int? durationMinutes; // appo_duration
  final String? purpose; // appo_remarks

  // Outcome
  final Duration? actualTimeSpent; // appacttimespent
  final String? keyPerson; // appclikeyperson
  final bool isRescheduled; // appisreschedule
  final DateTime? rescheduleDate; // appreschdate
  final AppointmentStatus status;
  final bool outcomeRecorded; // appoactstatus = 1

  /// Client or contact name, resolved from climaster / contactperson.
  final String partyName;

  const Appointment({
    required this.id,
    required this.orgId,
    required this.locId,
    required this.conId,
    required this.yearId,
    required this.staffId,
    required this.mode,
    required this.meetWith,
    required this.meetingDate,
    required this.partyName,
    this.clientId,
    this.contactId,
    this.meetingTime,
    this.durationMinutes,
    this.purpose,
    this.actualTimeSpent,
    this.keyPerson,
    this.isRescheduled = false,
    this.rescheduleDate,
    this.status = AppointmentStatus.active,
    this.outcomeRecorded = false,
  });

  /// Meeting start (midnight when no time is set).
  DateTime get start => DateTime(
        meetingDate.year,
        meetingDate.month,
        meetingDate.day,
        meetingTime?.hour ?? 0,
        meetingTime?.minute ?? 0,
      );

  DateTime get end => start.add(Duration(minutes: durationMinutes ?? 60));

  bool get isActive => status == AppointmentStatus.active;

  /// Active and still waiting for its outcome.
  bool get isOpen => isActive && !outcomeRecorded;

  bool overlaps(DateTime from, DateTime to) => start.isBefore(to) && end.isAfter(from);

  Appointment withPartyName(String name) => Appointment(
        id: id,
        orgId: orgId,
        locId: locId,
        conId: conId,
        yearId: yearId,
        staffId: staffId,
        mode: mode,
        meetWith: meetWith,
        clientId: clientId,
        contactId: contactId,
        meetingDate: meetingDate,
        meetingTime: meetingTime,
        durationMinutes: durationMinutes,
        purpose: purpose,
        actualTimeSpent: actualTimeSpent,
        keyPerson: keyPerson,
        isRescheduled: isRescheduled,
        rescheduleDate: rescheduleDate,
        status: status,
        outcomeRecorded: outcomeRecorded,
        partyName: name,
      );

  factory Appointment.fromRow(Map<String, dynamic> r, {String partyName = ''}) {
    int? toInt(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
    final time = parseTime(r['appo_time'] as String?);
    final spent = parseTime(r['appacttimespent'] as String?);
    return Appointment(
      id: toInt(r['appo_id'])!,
      orgId: toInt(r['org_id']) ?? 0,
      locId: toInt(r['loc_id']) ?? 0,
      conId: toInt(r['con_id']) ?? 0,
      yearId: toInt(r['year_id']) ?? 0,
      staffId: toInt(r['sporgid']) ?? 0,
      mode: MeetMode.fromCode(r['appmeetmode'] as String?),
      meetWith: MeetWith.fromCode(r['appo_isclientexist'] as String?),
      clientId: toInt(r['client_id']),
      contactId: toInt(r['appo_con_id']),
      meetingDate: DateTime.parse(r['appo_mdate'] as String),
      meetingTime: time,
      durationMinutes: toInt(r['appo_duration']),
      purpose: (r['appo_remarks'] as String?)?.trim().isEmpty ?? true
          ? null
          : (r['appo_remarks'] as String).trim(),
      actualTimeSpent: spent == null ? null : Duration(hours: spent.hour, minutes: spent.minute),
      keyPerson: (r['appclikeyperson'] as String?)?.trim(),
      isRescheduled: (r['appisreschedule'] as String?)?.trim() == 'Y',
      rescheduleDate:
          r['appreschdate'] == null ? null : DateTime.parse(r['appreschdate'] as String),
      status: AppointmentStatus.fromCode(r['appo_status'] as String?),
      outcomeRecorded: toInt(r['appoactstatus']) == 1,
      partyName: partyName,
    );
  }

  /// Parses a Postgres `time` value ("HH:mm[:ss]").
  static TimeOfDay? parseTime(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}

/// Formats as a Postgres `time` literal.
String pgTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';

/// Formats as a Postgres `date` literal.
String pgDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Financial year id (April to March), e.g. 20262027 for Nov 2026.
int financialYearId(DateTime d) {
  final startYear = d.month >= 4 ? d.year : d.year - 1;
  return startYear * 10000 + (startYear + 1);
}
