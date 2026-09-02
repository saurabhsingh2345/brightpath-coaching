import 'package:flutter_test/flutter_test.dart';
import 'package:brightpath_coaching/models/models.dart';

void main() {
  group('forgiving parsing', () {
    test('a student with missing optional fields still parses', () {
      final s = Student.fromJson({
        'id': 'abc',
        'studentCode': 'BP2026001',
        'name': 'Aarav Sharma',
        'phone': '9811000000',
        'email': 'aarav@brightpath.edu',
        'parentName': 'Rajesh Sharma',
        'parentPhone': '9722000000',
        'address': '12 Green Park',
        'course': 'JEE Main 2027',
        // no batch, no isActive, no admissionDate, no summaries
      });
      expect(s.name, 'Aarav Sharma');
      expect(s.batch, isNull);
      expect(s.isActive, isTrue, reason: 'absent isActive should default true');
      expect(s.attendanceSummary, isNull);
    });

    test('fee derives its balance when the server omits it', () {
      final fee = Fee.fromJson({
        'id': 'f1',
        'title': 'Term 1',
        'totalAmount': 20000,
        'paidAmount': 8000,
        'status': 'PARTIAL',
        'installmentNo': 1,
        'totalInstallments': 3,
      });
      expect(fee.balance, 12000);
      expect(fee.isPaid, isFalse);
    });

    test('numeric strings coerce instead of crashing', () {
      final fee = Fee.fromJson({
        'id': 'f2',
        'title': 'Term 2',
        'totalAmount': '15000.50',
        'paidAmount': '15000.50',
        'balance': '0',
        'status': 'PAID',
        'installmentNo': '2',
        'totalInstallments': '3',
      });
      expect(fee.totalAmount, 15000.50);
      expect(fee.installmentNo, 2);
      expect(fee.isPaid, isTrue);
    });

    test('attendance percentage comes through as a double', () {
      final summary = AttendanceSummary.fromJson({
        'PRESENT': 14,
        'ABSENT': 3,
        'LATE': 1,
        'LEAVE': 0,
        'total': 18,
        'percentage': 83.3,
        'todayStatus': 'PRESENT',
      });
      expect(summary.percentage, 83.3);
      expect(summary.present + summary.late, 15);
      expect(summary.todayStatus, 'PRESENT');
    });

    test('paged meta survives an empty payload', () {
      final page = Paged<Student>.fromJson({}, Student.fromJson);
      expect(page.items, isEmpty);
      expect(page.hasNext, isFalse);
    });
  });

  group('chat', () {
    test('a batch conversation is flagged and typed', () {
      final c = Conversation.fromJson({
        'id': 'c1',
        'type': 'BATCH',
        'title': 'JEE Morning A',
        'subtitle': '5 members',
        'isLocked': true,
        'unreadCount': 3,
        'memberCount': 5,
        'lastMessageText': 'Noted, thank you!',
        'participants': [
          {'id': 'u1', 'name': 'Priya Nair', 'role': 'ADMIN'},
        ],
      });
      expect(c.isBatch, isTrue);
      expect(c.isLocked, isTrue);
      expect(c.unreadCount, 3);
      expect(c.participants.single.isAdmin, isTrue);
    });

    test('an optimistic message is marked pending until replaced', () {
      final pending = ChatMessage.pending(
        conversationId: 'c1',
        body: 'Hello',
        senderName: 'Aarav',
      );
      expect(pending.isPending, isTrue);
      expect(pending.isMine, isTrue);

      final saved = ChatMessage.fromJson({
        'id': 'm1',
        'conversationId': 'c1',
        'body': 'Hello',
        'isMine': true,
        'isDeleted': false,
        'senderName': 'Aarav',
        'senderRole': 'STUDENT',
      });
      expect(saved.isPending, isFalse);
      expect(saved.fromAdmin, isFalse);
    });
  });

  test('file URLs pointing at localhost are rewritten for the device', () {
    final rewritten = fixFileUrl('http://localhost:4000/files/notes.pdf');
    expect(rewritten, endsWith('/files/notes.pdf'));
    expect(rewritten, isNot(contains('localhost')));
  });
}
