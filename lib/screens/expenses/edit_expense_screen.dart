import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../models/maintenance_item.dart';
import '../../models/reminder.dart';
import '../../repositories/reminder_repository.dart';
import '../../widgets/maintenance_items_editor.dart';
import '../../repositories/expense_repository.dart';
import '../../widgets/app_date_time_picker.dart';

class EditExpenseScreen extends StatefulWidget {
  const EditExpenseScreen({super.key, required this.expense});
  final Expense expense;
  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ExpenseRepository();
  final _reminders = ReminderRepository();
  late final _amount = TextEditingController(
    text: widget.expense.amount.toStringAsFixed(2).replaceAll('.', ','),
  );
  late final _quantity = TextEditingController(
    text:
        widget.expense.quantity?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
  );
  late final _unitPrice = TextEditingController(
    text:
        widget.expense.unitPrice?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
  );
  late final _km = TextEditingController(
    text: widget.expense.kilometer?.toString() ?? '',
  );
  late final _station = TextEditingController(
    text: widget.expense.stationName ?? '',
  );
  late final _note = TextEditingController(text: widget.expense.note ?? '');
  late final _serviceName = TextEditingController(
    text: widget.expense.serviceName ?? '',
  );
  late final _laborCost = TextEditingController(
    text: widget.expense.laborCost?.toString() ?? '',
  );
  late String _maintenanceType = widget.expense.maintenanceType ?? 'PERIODIC';
  late List<MaintenanceItem> _maintenanceItems = [
    ...widget.expense.effectiveMaintenanceItems,
  ];
  late DateTime _date = widget.expense.expenseDate;
  bool _saving = false;

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
  @override
  void dispose() {
    for (final c in [
      _amount,
      _quantity,
      _unitPrice,
      _km,
      _station,
      _note,
      _serviceName,
      _laborCost,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final old = widget.expense;
    try {
      await _repo.update(
        Expense(
          id: old.id,
          userId: old.userId,
          vehicleId: old.vehicleId,
          type: old.type,
          subType: old.subType,
          isFullTank: old.isFullTank,
          nextDueDate: old.nextDueDate,
          stationName: _station.text.trim().isEmpty
              ? null
              : _station.text.trim(),
          receiptNumber: old.receiptNumber,
          documentName: old.documentName,
          documentMimeType: old.documentMimeType,
          maintenanceType: old.type == ExpenseType.maintenance
              ? _maintenanceType
              : old.maintenanceType,
          serviceName:
              old.type == ExpenseType.maintenance &&
                  _serviceName.text.trim().isNotEmpty
              ? _serviceName.text.trim()
              : null,
          laborCost: old.type == ExpenseType.maintenance
              ? _number(_laborCost.text)
              : old.laborCost,
          maintenanceItems: old.type == ExpenseType.maintenance
              ? _maintenanceItems
              : old.maintenanceItems,
          replacedItems: old.type == ExpenseType.maintenance
              ? _maintenanceItems.map((item) => item.type).toList()
              : old.replacedItems,
          nextMaintenanceDate: old.nextMaintenanceDate,
          nextMaintenanceKilometer: old.nextMaintenanceKilometer,
          amount: _number(_amount.text)!,
          quantity: _number(_quantity.text),
          unitPrice: _number(_unitPrice.text),
          kilometer: int.tryParse(_km.text.trim()),
          expenseDate: _date,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          localDocumentPath: old.localDocumentPath,
          driveDocumentId: old.driveDocumentId,
          importKey: old.importKey,
          importSource: old.importSource,
        ),
      );
      if (old.type == ExpenseType.maintenance) {
        final reminders = _maintenanceItems
            .where(
              (item) =>
                  item.reminderEnabled &&
                  (item.nextDueDate != null || item.nextDueKilometer != null),
            )
            .map(
              (item) => Reminder(
                id: '',
                userId: old.userId,
                vehicleId: old.vehicleId,
                title: item.title,
                dueDate: item.nextDueDate,
                dueKilometer: item.nextDueKilometer,
                note: 'Bakım kaydından otomatik oluşturuldu.',
                sourceExpenseId: old.id,
                maintenanceItemId: item.id,
                maintenanceItemType: item.type,
              ),
            )
            .toList();
        await _reminders.syncMaintenanceReminders(
          sourceExpenseId: old.id,
          userId: old.userId,
          vehicleId: old.vehicleId,
          reminders: reminders,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Masrafı Düzenle')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InkWell(
              onTap: () async {
                final value = await AppDateTimePicker.show(
                  context,
                  title: 'Tarih ve Saat',
                  mode: AppPickerMode.dateAndTime,
                  initialValue: _date,
                );
                if (value != null && mounted) setState(() => _date = value);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Tarih ve Saat'),
                child: Text(_date.toLocal().toString().substring(0, 16)),
              ),
            ),
            if (widget.expense.type == ExpenseType.maintenance) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _maintenanceType,
                decoration: const InputDecoration(labelText: 'Bakım Türü'),
                items: const [
                  DropdownMenuItem(
                    value: 'PERIODIC',
                    child: Text('Periyodik Bakım'),
                  ),
                  DropdownMenuItem(
                    value: 'HEAVY_MAINTENANCE',
                    child: Text('Ağır Bakım'),
                  ),
                  DropdownMenuItem(value: 'REPAIR', child: Text('Onarım')),
                  DropdownMenuItem(
                    value: 'PART_REPLACEMENT',
                    child: Text('Parça Değişimi'),
                  ),
                  DropdownMenuItem(value: 'CHECK', child: Text('Kontrol')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Diğer')),
                ],
                onChanged: (value) => setState(() => _maintenanceType = value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serviceName,
                decoration: const InputDecoration(
                  labelText: 'Servis / Usta Adı',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _laborCost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'İşçilik Bedeli',
                  prefixText: '₺ ',
                ),
              ),
              const SizedBox(height: 14),
              MaintenanceItemsEditor(
                items: _maintenanceItems,
                serviceKilometer: int.tryParse(_km.text.trim()),
                serviceDate: _date,
                onChanged: (items) => setState(() => _maintenanceItems = items),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Toplam Tutar',
                prefixText: '₺ ',
              ),
              validator: (v) =>
                  (_number(v ?? '') ?? 0) <= 0 ? 'Geçerli tutar girin' : null,
            ),
            if (oldFuelLike) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _station,
                decoration: const InputDecoration(labelText: 'İstasyon'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Miktar'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitPrice,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Birim Fiyat'),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _km,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kilometre',
                suffixText: 'km',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Not'),
            ),
            if (widget.expense.documentName != null) ...[
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: Text(widget.expense.documentName!),
                subtitle: const Text('Bağlı belge korunacak'),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
            ),
          ],
        ),
      ),
    ),
  );

  bool get oldFuelLike =>
      widget.expense.type == ExpenseType.fuel ||
      widget.expense.type == ExpenseType.charge;
}
