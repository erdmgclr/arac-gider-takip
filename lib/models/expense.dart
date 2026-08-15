import 'package:cloud_firestore/cloud_firestore.dart';
import 'maintenance_item.dart';

enum ExpenseType {
  fuel,
  charge,
  maintenance,
  tax,
  insurance,
  inspection,
  toll,
  parking,
  fine,
  tire,
  other,
}

class Expense {
  const Expense({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.type,
    this.subType,
    this.isFullTank,
    this.nextDueDate,
    this.stationName,
    this.receiptNumber,
    this.documentName,
    this.documentMimeType,
    this.maintenanceType,
    this.serviceName,
    this.laborCost,
    this.maintenanceItems = const <MaintenanceItem>[],
    this.replacedItems = const <String>[],
    this.nextMaintenanceDate,
    this.nextMaintenanceKilometer,
    required this.amount,
    this.quantity,
    this.unitPrice,
    this.kilometer,
    required this.expenseDate,
    this.note,
    this.localDocumentPath,
    this.driveDocumentId,
    this.importKey,
    this.importSource,
  });

  final String id;
  final String userId;
  final String vehicleId;
  final ExpenseType type;
  final String? subType;
  final bool? isFullTank;
  final DateTime? nextDueDate;
  final String? stationName;
  final String? receiptNumber;
  final String? documentName;
  final String? documentMimeType;
  final String? maintenanceType;
  final String? serviceName;
  final double? laborCost;
  final List<MaintenanceItem> maintenanceItems;
  final List<String> replacedItems;
  final DateTime? nextMaintenanceDate;
  final int? nextMaintenanceKilometer;
  final double amount;
  final double? quantity;
  final double? unitPrice;
  final int? kilometer;
  final DateTime expenseDate;
  final String? note;
  final String? localDocumentPath;
  final String? driveDocumentId;
  final String? importKey;
  final String? importSource;

  List<MaintenanceItem> get effectiveMaintenanceItems {
    if (maintenanceItems.isNotEmpty) return maintenanceItems;
    return MaintenanceItem.fromLegacy(
      replacedItems,
      nextMaintenanceKilometer,
      nextMaintenanceDate,
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'userId': userId,
    'vehicleId': vehicleId,
    'type': type.name.toUpperCase(),
    'subType': subType,
    'isFullTank': isFullTank,
    'nextDueDate': nextDueDate == null
        ? null
        : Timestamp.fromDate(nextDueDate!),
    'stationName': stationName,
    'receiptNumber': receiptNumber,
    'documentName': documentName,
    'documentMimeType': documentMimeType,
    'maintenanceType': maintenanceType,
    'serviceName': serviceName,
    'laborCost': laborCost,
    'maintenanceItems': maintenanceItems.map((e) => e.toFirestore()).toList(),
    'replacedItems': replacedItems,
    'nextMaintenanceDate': nextMaintenanceDate == null
        ? null
        : Timestamp.fromDate(nextMaintenanceDate!),
    'nextMaintenanceKilometer': nextMaintenanceKilometer,
    'amount': amount,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'km': kilometer,
    'expenseDate': Timestamp.fromDate(expenseDate),
    'note': note,
    'localDocumentPath': localDocumentPath,
    'driveDocumentId': driveDocumentId,
    'importKey': importKey,
    'importSource': importSource,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory Expense.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final rawType = data['type'] as String? ?? 'OTHER';
    return Expense(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      vehicleId: data['vehicleId'] as String? ?? '',
      type: ExpenseType.values.firstWhere(
        (value) => value.name.toUpperCase() == rawType,
        orElse: () => ExpenseType.other,
      ),
      subType: data['subType'] as String?,
      isFullTank: data['isFullTank'] as bool?,
      nextDueDate: (data['nextDueDate'] as Timestamp?)?.toDate(),
      stationName: data['stationName'] as String?,
      receiptNumber: data['receiptNumber'] as String?,
      documentName: data['documentName'] as String?,
      documentMimeType: data['documentMimeType'] as String?,
      maintenanceType: data['maintenanceType'] as String?,
      serviceName: data['serviceName'] as String?,
      laborCost: (data['laborCost'] as num?)?.toDouble(),
      maintenanceItems:
          (data['maintenanceItems'] as List?)
              ?.whereType<Map>()
              .map((e) => MaintenanceItem.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const <MaintenanceItem>[],
      replacedItems: List<String>.from(
        data['replacedItems'] as List? ?? const [],
      ),
      nextMaintenanceDate: (data['nextMaintenanceDate'] as Timestamp?)
          ?.toDate(),
      nextMaintenanceKilometer: (data['nextMaintenanceKilometer'] as num?)
          ?.toInt(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      quantity: (data['quantity'] as num?)?.toDouble(),
      unitPrice: (data['unitPrice'] as num?)?.toDouble(),
      kilometer: (data['km'] as num?)?.toInt(),
      expenseDate:
          (data['expenseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'] as String?,
      localDocumentPath: data['localDocumentPath'] as String?,
      driveDocumentId: data['driveDocumentId'] as String?,
      importKey: data['importKey'] as String?,
      importSource: data['importSource'] as String?,
    );
  }
}
