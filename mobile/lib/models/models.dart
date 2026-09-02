import '../core/config.dart';

/// Every model here maps 1:1 onto a backend response shape. Parsing is
/// deliberately forgiving: a missing or renamed field yields a sane default
/// rather than a crash in the widget tree.

num _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
int _int(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
String _str(dynamic v) => v?.toString() ?? '';
bool _bool(dynamic v) => v is bool ? v : v?.toString() == 'true';
DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// Server-generated file URLs use whatever PUBLIC_BASE_URL was configured.
/// On an emulator `localhost` points at the phone, so rewrite it to the host
/// the app is actually talking to.
String fixFileUrl(String url) {
  if (url.isEmpty) return url;
  return url
      .replaceFirst('http://localhost:4000', AppConfig.host)
      .replaceFirst('http://127.0.0.1:4000', AppConfig.host)
      .replaceFirst('http://localhost:3000', AppConfig.host);
}

enum Role { admin, student }

Role roleFrom(String? v) => v == 'ADMIN' ? Role.admin : Role.student;

// ── auth ──────────────────────────────────────────────────────
class AppUser {
  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.studentId,
    this.studentCode,
  });

  final String id;
  final String email;
  final String name;
  final Role role;
  final String? phone;
  final String? studentId;
  final String? studentCode;

  bool get isAdmin => role == Role.admin;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _str(j['id']),
        email: _str(j['email']),
        name: _str(j['name']),
        role: roleFrom(j['role'] as String?),
        phone: j['phone'] as String?,
        studentId: j['studentId'] as String? ??
            (j['student'] is Map ? _str((j['student'] as Map)['id']) : null),
        studentCode: j['studentCode'] as String? ??
            (j['student'] is Map
                ? _str((j['student'] as Map)['studentCode'])
                : null),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role == Role.admin ? 'ADMIN' : 'STUDENT',
        'phone': phone,
        'studentId': studentId,
        'studentCode': studentCode,
      };
}

// ── batch ─────────────────────────────────────────────────────
class Batch {
  Batch({
    required this.id,
    required this.name,
    required this.course,
    required this.subject,
    required this.timing,
    required this.room,
    required this.capacity,
    required this.isActive,
    required this.studentCount,
    this.startDate,
  });

  final String id;
  final String name;
  final String course;
  final String subject;
  final String timing;
  final String room;
  final int capacity;
  final bool isActive;
  final int studentCount;
  final DateTime? startDate;

  factory Batch.fromJson(Map<String, dynamic> j) => Batch(
        id: _str(j['id']),
        name: _str(j['name']),
        course: _str(j['course']),
        subject: _str(j['subject']),
        timing: _str(j['timing']),
        room: _str(j['room']),
        capacity: _int(j['capacity']),
        isActive: j['isActive'] == null ? true : _bool(j['isActive']),
        studentCount: _int(j['studentCount'] ??
            (j['_count'] is Map ? (j['_count'] as Map)['students'] : 0)),
        startDate: _date(j['startDate']),
      );
}

class BatchRef {
  BatchRef({required this.id, required this.name, this.subject, this.timing, this.room});
  final String id;
  final String name;
  final String? subject;
  final String? timing;
  final String? room;

  factory BatchRef.fromJson(Map<String, dynamic> j) => BatchRef(
        id: _str(j['id']),
        name: _str(j['name']),
        subject: j['subject'] as String?,
        timing: j['timing'] as String?,
        room: j['room'] as String?,
      );
}

// ── student ───────────────────────────────────────────────────
class Student {
  Student({
    required this.id,
    required this.studentCode,
    required this.name,
    required this.phone,
    required this.email,
    required this.parentName,
    required this.parentPhone,
    required this.address,
    required this.course,
    required this.isActive,
    this.batch,
    this.batchId,
    this.admissionDate,
    this.notes,
    this.attendanceSummary,
    this.feeSummary,
  });

  final String id;
  final String studentCode;
  final String name;
  final String phone;
  final String email;
  final String parentName;
  final String parentPhone;
  final String address;
  final String course;
  final bool isActive;
  final BatchRef? batch;
  final String? batchId;
  final DateTime? admissionDate;
  final String? notes;
  final AttendanceSummary? attendanceSummary;
  final FeeSummary? feeSummary;

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: _str(j['id']),
        studentCode: _str(j['studentCode']),
        name: _str(j['name']),
        phone: _str(j['phone']),
        email: _str(j['email']),
        parentName: _str(j['parentName']),
        parentPhone: _str(j['parentPhone']),
        address: _str(j['address']),
        course: _str(j['course']),
        isActive: j['isActive'] == null ? true : _bool(j['isActive']),
        batch: j['batch'] is Map
            ? BatchRef.fromJson(Map<String, dynamic>.from(j['batch'] as Map))
            : null,
        batchId: j['batchId'] as String?,
        admissionDate: _date(j['admissionDate']),
        notes: j['notes'] as String?,
        attendanceSummary: j['attendanceSummary'] is Map
            ? AttendanceSummary.fromJson(
                Map<String, dynamic>.from(j['attendanceSummary'] as Map))
            : null,
        feeSummary: j['feeSummary'] is Map
            ? FeeSummary.fromJson(
                Map<String, dynamic>.from(j['feeSummary'] as Map))
            : null,
      );
}

class StudentRef {
  StudentRef({required this.id, required this.name, required this.studentCode});
  final String id;
  final String name;
  final String studentCode;

  factory StudentRef.fromJson(Map<String, dynamic> j) => StudentRef(
        id: _str(j['id']),
        name: _str(j['name']),
        studentCode: _str(j['studentCode']),
      );
}

// ── attendance ────────────────────────────────────────────────
class AttendanceSummary {
  AttendanceSummary({
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
    required this.total,
    required this.percentage,
    this.todayStatus,
  });

  final int present, absent, late, leave, total;
  final double percentage;
  final String? todayStatus;

  factory AttendanceSummary.fromJson(Map<String, dynamic> j) =>
      AttendanceSummary(
        present: _int(j['PRESENT']),
        absent: _int(j['ABSENT']),
        late: _int(j['LATE']),
        leave: _int(j['LEAVE']),
        total: _int(j['total']),
        percentage: _num(j['percentage']).toDouble(),
        todayStatus: j['todayStatus'] as String?,
      );
}

class AttendanceSheetEntry {
  AttendanceSheetEntry({
    required this.studentId,
    required this.name,
    required this.studentCode,
    this.status,
    this.remarks,
    this.attendanceId,
  });

  final String studentId;
  final String name;
  final String studentCode;
  String? status;
  String? remarks;
  final String? attendanceId;

  factory AttendanceSheetEntry.fromJson(Map<String, dynamic> j) =>
      AttendanceSheetEntry(
        studentId: _str(j['studentId']),
        name: _str(j['name']),
        studentCode: _str(j['studentCode']),
        status: j['status'] as String?,
        remarks: j['remarks'] as String?,
        attendanceId: j['attendanceId'] as String?,
      );
}

class AttendanceSheet {
  AttendanceSheet({
    required this.batch,
    required this.date,
    required this.alreadyMarked,
    required this.markedCount,
    required this.entries,
  });

  final BatchRef batch;
  final String date;
  final bool alreadyMarked;
  final int markedCount;
  final List<AttendanceSheetEntry> entries;

  factory AttendanceSheet.fromJson(Map<String, dynamic> j) => AttendanceSheet(
        batch: BatchRef.fromJson(Map<String, dynamic>.from(j['batch'] as Map)),
        date: _str(j['date']),
        alreadyMarked: _bool(j['alreadyMarked']),
        markedCount: _int(j['markedCount']),
        entries: ((j['entries'] as List?) ?? [])
            .map((e) =>
                AttendanceSheetEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.date,
    required this.status,
    this.remarks,
    this.batchName,
    this.subject,
    this.student,
  });

  final String id;
  final String date;
  final String status;
  final String? remarks;
  final String? batchName;
  final String? subject;
  final StudentRef? student;

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) {
    final batch = j['batch'];
    return AttendanceRecord(
      id: _str(j['id']),
      date: _str(j['date']),
      status: _str(j['status']),
      remarks: j['remarks'] as String?,
      batchName: batch is Map ? _str(batch['name']) : null,
      subject: batch is Map ? batch['subject'] as String? : null,
      student: j['student'] is Map
          ? StudentRef.fromJson(Map<String, dynamic>.from(j['student'] as Map))
          : null,
    );
  }
}

class AttendanceReport {
  AttendanceReport({
    required this.student,
    required this.summary,
    required this.records,
  });

  final StudentRef student;
  final AttendanceSummary summary;
  final List<AttendanceRecord> records;

  factory AttendanceReport.fromJson(Map<String, dynamic> j) =>
      AttendanceReport(
        student:
            StudentRef.fromJson(Map<String, dynamic>.from(j['student'] as Map)),
        summary: AttendanceSummary.fromJson(
            Map<String, dynamic>.from(j['summary'] as Map)),
        records: ((j['records'] as List?) ?? [])
            .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class AttendanceDay {
  AttendanceDay({
    required this.date,
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
    required this.total,
    required this.percentage,
  });

  final String date;
  final int present, absent, late, leave, total;
  final double percentage;

  factory AttendanceDay.fromJson(Map<String, dynamic> j) => AttendanceDay(
        date: _str(j['date']),
        present: _int(j['PRESENT']),
        absent: _int(j['ABSENT']),
        late: _int(j['LATE']),
        leave: _int(j['LEAVE']),
        total: _int(j['total']),
        percentage: _num(j['percentage']).toDouble(),
      );
}

// ── fees ──────────────────────────────────────────────────────
class FeeSummary {
  FeeSummary({
    required this.totalFee,
    required this.paid,
    required this.due,
    required this.overdue,
    required this.installments,
    this.paidInstallments = 0,
    this.nextDueDate,
    this.nextDueAmount = 0,
    this.nextDueTitle,
  });

  final num totalFee, paid, due, overdue;
  final int installments, paidInstallments;
  final DateTime? nextDueDate;
  final num nextDueAmount;
  final String? nextDueTitle;

  factory FeeSummary.fromJson(Map<String, dynamic> j) => FeeSummary(
        totalFee: _num(j['totalFee']),
        paid: _num(j['paid']),
        due: _num(j['due']),
        overdue: _num(j['overdue']),
        installments: _int(j['installments']),
        paidInstallments: _int(j['paidInstallments']),
        nextDueDate: _date(j['nextDueDate']),
        nextDueAmount: _num(j['nextDueAmount']),
        nextDueTitle: j['nextDueTitle'] as String?,
      );
}

class FeePayment {
  FeePayment({
    required this.id,
    required this.amount,
    required this.receiptNo,
    required this.mode,
    this.reference,
    this.paidAt,
    this.recordedBy,
    this.feeTitle,
    this.student,
  });

  final String id;
  final num amount;
  final String receiptNo;
  final String mode;
  final String? reference;
  final DateTime? paidAt;
  final String? recordedBy;
  final String? feeTitle;
  final StudentRef? student;

  factory FeePayment.fromJson(Map<String, dynamic> j) {
    final fee = j['fee'];
    return FeePayment(
      id: _str(j['id']),
      amount: _num(j['amount']),
      receiptNo: _str(j['receiptNo']),
      mode: _str(j['mode']),
      reference: j['reference'] as String?,
      paidAt: _date(j['paidAt']),
      recordedBy: j['recordedBy'] is Map
          ? _str((j['recordedBy'] as Map)['name'])
          : j['recordedBy'] as String?,
      feeTitle: fee is Map ? _str(fee['title']) : null,
      student: fee is Map && fee['student'] is Map
          ? StudentRef.fromJson(Map<String, dynamic>.from(fee['student'] as Map))
          : null,
    );
  }
}

class Fee {
  Fee({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.paidAmount,
    required this.balance,
    required this.status,
    required this.installmentNo,
    required this.totalInstallments,
    this.dueDate,
    this.notes,
    this.payments = const [],
    this.student,
  });

  final String id;
  final String title;
  final num totalAmount, paidAmount, balance;
  final String status;
  final int installmentNo, totalInstallments;
  final DateTime? dueDate;
  final String? notes;
  final List<FeePayment> payments;
  final StudentRef? student;

  bool get isPaid => status == 'PAID';

  factory Fee.fromJson(Map<String, dynamic> j) => Fee(
        id: _str(j['id']),
        title: _str(j['title']),
        totalAmount: _num(j['totalAmount']),
        paidAmount: _num(j['paidAmount']),
        balance: _num(j['balance'] ??
            (_num(j['totalAmount']) - _num(j['paidAmount']))),
        status: _str(j['status']),
        installmentNo: _int(j['installmentNo']),
        totalInstallments: _int(j['totalInstallments']),
        dueDate: _date(j['dueDate']),
        notes: j['notes'] as String?,
        payments: ((j['payments'] as List?) ?? [])
            .map((e) => FeePayment.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        student: j['student'] is Map
            ? StudentRef.fromJson(
                Map<String, dynamic>.from(j['student'] as Map))
            : null,
      );
}

class StudentFeeLedger {
  StudentFeeLedger({
    required this.student,
    required this.summary,
    required this.fees,
  });

  final StudentRef student;
  final FeeSummary summary;
  final List<Fee> fees;

  factory StudentFeeLedger.fromJson(Map<String, dynamic> j) =>
      StudentFeeLedger(
        student:
            StudentRef.fromJson(Map<String, dynamic>.from(j['student'] as Map)),
        summary: FeeSummary.fromJson(
            Map<String, dynamic>.from(j['summary'] as Map)),
        fees: ((j['fees'] as List?) ?? [])
            .map((e) => Fee.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class Receipt {
  Receipt({
    required this.institute,
    required this.receiptNo,
    required this.amount,
    required this.mode,
    required this.studentName,
    required this.studentCode,
    required this.feeTitle,
    required this.installment,
    required this.totalAmount,
    required this.paidAmount,
    required this.balance,
    required this.status,
    this.course,
    this.batchName,
    this.reference,
    this.recordedBy,
    this.paidAt,
    this.dueDate,
  });

  final String institute, receiptNo, mode, studentName, studentCode;
  final String feeTitle, installment, status;
  final num amount, totalAmount, paidAmount, balance;
  final String? course, batchName, reference, recordedBy;
  final DateTime? paidAt, dueDate;

  factory Receipt.fromJson(Map<String, dynamic> j) {
    final s = Map<String, dynamic>.from(j['student'] as Map);
    final f = Map<String, dynamic>.from(j['fee'] as Map);
    return Receipt(
      institute: _str(j['institute']),
      receiptNo: _str(j['receiptNo']),
      amount: _num(j['amount']),
      mode: _str(j['mode']),
      reference: j['reference'] as String?,
      recordedBy: j['recordedBy'] as String?,
      paidAt: _date(j['paidAt']),
      studentName: _str(s['name']),
      studentCode: _str(s['studentCode']),
      course: s['course'] as String?,
      batchName: s['batch'] is Map ? _str((s['batch'] as Map)['name']) : null,
      feeTitle: _str(f['title']),
      installment: _str(f['installment']),
      totalAmount: _num(f['totalAmount']),
      paidAmount: _num(f['paidAmount']),
      balance: _num(f['balance']),
      status: _str(f['status']),
      dueDate: _date(f['dueDate']),
    );
  }
}

// ── timetable ─────────────────────────────────────────────────
class TimetableSlot {
  TimetableSlot({
    required this.id,
    required this.subject,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.room,
    this.teacher,
    this.batchId,
    this.batchName,
  });

  final String id;
  final String subject;
  final String weekday;
  final String startTime, endTime, room;
  final String? teacher;
  final String? batchId, batchName;

  factory TimetableSlot.fromJson(Map<String, dynamic> j) {
    final batch = j['batch'];
    return TimetableSlot(
      id: _str(j['id']),
      subject: _str(j['subject']),
      weekday: _str(j['weekday']),
      startTime: _str(j['startTime']),
      endTime: _str(j['endTime']),
      room: _str(j['room']),
      teacher: j['teacher'] as String?,
      batchId: j['batchId'] as String?,
      batchName: batch is Map ? _str(batch['name']) : null,
    );
  }
}

class WeeklyTimetable {
  WeeklyTimetable({required this.batch, required this.days});
  final BatchRef? batch;
  final Map<String, List<TimetableSlot>> days;

  bool get isEmpty => days.values.every((s) => s.isEmpty);

  factory WeeklyTimetable.fromJson(Map<String, dynamic> j) {
    final map = <String, List<TimetableSlot>>{};
    for (final d in (j['days'] as List?) ?? []) {
      final day = Map<String, dynamic>.from(d);
      map[_str(day['weekday'])] = ((day['slots'] as List?) ?? [])
          .map((s) => TimetableSlot.fromJson(Map<String, dynamic>.from(s)))
          .toList();
    }
    return WeeklyTimetable(
      batch: j['batch'] is Map
          ? BatchRef.fromJson(Map<String, dynamic>.from(j['batch'] as Map))
          : null,
      days: map,
    );
  }
}

class NextClass {
  NextClass({
    required this.subject,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.startsInMinutes,
    required this.isToday,
    this.teacher,
    this.batchName,
  });

  final String subject, weekday, startTime, endTime, room;
  final int startsInMinutes;
  final bool isToday;
  final String? teacher, batchName;

  factory NextClass.fromJson(Map<String, dynamic> j) => NextClass(
        subject: _str(j['subject']),
        weekday: _str(j['weekday']),
        startTime: _str(j['startTime']),
        endTime: _str(j['endTime']),
        room: _str(j['room']),
        startsInMinutes: _int(j['startsInMinutes']),
        isToday: _bool(j['isToday']),
        teacher: j['teacher'] as String?,
        batchName: j['batchName'] as String?,
      );
}

// ── exams ─────────────────────────────────────────────────────
class ExamSubject {
  ExamSubject({required this.name, required this.maxMarks});
  final String name;
  final int maxMarks;

  factory ExamSubject.fromJson(Map<String, dynamic> j) => ExamSubject(
        name: _str(j['name']),
        maxMarks: _int(j['maxMarks']),
      );

  Map<String, dynamic> toJson() => {'name': name, 'maxMarks': maxMarks};
}

class Exam {
  Exam({
    required this.id,
    required this.name,
    required this.totalMarks,
    required this.isPublished,
    required this.subjects,
    required this.resultCount,
    this.examDate,
    this.description,
    this.batchId,
    this.batchName,
    this.stats,
    this.results = const [],
  });

  final String id;
  final String name;
  final int totalMarks;
  final bool isPublished;
  final List<ExamSubject> subjects;
  final int resultCount;
  final DateTime? examDate;
  final String? description;
  final String? batchId, batchName;
  final ExamStats? stats;
  final List<ExamResult> results;

  factory Exam.fromJson(Map<String, dynamic> j) {
    final batch = j['batch'];
    return Exam(
      id: _str(j['id']),
      name: _str(j['name']),
      totalMarks: _int(j['totalMarks']),
      isPublished: _bool(j['isPublished']),
      subjects: ((j['subjects'] as List?) ?? [])
          .map((s) => ExamSubject.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
      resultCount: _int(j['resultCount'] ??
          (j['_count'] is Map ? (j['_count'] as Map)['results'] : 0)),
      examDate: _date(j['examDate']),
      description: j['description'] as String?,
      batchId: j['batchId'] as String?,
      batchName: batch is Map ? _str(batch['name']) : null,
      stats: j['stats'] is Map
          ? ExamStats.fromJson(Map<String, dynamic>.from(j['stats'] as Map))
          : null,
      results: ((j['results'] as List?) ?? [])
          .map((r) => ExamResult.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
    );
  }
}

class ExamStats {
  ExamStats({
    required this.count,
    required this.average,
    required this.highest,
    required this.lowest,
    required this.passRate,
  });

  final int count;
  final double average, highest, lowest, passRate;

  factory ExamStats.fromJson(Map<String, dynamic> j) => ExamStats(
        count: _int(j['count']),
        average: _num(j['average']).toDouble(),
        highest: _num(j['highest']).toDouble(),
        lowest: _num(j['lowest']).toDouble(),
        passRate: _num(j['passRate']).toDouble(),
      );
}

class SubjectMark {
  SubjectMark({
    required this.subject,
    required this.maxMarks,
    this.marksObtained,
  });

  final String subject;
  final int maxMarks;
  num? marksObtained;

  factory SubjectMark.fromJson(Map<String, dynamic> j) => SubjectMark(
        subject: _str(j['subject']),
        maxMarks: _int(j['maxMarks']),
        marksObtained: j['marksObtained'] == null ? null : _num(j['marksObtained']),
      );
}

class ExamResult {
  ExamResult({
    required this.id,
    required this.obtained,
    required this.totalMarks,
    required this.percentage,
    required this.marks,
    this.grade,
    this.rank,
    this.remarks,
    this.student,
    this.examName,
    this.examDate,
    this.classSize,
  });

  final String id;
  final num obtained;
  final int totalMarks;
  final double percentage;
  final List<SubjectMark> marks;
  final String? grade;
  final int? rank;
  final String? remarks;
  final StudentRef? student;
  final String? examName;
  final DateTime? examDate;
  final int? classSize;

  factory ExamResult.fromJson(Map<String, dynamic> j) {
    final exam = j['exam'];
    return ExamResult(
      id: _str(j['id']),
      obtained: _num(j['obtained']),
      totalMarks: _int(j['totalMarks']),
      percentage: _num(j['percentage']).toDouble(),
      marks: ((j['marks'] as List?) ?? [])
          .map((m) => SubjectMark.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      grade: j['grade'] as String?,
      rank: j['rank'] == null ? null : _int(j['rank']),
      remarks: j['remarks'] as String?,
      student: j['student'] is Map
          ? StudentRef.fromJson(Map<String, dynamic>.from(j['student'] as Map))
          : null,
      examName: exam is Map ? _str(exam['name']) : null,
      examDate: exam is Map ? _date(exam['examDate']) : null,
      classSize: j['classSize'] == null ? null : _int(j['classSize']),
    );
  }
}

class MarksSheetRow {
  MarksSheetRow({
    required this.studentId,
    required this.name,
    required this.studentCode,
    required this.marks,
    this.resultId,
    this.remarks,
  });

  final String studentId, name, studentCode;
  final List<SubjectMark> marks;
  final String? resultId;
  String? remarks;

  bool get hasMarks => marks.any((m) => m.marksObtained != null);

  factory MarksSheetRow.fromJson(Map<String, dynamic> j) => MarksSheetRow(
        studentId: _str(j['studentId']),
        name: _str(j['name']),
        studentCode: _str(j['studentCode']),
        resultId: j['resultId'] as String?,
        remarks: j['remarks'] as String?,
        marks: ((j['marks'] as List?) ?? [])
            .map((m) => SubjectMark.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

class MarksSheet {
  MarksSheet({
    required this.examId,
    required this.examName,
    required this.totalMarks,
    required this.isPublished,
    required this.batchName,
    required this.subjects,
    required this.rows,
  });

  final String examId, examName, batchName;
  final int totalMarks;
  final bool isPublished;
  final List<ExamSubject> subjects;
  final List<MarksSheetRow> rows;

  factory MarksSheet.fromJson(Map<String, dynamic> j) {
    final exam = Map<String, dynamic>.from(j['exam'] as Map);
    final batch = Map<String, dynamic>.from(j['batch'] as Map);
    return MarksSheet(
      examId: _str(exam['id']),
      examName: _str(exam['name']),
      totalMarks: _int(exam['totalMarks']),
      isPublished: _bool(exam['isPublished']),
      batchName: _str(batch['name']),
      subjects: ((j['subjects'] as List?) ?? [])
          .map((s) => ExamSubject.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
      rows: ((j['rows'] as List?) ?? [])
          .map((r) => MarksSheetRow.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
    );
  }
}

class StudentResults {
  StudentResults({
    required this.student,
    required this.examsTaken,
    required this.averagePercentage,
    required this.bestPercentage,
    required this.results,
    this.bestRank,
  });

  final StudentRef student;
  final int examsTaken;
  final double averagePercentage, bestPercentage;
  final int? bestRank;
  final List<ExamResult> results;

  factory StudentResults.fromJson(Map<String, dynamic> j) {
    final s = Map<String, dynamic>.from(j['summary'] as Map);
    return StudentResults(
      student:
          StudentRef.fromJson(Map<String, dynamic>.from(j['student'] as Map)),
      examsTaken: _int(s['examsTaken']),
      averagePercentage: _num(s['averagePercentage']).toDouble(),
      bestPercentage: _num(s['bestPercentage']).toDouble(),
      bestRank: s['bestRank'] == null ? null : _int(s['bestRank']),
      results: ((j['results'] as List?) ?? [])
          .map((r) => ExamResult.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
    );
  }
}

// ── study material ────────────────────────────────────────────
class StudyMaterial {
  StudyMaterial({
    required this.id,
    required this.title,
    required this.subject,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    this.description,
    this.batchId,
    this.batchName,
    this.uploadedBy,
    this.createdAt,
  });

  final String id, title, subject, fileName, fileUrl, fileType;
  final int fileSize;
  final String? description, batchId, batchName, uploadedBy;
  final DateTime? createdAt;

  bool get isPdf => fileType.contains('pdf');

  factory StudyMaterial.fromJson(Map<String, dynamic> j) {
    final batch = j['batch'];
    return StudyMaterial(
      id: _str(j['id']),
      title: _str(j['title']),
      subject: _str(j['subject']),
      fileName: _str(j['fileName']),
      fileUrl: fixFileUrl(_str(j['fileUrl'])),
      fileType: _str(j['fileType']),
      fileSize: _int(j['fileSize']),
      description: j['description'] as String?,
      batchId: j['batchId'] as String?,
      batchName: batch is Map ? _str(batch['name']) : null,
      uploadedBy: j['uploadedBy'] is Map
          ? _str((j['uploadedBy'] as Map)['name'])
          : null,
      createdAt: _date(j['createdAt']),
    );
  }
}

// ── announcements ─────────────────────────────────────────────
class Announcement {
  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.isPinned,
    this.batchId,
    this.batchName,
    this.authorName,
    this.createdAt,
  });

  final String id, title, body, audience;
  final bool isPinned;
  final String? batchId, batchName, authorName;
  final DateTime? createdAt;

  bool get isForAll => audience == 'ALL';

  factory Announcement.fromJson(Map<String, dynamic> j) {
    final batch = j['batch'];
    return Announcement(
      id: _str(j['id']),
      title: _str(j['title']),
      body: _str(j['body']),
      audience: _str(j['audience']),
      isPinned: _bool(j['isPinned']),
      batchId: j['batchId'] as String?,
      batchName: batch is Map ? _str(batch['name']) : null,
      authorName:
          j['author'] is Map ? _str((j['author'] as Map)['name']) : null,
      createdAt: _date(j['createdAt']),
    );
  }
}

// ── dashboards ────────────────────────────────────────────────
class AdminDashboard {
  AdminDashboard({
    required this.totalStudents,
    required this.activeStudents,
    required this.totalBatches,
    required this.activeBatches,
    required this.todayAttendance,
    required this.todayMarked,
    required this.todayExpected,
    required this.todayIsMarked,
    required this.totalFee,
    required this.collected,
    required this.pending,
    required this.overdueAmount,
    required this.pendingInstallments,
    required this.overdueInstallments,
    required this.collectionRate,
    required this.materialCount,
    required this.announcements,
    required this.upcomingExams,
  });

  final int totalStudents, activeStudents, totalBatches, activeBatches;
  final double todayAttendance;
  final int todayMarked, todayExpected;
  final bool todayIsMarked;
  final num totalFee, collected, pending, overdueAmount;
  final int pendingInstallments, overdueInstallments;
  final double collectionRate;
  final int materialCount;
  final List<Announcement> announcements;
  final List<Exam> upcomingExams;

  factory AdminDashboard.fromJson(Map<String, dynamic> j) {
    final s = Map<String, dynamic>.from(j['students'] as Map);
    final b = Map<String, dynamic>.from(j['batches'] as Map);
    final a = Map<String, dynamic>.from(j['todayAttendance'] as Map);
    final f = Map<String, dynamic>.from(j['fees'] as Map);
    return AdminDashboard(
      totalStudents: _int(s['total']),
      activeStudents: _int(s['active']),
      totalBatches: _int(b['total']),
      activeBatches: _int(b['active']),
      todayAttendance: _num(a['percentage']).toDouble(),
      todayMarked: _int(a['marked']),
      todayExpected: _int(a['expected']),
      todayIsMarked: _bool(a['isMarked']),
      totalFee: _num(f['totalFee']),
      collected: _num(f['collected']),
      pending: _num(f['pending']),
      overdueAmount: _num(f['overdueAmount']),
      pendingInstallments: _int(f['pendingInstallments']),
      overdueInstallments: _int(f['overdueInstallments']),
      collectionRate: _num(f['collectionRate']).toDouble(),
      materialCount: _int(j['materialCount']),
      announcements: ((j['recentAnnouncements'] as List?) ?? [])
          .map((x) => Announcement.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
      upcomingExams: ((j['upcomingExams'] as List?) ?? [])
          .map((x) => Exam.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
    );
  }
}

class StudentDashboard {
  StudentDashboard({
    required this.name,
    required this.studentCode,
    required this.course,
    required this.attendance,
    required this.fees,
    required this.announcements,
    required this.recentResults,
    required this.materialCount,
    this.batch,
    this.nextClass,
    this.admissionDate,
  });

  final String name, studentCode, course;
  final AttendanceSummary attendance;
  final FeeSummary fees;
  final List<Announcement> announcements;
  final List<ExamResult> recentResults;
  final int materialCount;
  final BatchRef? batch;
  final NextClass? nextClass;
  final DateTime? admissionDate;

  factory StudentDashboard.fromJson(Map<String, dynamic> j) {
    final s = Map<String, dynamic>.from(j['student'] as Map);
    return StudentDashboard(
      name: _str(s['name']),
      studentCode: _str(s['studentCode']),
      course: _str(s['course']),
      admissionDate: _date(s['admissionDate']),
      batch: s['batch'] is Map
          ? BatchRef.fromJson(Map<String, dynamic>.from(s['batch'] as Map))
          : null,
      attendance: AttendanceSummary.fromJson(
          Map<String, dynamic>.from(j['attendance'] as Map)),
      fees: FeeSummary.fromJson(Map<String, dynamic>.from(j['fees'] as Map)),
      nextClass: j['nextClass'] is Map
          ? NextClass.fromJson(Map<String, dynamic>.from(j['nextClass'] as Map))
          : null,
      announcements: ((j['recentAnnouncements'] as List?) ?? [])
          .map((x) => Announcement.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
      recentResults: ((j['recentResults'] as List?) ?? [])
          .map((x) => ExamResult.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
      materialCount: _int(j['materialCount']),
    );
  }
}

// ── paging ────────────────────────────────────────────────────
class Paged<T> {
  Paged({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.hasNext,
  });

  final List<T> items;
  final int page, totalPages, total;
  final bool hasNext;

  factory Paged.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) parse,
  ) {
    final meta = j['meta'] is Map
        ? Map<String, dynamic>.from(j['meta'] as Map)
        : const <String, dynamic>{};
    return Paged(
      items: ((j['data'] as List?) ?? [])
          .map((e) => parse(Map<String, dynamic>.from(e)))
          .toList(),
      page: _int(meta['page']),
      totalPages: _int(meta['totalPages']),
      total: _int(meta['total']),
      hasNext: _bool(meta['hasNext']),
    );
  }
}

// ── chat ──────────────────────────────────────────────────────
enum ConversationType { direct, batch }

ConversationType conversationTypeFrom(String? v) =>
    v == 'BATCH' ? ConversationType.batch : ConversationType.direct;

class ChatParticipant {
  ChatParticipant({
    required this.id,
    required this.name,
    required this.role,
    this.studentCode,
  });

  final String id;
  final String name;
  final String role;
  final String? studentCode;

  bool get isAdmin => role == 'ADMIN';

  factory ChatParticipant.fromJson(Map<String, dynamic> j) => ChatParticipant(
        id: _str(j['id']),
        name: _str(j['name']),
        role: _str(j['role']),
        studentCode: j['studentCode'] as String?,
      );
}

class Conversation {
  Conversation({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.isLocked,
    required this.unreadCount,
    required this.memberCount,
    required this.participants,
    this.lastMessageAt,
    this.lastMessageText,
    this.batchName,
  });

  final String id;
  final ConversationType type;
  final String title;
  final String subtitle;
  final bool isLocked;
  final int unreadCount;
  final int memberCount;
  final List<ChatParticipant> participants;
  final DateTime? lastMessageAt;
  final String? lastMessageText;
  final String? batchName;

  bool get isBatch => type == ConversationType.batch;

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: _str(j['id']),
        type: conversationTypeFrom(j['type'] as String?),
        title: _str(j['title']),
        subtitle: _str(j['subtitle']),
        isLocked: _bool(j['isLocked']),
        unreadCount: _int(j['unreadCount']),
        memberCount: _int(j['memberCount']),
        lastMessageAt: _date(j['lastMessageAt']),
        lastMessageText: j['lastMessageText'] as String?,
        batchName:
            j['batch'] is Map ? _str((j['batch'] as Map)['name']) : null,
        participants: ((j['participants'] as List?) ?? [])
            .map((p) => ChatParticipant.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.body,
    required this.isMine,
    required this.isDeleted,
    required this.senderName,
    this.senderId,
    this.senderRole,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String body;
  final bool isMine;
  final bool isDeleted;
  final String senderName;
  final String? senderId;
  final String? senderRole;
  final DateTime? createdAt;

  bool get fromAdmin => senderRole == 'ADMIN';

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: _str(j['id']),
        conversationId: _str(j['conversationId']),
        body: _str(j['body']),
        isMine: _bool(j['isMine']),
        isDeleted: _bool(j['isDeleted']),
        senderName: _str(j['senderName']),
        senderId: j['senderId'] as String?,
        senderRole: j['senderRole'] as String?,
        createdAt: _date(j['createdAt']),
      );

  /// Optimistic local echo shown immediately while the POST is in flight.
  factory ChatMessage.pending({
    required String conversationId,
    required String body,
    required String senderName,
  }) =>
      ChatMessage(
        id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
        conversationId: conversationId,
        body: body,
        isMine: true,
        isDeleted: false,
        senderName: senderName,
        createdAt: DateTime.now(),
      );

  bool get isPending => id.startsWith('pending-');
}

class MessagePage {
  MessagePage({
    required this.messages,
    required this.hasMore,
    required this.isLocked,
  });

  final List<ChatMessage> messages;
  final bool hasMore;
  final bool isLocked;

  factory MessagePage.fromJson(Map<String, dynamic> j) => MessagePage(
        hasMore: _bool(j['hasMore']),
        isLocked: j['conversation'] is Map
            ? _bool((j['conversation'] as Map)['isLocked'])
            : false,
        messages: ((j['messages'] as List?) ?? [])
            .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

class ChatContact {
  ChatContact({
    required this.id,
    required this.name,
    required this.role,
    this.studentCode,
    this.batchName,
  });

  final String id;
  final String name;
  final String role;
  final String? studentCode;
  final String? batchName;

  bool get isAdmin => role == 'ADMIN';

  factory ChatContact.fromJson(Map<String, dynamic> j) => ChatContact(
        id: _str(j['id']),
        name: _str(j['name']),
        role: _str(j['role']),
        studentCode: j['studentCode'] as String?,
        batchName: j['batchName'] as String?,
      );
}


// ── maintenance ───────────────────────────────────────────────
class KeptData {
  KeptData({
    required this.admins,
    required this.students,
    required this.batches,
    required this.announcements,
    required this.materials,
  });

  final int admins, students, batches, announcements, materials;

  /// True once the institute has entered anything of their own.
  bool get hasAny =>
      students > 0 || batches > 0 || announcements > 0 || materials > 0;

  factory KeptData.fromJson(Map<String, dynamic> j) => KeptData(
        admins: _int(j['admins']),
        students: _int(j['students']),
        batches: _int(j['batches']),
        announcements: _int(j['announcements']),
        materials: _int(j['materials']),
      );
}

class DemoSummary {
  DemoSummary({
    required this.hasDemoData,
    required this.keeps,
    required this.students,
    required this.batches,
    required this.announcements,
    required this.materials,
    required this.attendanceRecords,
    required this.feeInstallments,
    required this.exams,
    required this.chatMessages,
    required this.demoAdmins,
  });

  final bool hasDemoData;
  final KeptData keeps;
  final int students,
      batches,
      announcements,
      materials,
      attendanceRecords,
      feeInstallments,
      exams,
      chatMessages,
      demoAdmins;

  factory DemoSummary.fromJson(Map<String, dynamic> j) => DemoSummary(
        hasDemoData: _bool(j['hasDemoData']),
        keeps: KeptData.fromJson(
          j['keeps'] is Map
              ? Map<String, dynamic>.from(j['keeps'] as Map)
              : const {},
        ),
        students: _int(j['students']),
        batches: _int(j['batches']),
        announcements: _int(j['announcements']),
        materials: _int(j['materials']),
        attendanceRecords: _int(j['attendanceRecords']),
        feeInstallments: _int(j['feeInstallments']),
        exams: _int(j['exams']),
        chatMessages: _int(j['chatMessages']),
        demoAdmins: _int(j['demoAdmins']),
      );
}
