import 'package:cloud_firestore/cloud_firestore.dart';

class Reminder {
  const Reminder({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.title,
    this.dueDate,
    this.dueKilometer,
    this.note,
    this.sourceExpenseId,
    this.maintenanceItemId,
    this.maintenanceItemType,
    this.completed = false,
  });

  final String id;
  final String userId;
  final String vehicleId;
  final String title;
  final DateTime? dueDate;
  final int? dueKilometer;
  final String? note;
  final String? sourceExpenseId;
  final String? maintenanceItemId;
  final String? maintenanceItemType;
  final bool completed;

  factory Reminder.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Reminder(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      vehicleId: data['vehicleId'] as String? ?? '',
      title: data['title'] as String? ?? 'Bakım',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      dueKilometer: (data['dueKilometer'] as num?)?.toInt(),
      note: data['note'] as String?,
      sourceExpenseId: data['sourceExpenseId'] as String?,
      maintenanceItemId: data['maintenanceItemId'] as String?,
      maintenanceItemType: data['maintenanceItemType'] as String?,
      completed: data['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'vehicleId': vehicleId,
    'title': title,
    'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
    'dueKilometer': dueKilometer,
    'note': note,
    'sourceExpenseId': sourceExpenseId,
    'maintenanceItemId': maintenanceItemId,
    'maintenanceItemType': maintenanceItemType,
    'completed': completed,
    'updatedAt': FieldValue.serverTimestamp(),
    'createdAt': FieldValue.serverTimestamp(),
  };
}
