import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String id;
  final String userId;
  final String category;
  final String brand;
  final String model;
  final String? engine;
  final int? year;
  final String fuelType;
  final String? hybridType;
  final String? plate;
  final String? normalizedPlate;
  final int? startKm;
  final int? currentKm;
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final double? tankCapacity;
  final double? lpgTankCapacity;
  final double? batteryCapacity;
  final DateTime? mtvNextPaymentDate;
  final DateTime? trafficInsuranceEndDate;
  final DateTime? cascoEndDate;
  final DateTime? inspectionEndDate;
  final String? localImagePath;
  final String? localStickerPath;
  final String? originalImageDriveId;
  final String? stickerImageDriveId;
  final bool backgroundRemoved;
  final String status;
  final bool hasFinancing;
  final bool isCustomBrand;
  final bool isCustomModel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Vehicle({
    required this.id,
    required this.userId,
    required this.category,
    required this.brand,
    required this.model,
    this.engine,
    this.year,
    required this.fuelType,
    this.hybridType,
    this.plate,
    this.normalizedPlate,
    this.startKm,
    this.currentKm,
    this.purchasePrice,
    this.purchaseDate,
    this.tankCapacity,
    this.lpgTankCapacity,
    this.batteryCapacity,
    this.mtvNextPaymentDate,
    this.trafficInsuranceEndDate,
    this.cascoEndDate,
    this.inspectionEndDate,
    this.localImagePath,
    this.localStickerPath,
    this.originalImageDriveId,
    this.stickerImageDriveId,
    this.backgroundRemoved = false,
    this.status = 'ACTIVE',
    this.hasFinancing = false,
    this.isCustomBrand = false,
    this.isCustomModel = false,
    this.createdAt,
    this.updatedAt,
  });

  String get displayName => [
    brand,
    model,
    if (engine?.trim().isNotEmpty == true) engine!.trim(),
  ].join(' ');

  factory Vehicle.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    DateTime? date(String key) => (d[key] as Timestamp?)?.toDate();
    return Vehicle(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      category: d['category'] as String? ?? 'CAR',
      brand: d['brand'] as String? ?? '',
      model: d['model'] as String? ?? '',
      engine: d['engine'] as String?,
      year: (d['year'] as num?)?.toInt(),
      fuelType: d['fuelType'] as String? ?? 'OTHER',
      hybridType: d['hybridType'] as String?,
      plate: d['plate'] as String?,
      normalizedPlate: d['normalizedPlate'] as String?,
      startKm: (d['startKm'] as num?)?.toInt(),
      currentKm: (d['currentKm'] as num?)?.toInt(),
      purchasePrice: (d['purchasePrice'] as num?)?.toDouble(),
      purchaseDate: date('purchaseDate'),
      tankCapacity: (d['tankCapacity'] as num?)?.toDouble(),
      lpgTankCapacity: (d['lpgTankCapacity'] as num?)?.toDouble(),
      batteryCapacity: (d['batteryCapacity'] as num?)?.toDouble(),
      mtvNextPaymentDate: date('mtvNextPaymentDate'),
      trafficInsuranceEndDate: date('trafficInsuranceEndDate'),
      cascoEndDate: date('cascoEndDate'),
      inspectionEndDate: date('inspectionEndDate'),
      localImagePath: d['localImagePath'] as String?,
      localStickerPath: d['localStickerPath'] as String?,
      originalImageDriveId: d['originalImageDriveId'] as String?,
      stickerImageDriveId: d['stickerImageDriveId'] as String?,
      backgroundRemoved: d['backgroundRemoved'] as bool? ?? false,
      status: d['status'] as String? ?? 'ACTIVE',
      hasFinancing: d['hasFinancing'] as bool? ?? false,
      isCustomBrand: d['isCustomBrand'] as bool? ?? false,
      isCustomModel: d['isCustomModel'] as bool? ?? false,
      createdAt: date('createdAt'),
      updatedAt: date('updatedAt'),
    );
  }

  Map<String, dynamic> toFirestore({bool includeCreatedAt = true}) =>
      <String, dynamic>{
        'userId': userId,
        'category': category,
        'brand': brand.trim(),
        'model': model.trim(),
        'engine': _empty(engine),
        'year': year,
        'fuelType': fuelType,
        'hybridType': _empty(hybridType),
        'plate': _empty(plate),
        'normalizedPlate': _empty(normalizedPlate),
        'startKm': startKm,
        'currentKm': currentKm,
        'purchasePrice': purchasePrice,
        'purchaseDate': _timestamp(purchaseDate),
        'tankCapacity': tankCapacity,
        'lpgTankCapacity': lpgTankCapacity,
        'batteryCapacity': batteryCapacity,
        'mtvNextPaymentDate': _timestamp(mtvNextPaymentDate),
        'trafficInsuranceEndDate': _timestamp(trafficInsuranceEndDate),
        'cascoEndDate': _timestamp(cascoEndDate),
        'inspectionEndDate': _timestamp(inspectionEndDate),
        'localImagePath': _empty(localImagePath),
        'localStickerPath': _empty(localStickerPath),
        'originalImageDriveId': _empty(originalImageDriveId),
        'stickerImageDriveId': _empty(stickerImageDriveId),
        'backgroundRemoved': backgroundRemoved,
        'status': status,
        'hasFinancing': hasFinancing,
        'isCustomBrand': isCustomBrand,
        'isCustomModel': isCustomModel,
        if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static Timestamp? _timestamp(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value);
  static String? _empty(String? value) =>
      value?.trim().isEmpty == true ? null : value?.trim();
}
