import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reminder.dart';

class ReminderRepository {
  ReminderRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<Reminder>> watchForUser(String userId) {
    return _db
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final values = snapshot.docs
              .map(Reminder.fromDocument)
              .where((value) => !value.completed)
              .toList();
          _sort(values);
          return values;
        });
  }

  Stream<List<Reminder>> watchAllForVehicle(String userId, String vehicleId) {
    return _db
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .where('vehicleId', isEqualTo: vehicleId)
        .snapshots()
        .map((snapshot) {
          final values = snapshot.docs.map(Reminder.fromDocument).toList();
          _sort(values);
          return values;
        });
  }

  Future<void> syncMaintenanceReminders({
    required String sourceExpenseId,
    required String userId,
    required String vehicleId,
    required List<Reminder> reminders,
  }) async {
    final existing = await _db
        .collection('reminders')
        .where('sourceExpenseId', isEqualTo: sourceExpenseId)
        .get();
    final batch = _db.batch();
    for (final document in existing.docs) {
      batch.delete(document.reference);
    }
    for (final reminder in reminders) {
      batch.set(_db.collection('reminders').doc(), reminder.toFirestore());
    }
    await batch.commit();
  }

  Future<void> deleteForExpense(String sourceExpenseId) async {
    final existing = await _db
        .collection('reminders')
        .where('sourceExpenseId', isEqualTo: sourceExpenseId)
        .get();
    final batch = _db.batch();
    for (final document in existing.docs) {
      batch.delete(document.reference);
    }
    await batch.commit();
  }

  Future<void> add(Reminder reminder) async {
    await _db.collection('reminders').add(reminder.toFirestore());
  }

  Future<void> update(Reminder reminder) async {
    if (reminder.id.trim().isEmpty) {
      throw ArgumentError('Hatırlatma kimliği boş olamaz.');
    }
    final data = reminder.toFirestore()..remove('createdAt');
    await _db.collection('reminders').doc(reminder.id).update(data);
  }

  Future<void> setCompleted(String reminderId, bool completed) async {
    if (reminderId.trim().isEmpty) {
      return;
    }
    await _db.collection('reminders').doc(reminderId).update({
      'completed': completed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String reminderId) async {
    if (reminderId.trim().isEmpty) {
      return;
    }
    await _db.collection('reminders').doc(reminderId).delete();
  }

  static void _sort(List<Reminder> values) {
    values.sort((a, b) {
      if (a.completed != b.completed) {
        return a.completed ? 1 : -1;
      }
      if (a.dueDate == null && b.dueDate == null) {
        return (a.dueKilometer ?? 1 << 30).compareTo(b.dueKilometer ?? 1 << 30);
      }
      if (a.dueDate == null) {
        return 1;
      }
      if (b.dueDate == null) {
        return -1;
      }
      return a.dueDate!.compareTo(b.dueDate!);
    });
  }
}
