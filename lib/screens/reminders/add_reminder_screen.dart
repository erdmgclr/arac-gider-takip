import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/reminder.dart';
import '../../repositories/reminder_repository.dart';
import '../../widgets/app_date_time_picker.dart';

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
    this.currentKilometer,
  });
  final String vehicleId;
  final String vehicleName;
  final int? currentKilometer;

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kilometer = TextEditingController();
  final _note = TextEditingController();
  final _repository = ReminderRepository();
  String _title = 'Yağ Değişimi';
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    _kilometer.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await AppDateTimePicker.show(
      context,
      title: 'Sonraki İşlem Tarihi',
      mode: AppPickerMode.date,
      initialValue: _dueDate ?? now,
      minimumDate: DateTime(now.year, now.month, now.day),
      maximumDate: DateTime(2100, 12, 31),
    );
    if (mounted && date != null) setState(() => _dueDate = date);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final km = int.tryParse(_kilometer.text.trim());
    if (_dueDate == null && km == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarih veya kilometreden en az birini girin.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.add(
        Reminder(
          id: '',
          userId: user.uid,
          vehicleId: widget.vehicleId,
          title: _title,
          dueDate: _dueDate,
          dueKilometer: km,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const types = [
      'Yağ Değişimi',
      'Periyodik Bakım',
      'Hava Filtresi',
      'Polen Filtresi',
      'Yakıt Filtresi',
      'Triger Kayışı',
      'Fren Bakımı',
      'Lastik Değişimi',
      'Akü Kontrolü',
      'Şanzıman Yağı',
      'Diğer',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Bakım Takibi Ekle')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.vehicleName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _title,
                decoration: const InputDecoration(labelText: 'Takip Türü'),
                items: types
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _title = value!),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Sonraki İşlem Tarihi',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(
                    _dueDate == null
                        ? 'İsteğe bağlı'
                        : '${_dueDate!.day.toString().padLeft(2, '0')}.${_dueDate!.month.toString().padLeft(2, '0')}.${_dueDate!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _kilometer,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Sonraki İşlem Kilometresi',
                  hintText: widget.currentKilometer?.toString(),
                  suffixText: 'km',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Not'),
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
}
