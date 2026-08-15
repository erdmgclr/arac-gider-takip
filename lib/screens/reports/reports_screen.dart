import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/expense.dart';
import '../../models/vehicle.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/vehicle_repository.dart';
import '../../widgets/app_date_time_picker.dart';

enum ReportFilter { all, fuel, maintenance, fixed }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const String _allVehicles = '__ALL_VEHICLES__';
  final ExpenseRepository _expenseRepository = ExpenseRepository();
  final VehicleRepository _vehicleRepository = VehicleRepository();
  StreamSubscription<List<Expense>>? _expenseSubscription;
  StreamSubscription<List<Vehicle>>? _vehicleSubscription;
  List<Expense> _allExpenses = <Expense>[];
  List<Vehicle> _vehicles = <Vehicle>[];
  String _selectedVehicleId = _allVehicles;
  ReportFilter _filter = ReportFilter.all;
  String? _fuelFilter;
  bool _loadingExpenses = true;
  bool _loadingVehicles = true;
  late DateTimeRange _range;

  bool get _loading => _loadingExpenses || _loadingVehicles;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, 1, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _loadingExpenses = false;
      _loadingVehicles = false;
      return;
    }
    _expenseSubscription = _expenseRepository.watchForUser(uid).listen((items) {
      if (!mounted) return;
      setState(() {
        _allExpenses = items;
        _loadingExpenses = false;
      });
    });
    _vehicleSubscription = _vehicleRepository.watchVehicles(uid).listen((
      items,
    ) {
      if (!mounted) return;
      setState(() {
        _vehicles = items;
        _loadingVehicles = false;
        if (_selectedVehicleId != _allVehicles &&
            !_vehicles.any((vehicle) => vehicle.id == _selectedVehicleId)) {
          _selectedVehicleId = _allVehicles;
        }
      });
    });
  }

  @override
  void dispose() {
    _expenseSubscription?.cancel();
    _vehicleSubscription?.cancel();
    super.dispose();
  }

  List<Expense> get _baseRows => _allExpenses.where((expense) {
    return !expense.expenseDate.isBefore(_range.start) &&
        !expense.expenseDate.isAfter(_range.end) &&
        (_selectedVehicleId == _allVehicles ||
            expense.vehicleId == _selectedVehicleId);
  }).toList();

  List<Expense> get _visibleRows => _baseRows.where((expense) {
    switch (_filter) {
      case ReportFilter.all:
        return true;
      case ReportFilter.fuel:
        if (expense.type != ExpenseType.fuel &&
            expense.type != ExpenseType.charge) {
          return false;
        }
        if (_fuelFilter == null) return true;
        if (_fuelFilter == 'CHARGE') return expense.type == ExpenseType.charge;
        return expense.type == ExpenseType.fuel &&
            expense.subType == _fuelFilter;
      case ReportFilter.maintenance:
        return expense.type == ExpenseType.maintenance ||
            expense.type == ExpenseType.tire;
      case ReportFilter.fixed:
        return expense.type == ExpenseType.tax ||
            expense.type == ExpenseType.insurance ||
            expense.type == ExpenseType.inspection;
    }
  }).toList();

  Vehicle? get _selectedVehicle {
    if (_selectedVehicleId == _allVehicles) return null;
    for (final vehicle in _vehicles) {
      if (vehicle.id == _selectedVehicleId) return vehicle;
    }
    return null;
  }

  List<String> get _availableFuelFilters {
    final vehicle = _selectedVehicle;
    if (vehicle == null) {
      final values = _baseRows
          .where((e) => e.type == ExpenseType.fuel)
          .map((e) => e.subType)
          .whereType<String>()
          .toSet()
          .toList();
      if (_baseRows.any((e) => e.type == ExpenseType.charge)) {
        values.add('CHARGE');
      }
      return values;
    }
    switch (vehicle.fuelType) {
      case 'PETROL':
        return const ['BENZIN'];
      case 'DIESEL':
        return const ['DIZEL'];
      case 'LPG':
        return const ['LPG'];
      case 'PETROL_LPG':
        return const ['BENZIN', 'LPG'];
      case 'ELECTRIC':
        return const ['CHARGE'];
      case 'HYBRID':
        return vehicle.hybridType == 'Plug-in Hibrit'
            ? const ['BENZIN', 'CHARGE']
            : const ['BENZIN'];
      default:
        return const [];
    }
  }

  String _fuelFilterLabel(String value) => switch (value) {
    'BENZIN' => 'Benzin',
    'LPG' => 'LPG',
    'DIZEL' => 'Dizel',
    'CHARGE' => 'Şarj',
    _ => value,
  };

  Future<void> _pickRange() async {
    final start = await AppDateTimePicker.show(
      context,
      title: 'Başlangıç Tarihi',
      mode: AppPickerMode.date,
      initialValue: _range.start,
      minimumDate: DateTime(2000),
      maximumDate: DateTime(2100),
    );
    if (!mounted || start == null) return;
    final end = await AppDateTimePicker.show(
      context,
      title: 'Bitiş Tarihi',
      mode: AppPickerMode.date,
      initialValue: _range.end,
      minimumDate: start,
      maximumDate: DateTime(2100),
    );
    if (!mounted || end == null) return;
    setState(() {
      _range = DateTimeRange(
        start: DateTime(start.year, start.month, start.day),
        end: DateTime(end.year, end.month, end.day, 23, 59, 59),
      );
    });
  }

  double _sum(Iterable<Expense> rows) =>
      rows.fold<double>(0, (sum, expense) => sum + expense.amount);

  void _selectFilter(ReportFilter value) {
    setState(() {
      _filter = value;
      if (value != ReportFilter.fuel) _fuelFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final base = _baseRows;
    final rows = _visibleRows;
    final total = _sum(base);
    final fuel = _sum(
      base.where(
        (e) => e.type == ExpenseType.fuel || e.type == ExpenseType.charge,
      ),
    );
    final maintenance = _sum(
      base.where(
        (e) => e.type == ExpenseType.maintenance || e.type == ExpenseType.tire,
      ),
    );
    final fixed = _sum(
      base.where(
        (e) =>
            e.type == ExpenseType.tax ||
            e.type == ExpenseType.insurance ||
            e.type == ExpenseType.inspection,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Raporlar')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedVehicleId,
                    decoration: const InputDecoration(
                      labelText: 'Araç',
                      prefixIcon: Icon(Icons.directions_car_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: _allVehicles,
                        child: Text('Tüm Araçlar'),
                      ),
                      ..._vehicles.map(
                        (vehicle) => DropdownMenuItem(
                          value: vehicle.id,
                          child: Text(
                            vehicle.plate?.trim().isNotEmpty == true
                                ? '${vehicle.displayName} • ${vehicle.plate}'
                                : vehicle.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedVehicleId = value ?? _allVehicles;
                        _fuelFilter = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _pickRange,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tarih Aralığı',
                        prefixIcon: Icon(Icons.date_range_rounded),
                        suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                      child: Text(
                        '${_date(_range.start)} - ${_date(_range.end)}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.35,
                    children: [
                      _ReportCard(
                        title: 'Toplam',
                        value: _money(total),
                        icon: Icons.account_balance_wallet_rounded,
                        color: Colors.purple,
                        selected: _filter == ReportFilter.all,
                        onTap: () => _selectFilter(ReportFilter.all),
                      ),
                      _ReportCard(
                        title: 'Yakıt',
                        value: _money(fuel),
                        icon: Icons.local_gas_station_rounded,
                        color: Colors.blue,
                        selected: _filter == ReportFilter.fuel,
                        onTap: () => _selectFilter(ReportFilter.fuel),
                      ),
                      _ReportCard(
                        title: 'Bakım',
                        value: _money(maintenance),
                        icon: Icons.build_rounded,
                        color: Colors.orange,
                        selected: _filter == ReportFilter.maintenance,
                        onTap: () => _selectFilter(ReportFilter.maintenance),
                      ),
                      _ReportCard(
                        title: 'Sabit',
                        value: _money(fixed),
                        icon: Icons.shield_rounded,
                        color: Colors.teal,
                        selected: _filter == ReportFilter.fixed,
                        onTap: () => _selectFilter(ReportFilter.fixed),
                      ),
                    ],
                  ),
                  if (_filter == ReportFilter.fuel) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _FuelChip(
                          label: 'Tümü',
                          selected: _fuelFilter == null,
                          onTap: () => setState(() => _fuelFilter = null),
                        ),
                        ..._availableFuelFilters.map(
                          (value) => _FuelChip(
                            label: _fuelFilterLabel(value),
                            selected: _fuelFilter == value,
                            onTap: () => setState(() => _fuelFilter = value),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Dönem Kayıtları',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text('${rows.length} kayıt'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (rows.isEmpty)
                    const _EmptyCard()
                  else
                    _PeriodList(rows: rows, money: _money, label: _label),
                ],
              ),
            ),
    );
  }

  String _date(DateTime value) => Formatters.date(value);

  String _money(double value) => Formatters.currencyRounded(value);

  String _label(ExpenseType type) => switch (type) {
    ExpenseType.fuel => 'Yakıt',
    ExpenseType.charge => 'Şarj',
    ExpenseType.maintenance => 'Bakım / Onarım',
    ExpenseType.tax => 'Vergi',
    ExpenseType.insurance => 'Sigorta / Kasko',
    ExpenseType.inspection => 'Muayene',
    ExpenseType.toll => 'HGS / Otoyol',
    ExpenseType.parking => 'Otopark',
    ExpenseType.fine => 'Trafik Cezası',
    ExpenseType.tire => 'Lastik',
    ExpenseType.other => 'Diğer',
  };
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? color.withValues(alpha: 0.12)
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Theme.of(context).dividerColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FuelChip extends StatelessWidget {
  const _FuelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    visualDensity: VisualDensity.compact,
  );
}

class _PeriodList extends StatelessWidget {
  const _PeriodList({
    required this.rows,
    required this.money,
    required this.label,
  });
  final List<Expense> rows;
  final String Function(double) money;
  final String Function(ExpenseType) label;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < rows.length && index < 50; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 54),
            _PeriodRow(expense: rows[index], money: money, label: label),
          ],
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.expense,
    required this.money,
    required this.label,
  });
  final Expense expense;
  final String Function(double) money;
  final String Function(ExpenseType) label;

  @override
  Widget build(BuildContext context) {
    final title = expense.type == ExpenseType.fuel
        ? (expense.subType ?? 'Yakıt')
        : (expense.note?.trim().isNotEmpty == true
              ? expense.note!
              : label(expense.type));
    final date =
        '${expense.expenseDate.day.toString().padLeft(2, '0')}.'
        '${expense.expenseDate.month.toString().padLeft(2, '0')}.${expense.expenseDate.year}';
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      minLeadingWidth: 30,
      leading: Icon(
        expense.type == ExpenseType.fuel
            ? Icons.local_gas_station_rounded
            : Icons.receipt_long_rounded,
        size: 21,
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        expense.kilometer == null ? date : '$date • ${expense.kilometer} km',
        maxLines: 1,
      ),
      trailing: Text(
        money(expense.amount),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text('Seçilen araç, dönem ve kategoride kayıt bulunamadı.'),
    ),
  );
}
