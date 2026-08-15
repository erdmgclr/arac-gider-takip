import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../models/expense.dart';
import '../../models/maintenance_item.dart';
import '../../widgets/maintenance_items_editor.dart';
import '../../models/reminder.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/reminder_repository.dart';
import '../../repositories/vehicle_repository.dart';
import '../../services/google_drive_service.dart';
import '../../services/receipt_ocr_service.dart';
import '../../widgets/app_date_time_picker.dart';
import 'receipt_ocr_review_screen.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
    this.initialType = ExpenseType.fuel,
    this.initialKilometer,
  });
  final String vehicleId;
  final String vehicleName;
  final ExpenseType initialType;
  final int? initialKilometer;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  final _station = TextEditingController();
  final _receiptNumber = TextEditingController();
  late final _kilometer = TextEditingController(
    text: widget.initialKilometer?.toString() ?? '',
  );
  final _serviceName = TextEditingController();
  final _laborCost = TextEditingController();
  final _note = TextEditingController();
  final _repository = ExpenseRepository();
  final _vehicleRepository = VehicleRepository();
  final _reminderRepository = ReminderRepository();
  final _ocr = ReceiptOcrService();
  final _picker = ImagePicker();

  late ExpenseType _type = widget.initialType;
  String? _fuelSubType;
  bool _isFullTank = true;
  String _maintenanceType = 'PERIODIC';
  List<MaintenanceItem> _maintenanceItems = <MaintenanceItem>[];
  DateTime _date = DateTime.now();
  String? _documentPath;
  bool _saving = false;
  bool _readingReceipt = false;

  @override
  void dispose() {
    for (final controller in [
      _amount,
      _quantity,
      _unitPrice,
      _station,
      _receiptNumber,
      _kilometer,
      _serviceName,
      _laborCost,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
  void _setNumber(TextEditingController controller, double? value) {
    if (value != null) {
      controller.text = value.toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  Future<ImageSource?> _source() => showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Kameradan Çek'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galeriden Seç'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );

  Future<String?> _pickDocument() async {
    final source = await _source();
    if (source == null) {
      return null;
    }
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 2200,
    );
    if (picked == null) {
      return null;
    }
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory(path.join(directory.path, 'expense_documents'));
    await folder.create(recursive: true);
    final extension = path.extension(picked.path).isEmpty
        ? '.jpg'
        : path.extension(picked.path).toLowerCase();
    final target = path.join(
      folder.path,
      'expense_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    return File(picked.path).copy(target).then((file) => file.path);
  }

  Future<void> _readReceipt() async {
    final selected = await _pickDocument();
    if (selected == null || !mounted) {
      return;
    }
    setState(() => _readingReceipt = true);
    try {
      final result = await _ocr.read(selected);
      if (!mounted) {
        return;
      }
      final reviewed = await Navigator.push<ReceiptReviewValue>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ReceiptOcrReviewScreen(imagePath: selected, result: result),
        ),
      );
      if (reviewed == null || !mounted) {
        return;
      }
      setState(() {
        _documentPath = selected;
        if (reviewed.stationName != null) {
          _station.text = reviewed.stationName!;
        }
        if (reviewed.dateTime != null) {
          _date = reviewed.dateTime!;
        }
        if (reviewed.fuelSubType != null) {
          _fuelSubType = reviewed.fuelSubType;
        }
        _setNumber(_amount, reviewed.amount);
        _setNumber(_quantity, reviewed.quantity);
        _setNumber(_unitPrice, reviewed.unitPrice);
        if (reviewed.receiptNumber != null) {
          _receiptNumber.text = reviewed.receiptNumber!;
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fiş okunamadı: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _readingReceipt = false);
      }
    }
  }

  Future<void> _attachDocument() async {
    final selected = await _pickDocument();
    if (selected != null && mounted) {
      setState(() => _documentPath = selected);
    }
  }

  Future<void> _pickDate() async {
    final value = await AppDateTimePicker.show(
      context,
      title: 'Kayıt Tarihi ve Saati',
      mode: AppPickerMode.dateAndTime,
      initialValue: _date,
    );
    if (mounted && value != null) {
      setState(() => _date = value);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    setState(() => _saving = true);
    late final String createdId;
    try {
      final km = int.tryParse(_kilometer.text.trim());
      final documentName = _documentPath == null
          ? null
          : path.basename(_documentPath!);
      final documentMime = _documentPath == null
          ? null
          : (path.extension(_documentPath!).toLowerCase() == '.png'
                ? 'image/png'
                : 'image/jpeg');
      final expense = Expense(
        id: '',
        userId: user.uid,
        vehicleId: widget.vehicleId,
        type: _type,
        subType: _type == ExpenseType.fuel ? _fuelSubType : null,
        isFullTank: _type == ExpenseType.fuel ? _isFullTank : null,
        stationName: _station.text.trim().isEmpty ? null : _station.text.trim(),
        receiptNumber: _receiptNumber.text.trim().isEmpty
            ? null
            : _receiptNumber.text.trim(),
        documentName: documentName,
        documentMimeType: documentMime,
        maintenanceType: _type == ExpenseType.maintenance
            ? _maintenanceType
            : null,
        serviceName:
            _type == ExpenseType.maintenance &&
                _serviceName.text.trim().isNotEmpty
            ? _serviceName.text.trim()
            : null,
        laborCost: _type == ExpenseType.maintenance
            ? _number(_laborCost.text)
            : null,
        maintenanceItems: _type == ExpenseType.maintenance
            ? _maintenanceItems
            : const <MaintenanceItem>[],
        replacedItems: _type == ExpenseType.maintenance
            ? _maintenanceItems.map((item) => item.type).toList()
            : const <String>[],
        nextMaintenanceDate: null,
        nextMaintenanceKilometer: null,
        amount: _number(_amount.text)!,
        quantity: _number(_quantity.text),
        unitPrice: _number(_unitPrice.text),
        kilometer: km,
        expenseDate: _date,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        localDocumentPath: _documentPath,
      );
      createdId = await _repository.add(expense);
      if (_documentPath != null) {
        final driveId = await GoogleDriveService().upload(
          localPath: _documentPath!,
          name:
              'expense_${user.uid}_${DateTime.now().microsecondsSinceEpoch}${path.extension(_documentPath!)}',
          mimeType: documentMime!,
        );
        await _repository.updateFields(createdId, {'driveDocumentId': driveId});
      }
      if (km != null) {
        await _vehicleRepository.updateCurrentKmIfHigher(
          vehicleId: widget.vehicleId,
          kilometer: km,
        );
      }
      if (_type == ExpenseType.maintenance) {
        final reminders = _maintenanceItems
            .where(
              (item) =>
                  item.reminderEnabled &&
                  (item.nextDueDate != null || item.nextDueKilometer != null),
            )
            .map(
              (item) => Reminder(
                id: '',
                userId: user.uid,
                vehicleId: widget.vehicleId,
                title: item.title,
                dueDate: item.nextDueDate,
                dueKilometer: item.nextDueKilometer,
                note: 'Bakım kaydından otomatik oluşturuldu.',
                sourceExpenseId: createdId,
                maintenanceItemId: item.id,
                maintenanceItemType: item.type,
              ),
            )
            .toList();
        await _reminderRepository.syncMaintenanceReminders(
          sourceExpenseId: createdId,
          userId: user.uid,
          vehicleId: widget.vehicleId,
          reminders: reminders,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kayıt tamamlanamadı: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fuelLike = _type == ExpenseType.fuel || _type == ExpenseType.charge;
    return Scaffold(
      appBar: AppBar(
        title: Text(_type == ExpenseType.fuel ? 'Yakıt Ekle' : 'Gider Ekle'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.vehicleName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ExpenseType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Kayıt Türü'),
                items: ExpenseType.values
                    .map(
                      (e) => DropdownMenuItem(value: e, child: Text(_label(e))),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _type = value!),
              ),
              if (fuelLike) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _readingReceipt ? null : _readReceipt,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(
                    _readingReceipt
                        ? 'Fiş okunuyor...'
                        : 'Fişten Bilgileri Oku',
                  ),
                ),
                if (_type == ExpenseType.fuel) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _fuelSubType,
                    decoration: const InputDecoration(labelText: 'Yakıt Türü'),
                    items: const [
                      DropdownMenuItem(value: 'BENZIN', child: Text('Benzin')),
                      DropdownMenuItem(value: 'LPG', child: Text('LPG')),
                      DropdownMenuItem(value: 'DIZEL', child: Text('Dizel')),
                      DropdownMenuItem(value: 'DIGER', child: Text('Diğer')),
                    ],
                    onChanged: (v) => setState(() => _fuelSubType = v),
                    validator: (v) => _type == ExpenseType.fuel && v == null
                        ? 'Yakıt türünü seçin'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Depo doldu')),
                      ButtonSegment(value: false, label: Text('Kısmi dolum')),
                    ],
                    selected: {_isFullTank},
                    onSelectionChanged: (v) =>
                        setState(() => _isFullTank = v.first),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _station,
                  decoration: const InputDecoration(
                    labelText: 'İstasyon Adı',
                    helperText: 'İsteğe bağlı',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _receiptNumber,
                  decoration: const InputDecoration(labelText: 'Fiş Numarası'),
                ),
              ],
              if (_type == ExpenseType.maintenance) ...[
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
                  onChanged: (value) =>
                      setState(() => _maintenanceType = value!),
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
                  serviceKilometer: int.tryParse(_kilometer.text.trim()),
                  serviceDate: _date,
                  onChanged: (items) =>
                      setState(() => _maintenanceItems = items),
                ),
              ],
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Tarih ve Saat'),
                  child: Text(_date.toLocal().toString().substring(0, 16)),
                ),
              ),
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
              if (fuelLike) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _type == ExpenseType.charge
                        ? 'Enerji'
                        : 'Miktar',
                    suffixText: _type == ExpenseType.charge ? 'kWh' : 'L',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unitPrice,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Birim Fiyat',
                    prefixText: '₺ ',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _kilometer,
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _attachDocument,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(
                  _documentPath == null
                      ? 'Fiş / Evrak Görseli Ekle'
                      : 'Belge Eklendi: ${path.basename(_documentPath!)}',
                ),
              ),
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
  }

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
