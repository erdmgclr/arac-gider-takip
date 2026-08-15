import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenanceItem {
  const MaintenanceItem({
    required this.id,
    required this.type,
    required this.title,
    this.brand,
    this.partNumber,
    this.quantity,
    this.unit,
    this.note,
    this.intervalKilometers,
    this.intervalMonths,
    this.nextDueKilometer,
    this.nextDueDate,
    this.reminderEnabled = true,
  });

  final String id;
  final String type;
  final String title;
  final String? brand;
  final String? partNumber;
  final double? quantity;
  final String? unit;
  final String? note;
  final int? intervalKilometers;
  final int? intervalMonths;
  final int? nextDueKilometer;
  final DateTime? nextDueDate;
  final bool reminderEnabled;

  MaintenanceItem copyWith({
    String? brand,
    String? partNumber,
    double? quantity,
    String? unit,
    String? note,
    int? intervalKilometers,
    int? intervalMonths,
    int? nextDueKilometer,
    DateTime? nextDueDate,
    bool? reminderEnabled,
  }) => MaintenanceItem(
    id: id,
    type: type,
    title: title,
    brand: brand ?? this.brand,
    partNumber: partNumber ?? this.partNumber,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    note: note ?? this.note,
    intervalKilometers: intervalKilometers ?? this.intervalKilometers,
    intervalMonths: intervalMonths ?? this.intervalMonths,
    nextDueKilometer: nextDueKilometer ?? this.nextDueKilometer,
    nextDueDate: nextDueDate ?? this.nextDueDate,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
  );

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'type': type,
    'title': title,
    'brand': brand,
    'partNumber': partNumber,
    'quantity': quantity,
    'unit': unit,
    'note': note,
    'intervalKilometers': intervalKilometers,
    'intervalMonths': intervalMonths,
    'nextDueKilometer': nextDueKilometer,
    'nextDueDate': nextDueDate == null
        ? null
        : Timestamp.fromDate(nextDueDate!),
    'reminderEnabled': reminderEnabled,
  };

  factory MaintenanceItem.fromMap(Map<String, dynamic> data) => MaintenanceItem(
    id: data['id'] as String? ?? data['type'] as String? ?? '',
    type: data['type'] as String? ?? 'OTHER',
    title: data['title'] as String? ?? 'Bakım kalemi',
    brand: data['brand'] as String?,
    partNumber: data['partNumber'] as String?,
    quantity: (data['quantity'] as num?)?.toDouble(),
    unit: data['unit'] as String?,
    note: data['note'] as String?,
    intervalKilometers: (data['intervalKilometers'] as num?)?.toInt(),
    intervalMonths: (data['intervalMonths'] as num?)?.toInt(),
    nextDueKilometer: (data['nextDueKilometer'] as num?)?.toInt(),
    nextDueDate: (data['nextDueDate'] as Timestamp?)?.toDate(),
    reminderEnabled: data['reminderEnabled'] as bool? ?? true,
  );

  static List<MaintenanceItem> fromLegacy(
    List<String> values,
    int? legacyKm,
    DateTime? legacyDate,
  ) => values
      .map(
        (type) => MaintenanceItem(
          id: type.toLowerCase(),
          type: type,
          title: labels[type] ?? type,
          nextDueKilometer: legacyKm,
          nextDueDate: legacyDate,
          reminderEnabled: legacyKm != null || legacyDate != null,
        ),
      )
      .toList();

  static const labels = <String, String>{
    'ENGINE_OIL': 'Motor yağı',
    'OIL_FILTER': 'Yağ filtresi',
    'AIR_FILTER': 'Hava filtresi',
    'CABIN_FILTER': 'Polen filtresi',
    'FUEL_FILTER': 'Yakıt filtresi',
    'ANTIFREEZE': 'Antifriz',
    'BRAKE_FLUID': 'Fren hidroliği',
    'TRANSMISSION_OIL': 'Şanzıman yağı',
    'SPARK_PLUG': 'Buji',
    'TIMING_BELT': 'Triger seti',
    'TIMING_CHAIN': 'Triger zinciri',
    'WATER_PUMP': 'Devirdaim pompası',
    'V_BELT': 'V kayışı',
    'BRAKE_PAD': 'Fren balatası',
    'BRAKE_DISC': 'Fren diski',
    'BATTERY': 'Akü',
    'TIRE': 'Lastik',
    'OTHER': 'Diğer',
  };
}
