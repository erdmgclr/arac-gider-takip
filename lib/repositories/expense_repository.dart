import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense.dart';

class ExpenseRepository {
  ExpenseRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<String> add(Expense expense) async {
    final document = await _db
        .collection('expenses')
        .add(expense.toFirestore());

    // Yeni bir kayıt eklemek, aracın azami km'sini yalnızca artırabilir,
    // asla düşüremez. Bu yüzden tüm giderleri yeniden taramak yerine tek
    // bir transaction ile "daha yüksekse güncelle" yeterlidir.
    await _bumpCurrentKmIfHigher(
      vehicleId: expense.vehicleId,
      kilometer: expense.kilometer,
    );
    return document.id;
  }

  Future<void> update(Expense expense) async {
    if (expense.id.trim().isEmpty) {
      throw ArgumentError('Güncellenecek kayıt kimliği boş olamaz.');
    }

    final data = expense.toFirestore()..remove('createdAt');
    await _db.collection('expenses').doc(expense.id).update(data);

    // Güncellenen km değeri mevcut azami km'ye eşit ya da ondan büyükse,
    // bu kayıt (eski değeri ne olursa olsun) yeni azami olur; tek
    // transaction yeterlidir. Küçükse, bu kaydın önceden azami km'yi
    // belirleyen kayıt olma ihtimaline karşı güvenli tarafta kalıp tam
    // yeniden hesaplama yapılır.
    final vehicleReference = _db.collection('vehicles').doc(expense.vehicleId);
    final vehicleSnapshot = await vehicleReference.get();
    final currentKm = (vehicleSnapshot.data()?['currentKm'] as num?)?.toInt();
    final newKm = expense.kilometer;
    if (newKm != null && (currentKm == null || newKm >= currentKm)) {
      await _bumpCurrentKmIfHigher(
        vehicleId: expense.vehicleId,
        kilometer: newKm,
      );
    } else {
      await _recalculateVehicleCurrentKm(
        userId: expense.userId,
        vehicleId: expense.vehicleId,
      );
    }
  }

  Future<void> updateFields(
    String expenseId,
    Map<String, dynamic> fields,
  ) async {
    if (expenseId.trim().isEmpty) {
      throw ArgumentError('Güncellenecek kayıt kimliği boş olamaz.');
    }
    await _db.collection('expenses').doc(expenseId).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String expenseId) async {
    if (expenseId.trim().isEmpty) {
      return;
    }

    final reference = _db.collection('expenses').doc(expenseId);
    final snapshot = await reference.get();
    final data = snapshot.data();
    await reference.delete();

    final linkedReminders = await _db
        .collection('reminders')
        .where('sourceExpenseId', isEqualTo: expenseId)
        .get();
    if (linkedReminders.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final document in linkedReminders.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }

    final userId = data?['userId'] as String?;
    final vehicleId = data?['vehicleId'] as String?;
    if (userId == null || vehicleId == null) {
      return;
    }

    // Silinen kaydın km'si, aracın mevcut azami km'sinden kesin olarak
    // küçükse, bu kayıt zaten azami değeri belirleyen kayıt olamaz —
    // dolayısıyla yeniden hesaplamaya gerek yoktur. Eşitse veya km
    // bilgisi yoksa (belirsizlik durumunda güvenli tarafta kalınır),
    // tam yeniden hesaplama yapılır.
    final deletedKm = (data?['km'] as num?)?.toInt();
    final vehicleReference = _db.collection('vehicles').doc(vehicleId);
    final vehicleSnapshot = await vehicleReference.get();
    final currentKm = (vehicleSnapshot.data()?['currentKm'] as num?)?.toInt();
    final canSkip =
        deletedKm != null && currentKm != null && deletedKm < currentKm;
    if (!canSkip) {
      await _recalculateVehicleCurrentKm(userId: userId, vehicleId: vehicleId);
    }
  }

  Stream<List<Expense>> watchForUser(String userId) {
    return _db
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final result = snapshot.docs.map(Expense.fromDocument).toList();
          result.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
          return result;
        });
  }

  Stream<List<Expense>> watchForVehicle(String userId, String vehicleId) {
    return _db
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('vehicleId', isEqualTo: vehicleId)
        .snapshots()
        .map((snapshot) {
          final result = snapshot.docs.map(Expense.fromDocument).toList();
          result.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
          return result;
        });
  }

  /// Aracın azami km'sini yalnızca verilen değer daha yüksekse, tek bir
  /// transaction ile günceller. `VehicleRepository.updateCurrentKmIfHigher`
  /// ile aynı deseni kullanır; burada ayrıca tutulmasının sebebi bu
  /// sınıfın kendi Firestore erişimini (`_db`) kullanmasıdır.
  Future<void> _bumpCurrentKmIfHigher({
    required String vehicleId,
    required int? kilometer,
  }) async {
    if (kilometer == null) return;
    final reference = _db.collection('vehicles').doc(vehicleId);
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

  Future<void> recalculateVehicleCurrentKm({
    required String userId,
    required String vehicleId,
  }) {
    return _recalculateVehicleCurrentKm(userId: userId, vehicleId: vehicleId);
  }

  Future<void> _recalculateVehicleCurrentKm({
    required String userId,
    required String vehicleId,
  }) async {
    final vehicleReference = _db.collection('vehicles').doc(vehicleId);
    final vehicleSnapshot = await vehicleReference.get();
    if (!vehicleSnapshot.exists) {
      return;
    }

    final startKm = (vehicleSnapshot.data()?['startKm'] as num?)?.toInt() ?? 0;
    final expenseSnapshot = await _db
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('vehicleId', isEqualTo: vehicleId)
        .get();

    var highestKm = startKm;
    for (final document in expenseSnapshot.docs) {
      final kilometer = (document.data()['km'] as num?)?.toInt();
      if (kilometer != null && kilometer > highestKm) {
        highestKm = kilometer;
      }
    }

    await vehicleReference.update({
      'currentKm': highestKm,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
