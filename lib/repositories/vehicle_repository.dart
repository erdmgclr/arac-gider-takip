import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle.dart';

class DuplicatePlateException implements Exception {
  final String plate;
  const DuplicatePlateException(this.plate);
}

class VehicleRepository {
  VehicleRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _vehicles =>
      _db.collection('vehicles');

  Stream<List<Vehicle>> watchVehicles(String uid) =>
      _vehicles.where('userId', isEqualTo: uid).snapshots().map((snapshot) {
        final list = snapshot.docs
            .map(Vehicle.fromDocument)
            .where((v) => v.status != 'DELETED')
            .toList();
        list.sort(
          (a, b) => (a.createdAt ?? DateTime(1970)).compareTo(
            b.createdAt ?? DateTime(1970),
          ),
        );
        return list;
      });

  Future<String> addVehicle(Vehicle vehicle) async {
    final key = normalizePlate(vehicle.plate);
    final vehicleDoc = _vehicles.doc();
    if (key == null) {
      await vehicleDoc.set(vehicle.toFirestore());
      return vehicleDoc.id;
    }
    final plateDoc = _db
        .collection('vehicle_plate_keys')
        .doc('${vehicle.userId}_$key');
    await _db.runTransaction((tx) async {
      if ((await tx.get(plateDoc)).exists) {
        throw DuplicatePlateException(vehicle.plate!);
      }
      tx.set(plateDoc, {
        'userId': vehicle.userId,
        'vehicleId': vehicleDoc.id,
        'normalizedPlate': key,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(vehicleDoc, vehicle.toFirestore());
    });
    return vehicleDoc.id;
  }

  Future<void> updateVehicle(Vehicle original, Vehicle updated) async {
    final oldKey = normalizePlate(original.plate);
    final newKey = normalizePlate(updated.plate);
    final oldRef = oldKey == null
        ? null
        : _db
              .collection('vehicle_plate_keys')
              .doc('${original.userId}_$oldKey');
    final newRef = newKey == null
        ? null
        : _db
              .collection('vehicle_plate_keys')
              .doc('${original.userId}_$newKey');
    await _db.runTransaction((tx) async {
      if (newRef != null && newKey != oldKey && (await tx.get(newRef)).exists) {
        throw DuplicatePlateException(updated.plate!);
      }
      tx.update(
        _vehicles.doc(original.id),
        updated.toFirestore(includeCreatedAt: false),
      );
      if (oldRef != null && oldKey != newKey) tx.delete(oldRef);
      if (newRef != null && oldKey != newKey) {
        tx.set(newRef, {
          'userId': original.userId,
          'vehicleId': original.id,
          'normalizedPlate': newKey,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> updateLocalImagePaths({
    required String vehicleId,
    String? localImagePath,
    String? localStickerPath,
  }) async {
    final data = <String, dynamic>{
      'localImagePath': ?localImagePath,
      'localStickerPath': ?localStickerPath,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (data.length > 1) {
      await _vehicles.doc(vehicleId).update(data);
    }
  }

  Future<void> updateCurrentKmIfHigher({
    required String vehicleId,
    required int kilometer,
  }) async {
    final reference = _vehicles.doc(vehicleId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) return;
      final current = (snapshot.data()?['currentKm'] as num?)?.toInt();
      if (current == null || kilometer > current) {
        transaction.update(reference, {
          'currentKm': kilometer,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> deleteVehicle(Vehicle vehicle) async {
    final expenses = await _db
        .collection('expenses')
        .where('userId', isEqualTo: vehicle.userId)
        .where('vehicleId', isEqualTo: vehicle.id)
        .limit(1)
        .get();
    if (expenses.docs.isNotEmpty) {
      await _vehicles.doc(vehicle.id).update({
        'status': 'DELETED',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _vehicles.doc(vehicle.id).delete();
    }
    final key = normalizePlate(vehicle.plate);
    if (key != null) {
      await _db
          .collection('vehicle_plate_keys')
          .doc('${vehicle.userId}_$key')
          .delete();
    }
  }

  static String? normalizePlate(String? plate) {
    final value = plate?.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return value == null || value.isEmpty ? null : value;
  }
}
