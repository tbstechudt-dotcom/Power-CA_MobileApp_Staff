class Job {
  final int jobId;
  final String jobName;
  final String jobReference;
  final String? clientName;
  final String? jstatus;
  final DateTime? jstartdate;
  final DateTime? jduedate;

  const Job({
    required this.jobId,
    required this.jobName,
    required this.jobReference,
    this.clientName,
    this.jstatus,
    this.jstartdate,
    this.jduedate,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Job &&
        other.jobId == jobId &&
        other.jobName == jobName &&
        other.jobReference == jobReference &&
        other.clientName == clientName &&
        other.jstatus == jstatus &&
        other.jstartdate == jstartdate &&
        other.jduedate == jduedate;
  }

  @override
  int get hashCode {
    return jobId.hashCode ^
        jobName.hashCode ^
        jobReference.hashCode ^
        clientName.hashCode ^
        jstatus.hashCode ^
        jstartdate.hashCode ^
        jduedate.hashCode;
  }
}
