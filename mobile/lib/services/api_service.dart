import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/models.dart';

/// One typed facade over every backend endpoint the app uses.
class ApiService {
  ApiService(this._c);
  final ApiClient _c;

  String _str(dynamic v) => v?.toString() ?? '';

  Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.map(_map).toList() : const [];

  // ── auth ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _c.post<dynamic>(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
      skipAuth: true,
    );
    return _map(res);
  }

  Future<void> logout() async {
    try {
      await _c.post<dynamic>('/auth/logout');
    } catch (_) {
      // Local sign-out must succeed even if the server call fails.
    }
  }

  Future<AppUser> me() async => AppUser.fromJson(_map(await _c.get('/auth/me')));

  Future<Map<String, dynamic>> meFull() async => _map(await _c.get('/auth/me'));

  Future<AppUser> updateMe({String? name, String? phone}) async =>
      AppUser.fromJson(_map(await _c.patch(
        '/auth/me',
        body: {if (name != null) 'name': name, if (phone != null) 'phone': phone},
      )));

  Future<String> changePassword(String current, String next) async {
    final r = _map(await _c.post(
      '/auth/change-password',
      body: {'currentPassword': current, 'newPassword': next},
    ));
    return r['message'] as String? ?? 'Password updated';
  }

  // ── dashboards ──────────────────────────────────────────────
  Future<AdminDashboard> adminDashboard() async =>
      AdminDashboard.fromJson(_map(await _c.get('/dashboard/admin')));

  Future<StudentDashboard> studentDashboard() async =>
      StudentDashboard.fromJson(_map(await _c.get('/dashboard/student')));

  // ── students ────────────────────────────────────────────────
  Future<Paged<Student>> students({
    int page = 1,
    int limit = 20,
    String? search,
    String? batchId,
    bool? isActive,
  }) async =>
      Paged.fromJson(
        _map(await _c.get('/students', query: {
          'page': page,
          'limit': limit,
          'search': search,
          'batchId': batchId,
          'isActive': isActive?.toString(),
        })),
        Student.fromJson,
      );

  Future<Student> student(String id) async =>
      Student.fromJson(_map(await _c.get('/students/$id')));

  Future<Student> createStudent(Map<String, dynamic> body) async =>
      Student.fromJson(_map(await _c.post('/students', body: body)));

  Future<Student> updateStudent(String id, Map<String, dynamic> body) async =>
      Student.fromJson(_map(await _c.patch('/students/$id', body: body)));

  Future<String> setStudentActive(String id, bool active) async {
    final r = _map(await _c
        .patch('/students/$id/${active ? 'activate' : 'deactivate'}'));
    return r['message'] as String? ?? 'Updated';
  }

  Future<void> deleteStudent(String id) => _c.delete('/students/$id');

  // ── batches ─────────────────────────────────────────────────
  Future<List<Batch>> batches({bool? isActive, String? search}) async {
    final res = _map(await _c.get('/batches', query: {
      'limit': 100,
      'isActive': isActive?.toString(),
      'search': search,
    }));
    return _list(res['data']).map(Batch.fromJson).toList();
  }

  Future<Map<String, dynamic>> batchDetail(String id) async =>
      _map(await _c.get('/batches/$id'));

  Future<Batch> createBatch(Map<String, dynamic> body) async =>
      Batch.fromJson(_map(await _c.post('/batches', body: body)));

  Future<Batch> updateBatch(String id, Map<String, dynamic> body) async =>
      Batch.fromJson(_map(await _c.patch('/batches/$id', body: body)));

  Future<void> deleteBatch(String id) => _c.delete('/batches/$id');

  Future<String> assignStudents(String batchId, List<String> ids) async {
    final r = _map(
        await _c.post('/batches/$batchId/students', body: {'studentIds': ids}));
    return r['message'] as String? ?? 'Assigned';
  }

  Future<void> removeFromBatch(String batchId, String studentId) =>
      _c.delete('/batches/$batchId/students/$studentId');

  // ── attendance ──────────────────────────────────────────────
  Future<AttendanceSheet> attendanceSheet(String batchId, String date) async =>
      AttendanceSheet.fromJson(_map(await _c
          .get('/attendance/sheet', query: {'batchId': batchId, 'date': date})));

  Future<Map<String, dynamic>> markAttendance({
    required String batchId,
    required String date,
    required List<Map<String, dynamic>> entries,
  }) async =>
      _map(await _c.post('/attendance/mark',
          body: {'batchId': batchId, 'date': date, 'entries': entries}));

  Future<List<AttendanceDay>> attendanceDays(String batchId,
          {String? from, String? to}) async =>
      _list(await _c.get('/attendance/batch/$batchId/days',
              query: {'from': from, 'to': to}))
          .map(AttendanceDay.fromJson)
          .toList();

  Future<List<AttendanceRecord>> attendanceHistory({
    String? batchId,
    String? studentId,
    String? from,
    String? to,
    String? status,
  }) async =>
      _list(await _c.get('/attendance/history', query: {
        'batchId': batchId,
        'studentId': studentId,
        'from': from,
        'to': to,
        'status': status,
      })).map(AttendanceRecord.fromJson).toList();

  Future<AttendanceReport> studentAttendance(String studentId) async =>
      AttendanceReport.fromJson(
          _map(await _c.get('/attendance/student/$studentId')));

  Future<AttendanceReport> myAttendance() async =>
      AttendanceReport.fromJson(_map(await _c.get('/attendance/me')));

  // ── fees ────────────────────────────────────────────────────
  Future<Paged<Fee>> fees({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? batchId,
    String? studentId,
  }) async =>
      Paged.fromJson(
        _map(await _c.get('/fees', query: {
          'page': page,
          'limit': limit,
          'search': search,
          'status': status,
          'batchId': batchId,
          'studentId': studentId,
        })),
        Fee.fromJson,
      );

  Future<StudentFeeLedger> studentFees(String studentId) async =>
      StudentFeeLedger.fromJson(_map(await _c.get('/fees/student/$studentId')));

  Future<StudentFeeLedger> myFees() async =>
      StudentFeeLedger.fromJson(_map(await _c.get('/fees/me')));

  Future<String> createFeePlan({
    required String studentId,
    required List<Map<String, dynamic>> installments,
    String? notes,
  }) async {
    final r = _map(await _c.post('/fees/plan', body: {
      'studentId': studentId,
      'installments': installments,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    }));
    return r['message'] as String? ?? 'Fee plan created';
  }

  Future<Fee> createFee(Map<String, dynamic> body) async =>
      Fee.fromJson(_map(await _c.post('/fees', body: body)));

  Future<Fee> updateFee(String id, Map<String, dynamic> body) async =>
      Fee.fromJson(_map(await _c.patch('/fees/$id', body: body)));

  Future<void> deleteFee(String id) => _c.delete('/fees/$id');

  Future<Map<String, dynamic>> recordPayment(
    String feeId, {
    required num amount,
    String mode = 'CASH',
    String? reference,
  }) async =>
      _map(await _c.post('/fees/$feeId/payments', body: {
        'amount': amount,
        'mode': mode,
        if (reference != null && reference.isNotEmpty) 'reference': reference,
      }));

  Future<List<FeePayment>> payments({String? studentId, String? feeId}) async =>
      _list(await _c.get('/fees/payments',
              query: {'studentId': studentId, 'feeId': feeId}))
          .map(FeePayment.fromJson)
          .toList();

  Future<Receipt> receipt(String paymentId) async =>
      Receipt.fromJson(_map(await _c.get('/fees/receipt/$paymentId')));

  // ── timetable ───────────────────────────────────────────────
  Future<WeeklyTimetable> weeklyTimetable(String batchId) async =>
      WeeklyTimetable.fromJson(_map(await _c.get('/timetable/batch/$batchId')));

  Future<WeeklyTimetable> myTimetable() async =>
      WeeklyTimetable.fromJson(_map(await _c.get('/timetable/me')));

  Future<TimetableSlot> createSlot(Map<String, dynamic> body) async =>
      TimetableSlot.fromJson(_map(await _c.post('/timetable', body: body)));

  Future<TimetableSlot> updateSlot(String id, Map<String, dynamic> body) async =>
      TimetableSlot.fromJson(_map(await _c.patch('/timetable/$id', body: body)));

  Future<void> deleteSlot(String id) => _c.delete('/timetable/$id');

  // ── exams ───────────────────────────────────────────────────
  Future<List<Exam>> exams({String? batchId}) async =>
      _list(await _c.get('/exams', query: {'batchId': batchId}))
          .map(Exam.fromJson)
          .toList();

  Future<Exam> exam(String id) async =>
      Exam.fromJson(_map(await _c.get('/exams/$id')));

  Future<MarksSheet> marksSheet(String examId) async =>
      MarksSheet.fromJson(_map(await _c.get('/exams/$examId/marks-sheet')));

  Future<Exam> createExam(Map<String, dynamic> body) async =>
      Exam.fromJson(_map(await _c.post('/exams', body: body)));

  Future<Exam> updateExam(String id, Map<String, dynamic> body) async =>
      Exam.fromJson(_map(await _c.patch('/exams/$id', body: body)));

  Future<void> deleteExam(String id) => _c.delete('/exams/$id');

  Future<String> saveMarks(
      String examId, List<Map<String, dynamic>> results) async {
    final r = _map(
        await _c.post('/exams/$examId/results/bulk', body: {'results': results}));
    return r['message'] as String? ?? 'Marks saved';
  }

  Future<StudentResults> studentResults(String studentId) async =>
      StudentResults.fromJson(_map(await _c.get('/exams/student/$studentId')));

  Future<StudentResults> myResults() async =>
      StudentResults.fromJson(_map(await _c.get('/exams/me')));

  // ── materials ───────────────────────────────────────────────
  Future<List<StudyMaterial>> materials({
    String? batchId,
    String? subject,
    String? search,
  }) async =>
      _list(await _c.get('/materials',
              query: {'batchId': batchId, 'subject': subject, 'search': search}))
          .map(StudyMaterial.fromJson)
          .toList();

  Future<List<StudyMaterial>> myMaterials({
    String? subject,
    String? search,
  }) async =>
      _list(await _c
              .get('/materials/me', query: {'subject': subject, 'search': search}))
          .map(StudyMaterial.fromJson)
          .toList();

  /// On Android [filePath] is set; in a browser there is no filesystem, so
  /// file_picker hands us [bytes] instead. Exactly one of the two is required.
  Future<StudyMaterial> uploadMaterial({
    required String title,
    required String subject,
    required String fileName,
    String? filePath,
    Uint8List? bytes,
    String? description,
    String? batchId,
  }) async {
    final MultipartFile file;
    if (bytes != null) {
      file = MultipartFile.fromBytes(bytes, filename: fileName);
    } else if (filePath != null) {
      file = await MultipartFile.fromFile(filePath, filename: fileName);
    } else {
      throw ApiException('No file was selected');
    }

    final form = FormData.fromMap({
      'title': title,
      'subject': subject,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
      'file': file,
    });
    return StudyMaterial.fromJson(
        _map(await _c.postMultipart('/materials', form)));
  }

  Future<void> deleteMaterial(String id) => _c.delete('/materials/$id');

  // ── announcements ───────────────────────────────────────────
  Future<List<Announcement>> announcements({
    String? batchId,
    String? search,
  }) async =>
      _list(await _c
              .get('/announcements', query: {'batchId': batchId, 'search': search}))
          .map(Announcement.fromJson)
          .toList();

  Future<List<Announcement>> myAnnouncements() async =>
      _list(await _c.get('/announcements/me'))
          .map(Announcement.fromJson)
          .toList();

  Future<Announcement> createAnnouncement(Map<String, dynamic> body) async =>
      Announcement.fromJson(_map(await _c.post('/announcements', body: body)));

  Future<Announcement> updateAnnouncement(
          String id, Map<String, dynamic> body) async =>
      Announcement.fromJson(
          _map(await _c.patch('/announcements/$id', body: body)));

  Future<void> deleteAnnouncement(String id) => _c.delete('/announcements/$id');

  // ── chat ────────────────────────────────────────────────────
  Future<List<Conversation>> conversations() async =>
      _list(await _c.get('/chat/conversations'))
          .map(Conversation.fromJson)
          .toList();

  Future<int> unreadTotal() async {
    final r = _map(await _c.get('/chat/unread'));
    return (r['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<ChatContact>> chatContacts({String? search}) async =>
      _list(await _c.get('/chat/contacts', query: {'search': search}))
          .map(ChatContact.fromJson)
          .toList();

  Future<String> startDirect(String userId) async {
    final r = _map(await _c.post('/chat/direct', body: {'userId': userId}));
    return _str(r['id']);
  }

  Future<MessagePage> messages(
    String conversationId, {
    String? before,
    int limit = 40,
  }) async =>
      MessagePage.fromJson(_map(await _c.get(
        '/chat/conversations/$conversationId/messages',
        query: {'before': before, 'limit': limit},
      )));

  Future<ChatMessage> sendMessage(String conversationId, String body) async =>
      ChatMessage.fromJson(_map(await _c.post(
        '/chat/conversations/$conversationId/messages',
        body: {'body': body},
      )));

  Future<void> markConversationRead(String conversationId) =>
      _c.patch('/chat/conversations/$conversationId/read');

  Future<String> setConversationLocked(String conversationId, bool locked) async {
    final r = _map(await _c.patch(
      '/chat/conversations/$conversationId/${locked ? 'lock' : 'unlock'}',
    ));
    return r['message'] as String? ?? 'Updated';
  }

  Future<ChatMessage> deleteMessage(String messageId) async =>
      ChatMessage.fromJson(_map(await _c.delete('/chat/messages/$messageId')));

  // ── maintenance ─────────────────────────────────────────────
  Future<DemoSummary> demoSummary() async =>
      DemoSummary.fromJson(_map(await _c.get('/maintenance/demo-summary')));

  Future<String> clearDemoData() async {
    final r = _map(await _c.post(
      '/maintenance/clear-demo-data',
      body: {'confirm': 'CLEAR DEMO DATA'},
    ));
    return r['message'] as String? ?? 'Demo data removed';
  }
}
