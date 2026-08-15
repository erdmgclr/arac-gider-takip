import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../settings/settings_screen.dart';
import '../reports/reports_screen.dart';
import '../vehicles/vehicles_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../expenses/expense_history_screen.dart';
import '../expenses/edit_expense_screen.dart';

import '../../core/theme/theme_controller.dart';
import '../../models/vehicle.dart' as vehicle_model;
import '../../models/expense.dart';
import '../../models/reminder.dart';
import '../../repositories/reminder_repository.dart';
import '../reminders/add_reminder_screen.dart';
import '../reminders/reminder_list_screen.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/vehicle_repository.dart';
import '../../services/vehicle_image_service.dart';
import '../vehicles/add_vehicle_screen.dart' show AddVehicleScreen;
import '../vehicles/edit_vehicle_screen.dart';

class DemoVehicle {
  final vehicle_model.Vehicle source;
  final String name;
  final String plate;
  final String kilometer;
  final IconData icon;
  final List<Color> colors;
  final String monthlyExpense;
  final String totalExpense;
  final String fuelCost;
  final String runningCost;
  final String consumption;
  final String? petrolConsumption;
  final String? lpgConsumption;
  final String totalCostPerKm;
  final String? localImagePath;
  final String? localStickerPath;

  const DemoVehicle({
    required this.source,
    required this.name,
    required this.plate,
    required this.kilometer,
    required this.icon,
    required this.colors,
    required this.monthlyExpense,
    required this.totalExpense,
    required this.fuelCost,
    required this.runningCost,
    required this.consumption,
    this.petrolConsumption,
    this.lpgConsumption,
    required this.totalCostPerKm,
    this.localImagePath,
    this.localStickerPath,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VehicleImageService _imageService = VehicleImageService();
  final PageController _pageController = PageController(viewportFraction: 0.93);
  final VehicleRepository _vehicleRepository = VehicleRepository();
  final ExpenseRepository _expenseRepository = ExpenseRepository();
  final ReminderRepository _reminderRepository = ReminderRepository();
  StreamSubscription<List<vehicle_model.Vehicle>>? _vehicleSubscription;
  StreamSubscription<List<Expense>>? _expenseSubscription;
  StreamSubscription<List<Reminder>>? _reminderSubscription;
  List<DemoVehicle> _vehicles = <DemoVehicle>[];
  List<vehicle_model.Vehicle> _vehicleSources = <vehicle_model.Vehicle>[];
  List<Expense> _expenses = <Expense>[];
  List<Reminder> _reminders = <Reminder>[];
  bool _loading = true;
  int _selectedPage = 0;

  bool get _isAddPage => _selectedPage == _vehicles.length;

  DemoVehicle get _selectedVehicle => _vehicles[_selectedPage];

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _loading = false;
      return;
    }
    _vehicleSubscription = _vehicleRepository.watchVehicles(uid).listen((
      items,
    ) {
      if (!mounted) return;
      _restoreVehicleImages(items);
      setState(() {
        _vehicleSources = items;
        _rebuildVehicles();
        _loading = false;
        if (_selectedPage > _vehicles.length) _selectedPage = _vehicles.length;
      });
    });
    _expenseSubscription = _expenseRepository.watchForUser(uid).listen((items) {
      if (!mounted) return;
      setState(() {
        _expenses = items;
        _rebuildVehicles();
      });
    });
    _reminderSubscription = _reminderRepository.watchForUser(uid).listen((
      items,
    ) {
      if (!mounted) return;
      setState(() => _reminders = items);
    });
  }

  void _rebuildVehicles() {
    const colors = <List<Color>>[
      [Color(0xFF0D47A1), Color(0xFF1976D2)],
      [Color(0xFF6A1B4D), Color(0xFFC2185B)],
      [Color(0xFF00695C), Color(0xFF00897B)],
    ];
    final now = DateTime.now();
    _vehicles = _vehicleSources.asMap().entries.map((entry) {
      final vehicle = entry.value;
      final expenses = _expenses
          .where((e) => e.vehicleId == vehicle.id)
          .toList();
      final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
      final monthly = expenses
          .where(
            (e) =>
                e.expenseDate.year == now.year &&
                e.expenseDate.month == now.month,
          )
          .fold<double>(0, (sum, e) => sum + e.amount);
      final fuelExpenses = expenses
          .where((e) => e.type == ExpenseType.fuel)
          .toList();
      final fuelTotal = fuelExpenses.fold<double>(
        0,
        (sum, e) => sum + e.amount,
      );
      final usedKm = _usedKilometers(vehicle);
      final runningCost = usedKm == null ? null : total / usedKm;
      final ownershipTotal = vehicle.purchasePrice == null
          ? null
          : vehicle.purchasePrice! + total;
      final totalCostPerKm = usedKm == null || ownershipTotal == null
          ? null
          : ownershipTotal / usedKm;
      final petrolConsumption = _fullTankConsumption(fuelExpenses, 'BENZIN');
      final lpgConsumption = _fullTankConsumption(fuelExpenses, 'LPG');
      final dieselConsumption = _fullTankConsumption(fuelExpenses, 'DIZEL');
      final consumptionText = vehicle.fuelType == 'PETROL_LPG'
          ? _dualFuelConsumptionText(petrolConsumption, lpgConsumption)
          : _singleFuelConsumptionText(
              vehicle.fuelType == 'LPG'
                  ? lpgConsumption
                  : vehicle.fuelType == 'DIESEL'
                  ? dieselConsumption
                  : petrolConsumption,
            );
      return DemoVehicle(
        source: vehicle,
        name: vehicle.displayName,
        plate: vehicle.plate?.toUpperCase() ?? '',
        kilometer: vehicle.currentKm == null
            ? 'KM girilmedi'
            : '${vehicle.currentKm} km',
        icon: vehicle.category == 'MOTORCYCLE'
            ? Icons.two_wheeler_rounded
            : Icons.directions_car_rounded,
        colors: colors[entry.key % colors.length],
        monthlyExpense: _money(monthly),
        totalExpense: _money(total),
        fuelCost: _money(fuelTotal),
        runningCost: runningCost == null
            ? 'Hesaplanamadı'
            : '₺${runningCost.round()} / km',
        consumption: consumptionText,
        petrolConsumption: vehicle.fuelType == 'PETROL_LPG'
            ? (petrolConsumption == null
                  ? 'Veri bekleniyor'
                  : '${petrolConsumption.toStringAsFixed(1)} L/100 km')
            : null,
        lpgConsumption: vehicle.fuelType == 'PETROL_LPG'
            ? (lpgConsumption == null
                  ? 'Veri bekleniyor'
                  : '${lpgConsumption.toStringAsFixed(1)} L/100 km')
            : null,
        totalCostPerKm: totalCostPerKm == null
            ? (vehicle.purchasePrice == null
                  ? 'Alış fiyatı gerekli'
                  : 'Hesaplanamadı')
            : '₺${totalCostPerKm.round()} / km',
        localImagePath: vehicle.localImagePath,
        localStickerPath: vehicle.localStickerPath,
      );
    }).toList();
  }

  double? _fullTankConsumption(List<Expense> fuelExpenses, String fuelSubType) {
    final records =
        fuelExpenses
            .where(
              (expense) =>
                  expense.subType == fuelSubType &&
                  expense.quantity != null &&
                  expense.quantity! > 0 &&
                  expense.kilometer != null,
            )
            .toList()
          ..sort((a, b) => a.expenseDate.compareTo(b.expenseDate));

    int? previousFullKm;
    double pendingLitres = 0;
    double totalLitres = 0;
    int totalDistance = 0;

    for (final record in records) {
      if (previousFullKm == null) {
        if (record.isFullTank == true) {
          previousFullKm = record.kilometer!;
          pendingLitres = 0;
        }
        continue;
      }

      pendingLitres += record.quantity!;
      if (record.isFullTank == true && record.kilometer! > previousFullKm) {
        totalDistance += record.kilometer! - previousFullKm;
        totalLitres += pendingLitres;
        previousFullKm = record.kilometer!;
        pendingLitres = 0;
      }
    }

    if (totalDistance <= 0 || totalLitres <= 0) return null;
    return totalLitres / totalDistance * 100;
  }

  String _singleFuelConsumptionText(double? value) {
    return value == null
        ? '2 tam dolum gerekli'
        : '${value.toStringAsFixed(1)} L/100 km';
  }

  String _dualFuelConsumptionText(double? petrol, double? lpg) {
    if (petrol == null && lpg == null) return '2 tam dolum gerekli';
    final parts = <String>[];
    if (lpg != null) parts.add('LPG ${lpg.toStringAsFixed(1)}');
    if (petrol != null) parts.add('Benzin ${petrol.toStringAsFixed(1)}');
    return '${parts.join(' • ')} L/100 km';
  }

  double? _usedKilometers(vehicle_model.Vehicle vehicle) {
    final startKm = vehicle.startKm;
    final currentKm = vehicle.currentKm;
    if (startKm == null || currentKm == null) return null;
    final usedKm = currentKm - startKm;
    return usedKm > 0 ? usedKm.toDouble() : null;
  }

  String _money(double value) {
    final rounded = value.round().toString();
    final grouped = rounded.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return '₺$grouped';
  }

  Future<void> _openAddVehicle() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (context) => const AddVehicleScreen()),
    );
  }

  Future<void> _editVehicle(DemoVehicle vehicle) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditVehicleScreen(vehicle: vehicle.source),
      ),
    );
  }

  Future<void> _restoreVehicleImages(List<vehicle_model.Vehicle> items) async {
    for (final vehicle in items) {
      try {
        final restored = await _imageService.restoreMissingImages(vehicle);
        if (restored.hasChanges) {
          await _vehicleRepository.updateLocalImagePaths(
            vehicleId: vehicle.id,
            localImagePath: restored.originalPath,
            localStickerPath: restored.stickerPath,
          );
        }
      } catch (_) {
        // Kart varsayılan ikonla açılır; sonraki akışta yeniden denenir.
      }
    }
  }

  @override
  void dispose() {
    _vehicleSubscription?.cancel();
    _expenseSubscription?.cancel();
    _reminderSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openExpense(ExpenseType type) async {
    if (_vehicles.isEmpty || _isAddPage) {
      _showMessage('Önce işlem yapılacak aracı seçin.');
      return;
    }
    final vehicle = _selectedVehicle;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddExpenseScreen(
          vehicleId: vehicle.source.id,
          vehicleName: vehicle.name,
          initialType: type,
          initialKilometer: vehicle.source.currentKm,
        ),
      ),
    );
  }

  List<Expense> get _selectedVehicleExpenses => _expenses
      .where((e) => e.vehicleId == _selectedVehicle.source.id)
      .toList();

  bool get _hasUpcomingActions {
    final vehicle = _selectedVehicle.source;
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    bool dateVisible(DateTime? date) {
      if (date == null) return false;
      return DateTime(
            date.year,
            date.month,
            date.day,
          ).difference(base).inDays <=
          90;
    }

    if (dateVisible(vehicle.trafficInsuranceEndDate) ||
        dateVisible(vehicle.cascoEndDate) ||
        dateVisible(vehicle.inspectionEndDate)) {
      return true;
    }
    return _reminders.where((r) => r.vehicleId == vehicle.id).any((reminder) {
      if (dateVisible(reminder.dueDate)) return true;
      final km = reminder.dueKilometer;
      return km != null &&
          vehicle.currentKm != null &&
          km - vehicle.currentKm! <= 3000;
    });
  }

  Future<void> _openAllExpenses() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ExpenseHistoryScreen(
          vehicleName: _selectedVehicle.name,
          expenses: _selectedVehicleExpenses,
        ),
      ),
    );
  }

  Future<void> _openAllReminders() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReminderListScreen(
          vehicleId: _selectedVehicle.source.id,
          vehicleName: _selectedVehicle.name,
        ),
      ),
    );
  }

  Future<void> _openExpenseActions(Expense expense) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Düzenle'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Sil',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => EditExpenseScreen(expense: expense),
        ),
      );
      return;
    }
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Kayıt silinsin mi?'),
            content: const Text(
              'Silinen kayıt toplam gider, rapor ve tüketim hesaplarından çıkarılacaktır.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await _expenseRepository.delete(expense.id);
  }

  void _showQuickAddMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yeni Kayıt',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.local_gas_station_rounded,
                        label: 'Yakıt',
                        color: const Color(0xFF1976D2),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _openExpense(ExpenseType.fuel);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.build_rounded,
                        label: 'Bakım',
                        color: const Color(0xFFEF6C00),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _openExpense(ExpenseType.maintenance);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.receipt_long_rounded,
                        label: 'Gider',
                        color: const Color(0xFF7B1FA2),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _openExpense(ExpenseType.other);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.notifications_active_rounded,
                        label: 'Hatırlatma',
                        color: const Color(0xFFC62828),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          if (_vehicles.isEmpty || _isAddPage) {
                            _showMessage('Önce araç seçin.');
                          } else {
                            final vehicle = _selectedVehicle;
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AddReminderScreen(
                                  vehicleId: vehicle.source.id,
                                  vehicleName: vehicle.name,
                                  currentKilometer: vehicle.source.currentKm,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _vehicles.length + 1;

    return Scaffold(
      extendBody: false,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            if (_loading)
              const SizedBox(
                height: 278,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SizedBox(
                height: 278,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pageCount,
                  onPageChanged: (index) {
                    setState(() {
                      _selectedPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    if (index == _vehicles.length) {
                      return _buildAddVehicleCard();
                    }

                    return _buildVehicleCard(
                      _vehicles[index],
                      _selectedPage == index,
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            _buildPageIndicator(pageCount),
            if (!_loading && !_isAddPage && _vehicles.isNotEmpty) ...[
              const SizedBox(height: 22),
              _buildMetrics(),
              if (_hasUpcomingActions) ...[
                const SizedBox(height: 24),
                _buildSectionTitle(
                  'Yaklaşan İşlemler',
                  'Tümünü Gör',
                  _openAllReminders,
                ),
                const SizedBox(height: 10),
                _buildUpcomingActions(),
              ],
              const SizedBox(height: 24),
              _buildSectionTitle(
                'Son Kayıtlar',
                'Tümünü Gör',
                _openAllExpenses,
              ),
              const SizedBox(height: 10),
              _buildRecentRecords(),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickAddMenu,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.displayName == null
                    ? 'Merhaba'
                    : 'Merhaba, ${user!.displayName!.split(' ').first}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.58),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Araç Gider Takip',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: isDark ? 'Aydınlık temaya geç' : 'AMOLED temaya geç',
          onPressed: () {
            themeController.toggleTheme(context);
          },
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard(DemoVehicle vehicle, bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      margin: EdgeInsets.only(
        left: 3,
        right: 7,
        top: selected ? 0 : 7,
        bottom: selected ? 0 : 7,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: vehicle.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: Theme.of(context).brightness == Brightness.light && selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white.withValues(alpha: 0.10))
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vehicle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      vehicle.plate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (vehicle.localStickerPath != null &&
                        File(vehicle.localStickerPath!).existsSync())
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Image.file(
                          File(vehicle.localStickerPath!),
                          width: double.infinity,
                          height: 158,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          filterQuality: FilterQuality.high,
                        ),
                      )
                    else if (vehicle.localImagePath != null &&
                        File(vehicle.localImagePath!).existsSync())
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Image.file(
                          File(vehicle.localImagePath!),
                          width: double.infinity,
                          height: 158,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                        ),
                      )
                    else
                      Icon(
                        vehicle.icon,
                        size: vehicle.icon == Icons.two_wheeler_rounded
                            ? 126
                            : 150,
                        color: Colors.white,
                      ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, 7),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.speed_rounded,
                        color: Colors.white70,
                        size: 11,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        vehicle.kilometer,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _VehicleExpenseValue(
                      label: 'BU AYKİ GİDER',
                      value: vehicle.monthlyExpense,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 34,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  Expanded(
                    child: _VehicleExpenseValue(
                      label: 'TOPLAM GİDER',
                      value: vehicle.totalExpense,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddVehicleCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(3, 7, 7, 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _openAddVehicle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.add_rounded,
                size: 39,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 17),
            Text(
              'Yeni Araç Ekle',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Text(
                'Giderlerini takip etmek istediğiniz araç veya motosikleti ekleyin.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final selected = index == _selectedPage;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: selected ? 23 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }

  Widget _buildMetrics() {
    final vehicle = _selectedVehicle;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Yakıt Maliyeti',
                value: vehicle.fuelCost,
                icon: Icons.local_gas_station_rounded,
                color: const Color(0xFF1976D2),
                info: 'Seçili araca ait yakıt ve şarj giderlerinin toplamıdır.',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'İşletme Maliyeti',
                value: vehicle.runningCost,
                icon: Icons.speed_rounded,
                color: const Color(0xFF00897B),
                info:
                    'Araç alış bedeli hariç kayıtlı tüm giderlerin, başlangıç kilometresinden itibaren kat edilen mesafeye bölünmesiyle hesaplanır.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Ortalama Tüketim',
                value: vehicle.consumption,
                icon: Icons.water_drop_rounded,
                color: const Color(0xFFEF6C00),
                info:
                    'Aynı yakıt türündeki iki tam dolum arasındaki yakıt toplamı kilometre farkına bölünür ve 100 ile çarpılır. Kısmi dolumlar sonraki tam doluma eklenir.',
                firstDetailLabel: vehicle.petrolConsumption == null
                    ? null
                    : 'Benzin',
                firstDetailValue: vehicle.petrolConsumption,
                secondDetailLabel: vehicle.lpgConsumption == null
                    ? null
                    : 'LPG',
                secondDetailValue: vehicle.lpgConsumption,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Sahip Olma / KM',
                value: vehicle.totalCostPerKm,
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF7B1FA2),
                info:
                    'Araç alış bedeli ile kayıtlı tüm giderlerin toplamı, başlangıç kilometresinden itibaren kat edilen mesafeye bölünür.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    String title,
    String action,
    VoidCallback onPressed,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }

  Widget _buildUpcomingActions() {
    final vehicle = _selectedVehicle.source;
    final entries = <Widget>[];

    void add(DateTime? date, String title, IconData icon, Color color) {
      if (date == null) return;
      final days = DateTime(date.year, date.month, date.day)
          .difference(
            DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            ),
          )
          .inDays;
      if (days > 90) return;
      if (entries.isNotEmpty) entries.add(const _EntryDivider());
      entries.add(
        _ListEntry(
          icon: icon,
          title: title,
          subtitle:
              '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
          color: color,
          trailingText: days < 0 ? '${-days} gün geçti' : '$days gün',
        ),
      );
    }

    add(
      vehicle.trafficInsuranceEndDate,
      'Trafik Sigortası',
      Icons.shield_outlined,
      const Color(0xFFEF6C00),
    );
    add(
      vehicle.cascoEndDate,
      'Kasko',
      Icons.verified_user_outlined,
      const Color(0xFF1976D2),
    );
    add(
      vehicle.inspectionEndDate,
      'Araç Muayenesi',
      Icons.fact_check_outlined,
      const Color(0xFFC62828),
    );

    for (final reminder in _reminders.where((r) => r.vehicleId == vehicle.id)) {
      final date = reminder.dueDate;
      final km = reminder.dueKilometer;
      final dueByKm =
          km != null &&
          vehicle.currentKm != null &&
          km - vehicle.currentKm! <= 3000;
      if (date != null) {
        add(
          date,
          reminder.title,
          Icons.build_circle_outlined,
          const Color(0xFF00897B),
        );
      } else if (dueByKm) {
        if (entries.isNotEmpty) entries.add(const _EntryDivider());
        entries.add(
          _ListEntry(
            icon: Icons.build_circle_outlined,
            title: reminder.title,
            subtitle: '$km km',
            color: const Color(0xFF00897B),
            trailingText: '${km - vehicle.currentKm!} km',
          ),
        );
      }
    }

    if (entries.isEmpty) {
      return _EmptyStateCard(
        text: 'Önümüzdeki 90 gün içinde yaklaşan işlem yok.',
        action: 'Araç düzenle',
        onTap: () => _editVehicle(_selectedVehicle),
      );
    }
    return _SectionCard(children: entries);
  }

  Widget _buildRecentRecords() {
    final records = _expenses
        .where((e) => e.vehicleId == _selectedVehicle.source.id)
        .take(4)
        .toList();
    if (records.isEmpty) {
      return const _EmptyStateCard(text: 'Henüz masraf kaydı yok.');
    }
    return _SectionCard(
      children: [
        for (var i = 0; i < records.length; i++) ...[
          if (i > 0) const _EntryDivider(),
          _ListEntry(
            onTap: () => _openExpenseActions(records[i]),
            icon: records[i].type == ExpenseType.fuel
                ? Icons.local_gas_station_rounded
                : Icons.receipt_long_rounded,
            title: records[i].type == ExpenseType.fuel
                ? (records[i].subType ?? 'Yakıt')
                : (records[i].note ?? _typeLabel(records[i].type)),
            subtitle:
                '${records[i].expenseDate.day.toString().padLeft(2, '0')}.${records[i].expenseDate.month.toString().padLeft(2, '0')}.${records[i].expenseDate.year}',
            color: records[i].type == ExpenseType.fuel
                ? const Color(0xFF1976D2)
                : const Color(0xFFEF6C00),
            trailingText: _money(records[i].amount),
          ),
        ],
      ],
    );
  }

  String _typeLabel(ExpenseType type) => switch (type) {
    ExpenseType.maintenance => 'Bakım',
    ExpenseType.tax => 'MTV',
    ExpenseType.insurance => 'Sigorta',
    _ => 'Gider',
  };

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: BottomAppBar(
        height: 68,
        padding: EdgeInsets.zero,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Row(
          children: [
            const Expanded(
              child: _BottomItem(
                icon: Icons.home_rounded,
                label: 'Ana Sayfa',
                selected: true,
              ),
            ),
            Expanded(
              child: _BottomItem(
                icon: Icons.directions_car_outlined,
                label: 'Araçlar',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VehiclesScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 64),
            Expanded(
              child: _BottomItem(
                icon: Icons.bar_chart_rounded,
                label: 'Raporlar',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
                  );
                },
              ),
            ),
            Expanded(
              child: _BottomItem(
                icon: Icons.settings_outlined,
                label: 'Ayarlar',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleExpenseValue extends StatelessWidget {
  const _VehicleExpenseValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.25,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.text, this.action, this.onTap});
  final String text;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          if (action != null)
            TextButton(onPressed: onTap, child: Text(action!)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String info;
  final String? firstDetailLabel;
  final String? firstDetailValue;
  final String? secondDetailLabel;
  final String? secondDetailValue;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.info,
    this.firstDetailLabel,
    this.firstDetailValue,
    this.secondDetailLabel,
    this.secondDetailValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 82, maxHeight: 82),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF242424) : const Color(0xFFE3E7ED),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(title),
                          content: Text(info),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Tamam'),
                            ),
                          ],
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.info_outline_rounded, size: 15),
                      ),
                    ),
                  ],
                ),
                if (firstDetailLabel != null) ...[
                  const SizedBox(height: 1),
                  _MetricDetail(
                    label: firstDetailLabel!,
                    value: firstDetailValue ?? 'Veri bekleniyor',
                  ),
                  _MetricDetail(
                    label: secondDetailLabel!,
                    value: secondDetailValue ?? 'Veri bekleniyor',
                  ),
                ] else ...[
                  const SizedBox(height: 5),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDetail extends StatelessWidget {
  const _MetricDetail({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 42,
        child: Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
        ),
      ),
      Expanded(
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF242424) : const Color(0xFFE3E7ED),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ListEntry extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String trailingText;
  final VoidCallback? onTap;

  const _ListEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.trailingText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      dense: true,
      visualDensity: const VisualDensity(vertical: -3),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        trailingText,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EntryDivider extends StatelessWidget {
  const _EntryDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 56),
      child: Divider(height: 1),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 15),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.50);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
