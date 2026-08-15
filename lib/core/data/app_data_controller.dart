import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/expense.dart';
import '../../models/reminder.dart';
import '../../models/vehicle.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/reminder_repository.dart';
import '../../repositories/vehicle_repository.dart';

/// Kullanıcının araç/gider/hatırlatma verisine **tek bir yerden**, tek bir
/// Firestore aboneliği üzerinden erişim sağlayan paylaşılan controller.
///
/// NEDEN: Analiz raporunda tespit edildiği üzere `home_screen.dart`,
/// `reports_screen.dart` ve `vehicles_screen.dart` şu anda aynı
/// `vehicles`/`expenses`/`reminders` koleksiyonlarına **bağımsız olarak**
/// abone oluyor; her ekran kendi stream'ini açıp kendi türetilmiş
/// hesaplamalarını (toplam gider, aylık gider vb.) tekrar yazıyor.
///
/// Bu sınıf o tekrarı ortadan kaldırmak için hazırlanmıştır: `initialize()`
/// çağrıldığında her koleksiyona **bir kez** abone olur, `ChangeNotifier`
/// üzerinden dinleyicilere haber verir.
///
/// KULLANIM (opsiyonel, kademeli benimseme için tasarlandı):
/// ```dart
/// final controller = AppDataController();
/// controller.initialize(uid); // uygulama girişinde bir kez
/// // ...
/// AnimatedBuilder(
///   animation: controller,
///   builder: (context, _) => Text('${controller.vehicles.length} araç'),
/// )
/// ```
///
/// NOT: Bu sınıf kasıtlı olarak `home_screen.dart` / `reports_screen.dart` /
/// `vehicles_screen.dart` içine henüz **bağlanmamıştır**. Bu üç ekranın iç
/// mantığı (özellikle `home_screen.dart`, `DemoVehicle` türetme mantığıyla)
/// birbirine sıkı bağımlı; buraya geçiş, bir Flutter derleyicisiyle
/// (`flutter analyze` / `flutter test`) doğrulanarak yapılmalıdır. Bu
/// ortamda derleyici bulunmadığından, üç ekranı aynı anda bu controller'a
/// bağlamak yerine, önce bu sınıfın kendisi teslim edilmiş; ekran bazlı
/// geçiş ayrı ayrı ve test edilerek yapılmalıdır.
class AppDataController extends ChangeNotifier {
  AppDataController({
    VehicleRepository? vehicleRepository,
    ExpenseRepository? expenseRepository,
    ReminderRepository? reminderRepository,
  }) : _vehicleRepository = vehicleRepository ?? VehicleRepository(),
       _expenseRepository = expenseRepository ?? ExpenseRepository(),
       _reminderRepository = reminderRepository ?? ReminderRepository();

  final VehicleRepository _vehicleRepository;
  final ExpenseRepository _expenseRepository;
  final ReminderRepository _reminderRepository;

  StreamSubscription<List<Vehicle>>? _vehicleSubscription;
  StreamSubscription<List<Expense>>? _expenseSubscription;
  StreamSubscription<List<Reminder>>? _reminderSubscription;

  List<Vehicle> _vehicles = const <Vehicle>[];
  List<Expense> _expenses = const <Expense>[];
  List<Reminder> _reminders = const <Reminder>[];
  bool _loading = true;
  String? _uid;

  List<Vehicle> get vehicles => _vehicles;
  List<Expense> get expenses => _expenses;
  List<Reminder> get reminders => _reminders;
  bool get loading => _loading;

  /// Bir kullanıcı için tek seferlik abonelik başlatır. Aynı kullanıcı için
  /// tekrar çağrılırsa hiçbir şey yapmaz (idempotent); farklı bir kullanıcı
  /// için çağrılırsa önceki abonelikler kapatılıp yeniden açılır.
  void initialize(String uid) {
    if (_uid == uid && _vehicleSubscription != null) return;
    _disposeSubscriptions();
    _uid = uid;
    _loading = true;

    _vehicleSubscription = _vehicleRepository.watchVehicles(uid).listen((
      items,
    ) {
      _vehicles = items;
      _loading = false;
      notifyListeners();
    });
    _expenseSubscription = _expenseRepository.watchForUser(uid).listen((
      items,
    ) {
      _expenses = items;
      notifyListeners();
    });
    _reminderSubscription = _reminderRepository.watchForUser(uid).listen((
      items,
    ) {
      _reminders = items;
      notifyListeners();
    });
  }

  /// Belirli bir araca ait giderleri döndürür (türetilmiş, salt-okunur).
  List<Expense> expensesForVehicle(String vehicleId) =>
      _expenses.where((e) => e.vehicleId == vehicleId).toList();

  /// Belirli bir araca ait tamamlanmamış hatırlatmaları döndürür.
  List<Reminder> remindersForVehicle(String vehicleId) => _reminders
      .where((r) => r.vehicleId == vehicleId && !r.completed)
      .toList();

  void _disposeSubscriptions() {
    _vehicleSubscription?.cancel();
    _expenseSubscription?.cancel();
    _reminderSubscription?.cancel();
    _vehicleSubscription = null;
    _expenseSubscription = null;
    _reminderSubscription = null;
  }

  @override
  void dispose() {
    _disposeSubscriptions();
    super.dispose();
  }
}
