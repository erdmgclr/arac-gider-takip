import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/reminder.dart';
import '../../repositories/reminder_repository.dart';
import '../../widgets/app_date_time_picker.dart';

class ReminderListScreen extends StatelessWidget {
  const ReminderListScreen({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
  });
  final String vehicleId;
  final String vehicleName;

  Future<void> _edit(BuildContext context, Reminder reminder) async {
    var title = reminder.title;
    var dueDate = reminder.dueDate;
    final km = TextEditingController(
      text: reminder.dueKilometer?.toString() ?? '',
    );
    final note = TextEditingController(text: reminder.note ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Takibi Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: title,
                  decoration: const InputDecoration(labelText: 'Takip Adı'),
                  onChanged: (value) => title = value,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sonraki Tarih'),
                  subtitle: Text(dueDate == null ? 'Yok' : _date(dueDate!)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final value = await AppDateTimePicker.show(
                      context,
                      title: 'Sonraki İşlem Tarihi',
                      mode: AppPickerMode.date,
                      initialValue: dueDate ?? DateTime.now(),
                      minimumDate: DateTime(2000),
                      maximumDate: DateTime(2100),
                    );
                    if (value != null) setState(() => dueDate = value);
                  },
                ),
                TextFormField(
                  controller: km,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sonraki Kilometre',
                    suffixText: 'km',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Not'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await ReminderRepository().update(
        Reminder(
          id: reminder.id,
          userId: reminder.userId,
          vehicleId: reminder.vehicleId,
          title: title.trim().isEmpty ? reminder.title : title.trim(),
          dueDate: dueDate,
          dueKilometer: int.tryParse(km.text.trim()),
          note: note.text.trim().isEmpty ? null : note.text.trim(),
          sourceExpenseId: reminder.sourceExpenseId,
          maintenanceItemId: reminder.maintenanceItemId,
          maintenanceItemType: reminder.maintenanceItemType,
          completed: reminder.completed,
        ),
      );
    }
    km.dispose();
    note.dispose();
  }

  Future<void> _delete(BuildContext context, Reminder reminder) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Takip silinsin mi?'),
            content: Text('${reminder.title} takip listesinden kaldırılacak.'),
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
    if (confirmed) await ReminderRepository().delete(reminder.id);
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Yaklaşan İşlemler')),
      body: userId == null
          ? const Center(child: Text('Oturum bulunamadı.'))
          : StreamBuilder<List<Reminder>>(
              stream: ReminderRepository().watchAllForVehicle(
                userId,
                vehicleId,
              ),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <Reminder>[];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (items.isEmpty) {
                  return const Center(child: Text('Takip kaydı bulunmuyor.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: Checkbox(
                        value: item.completed,
                        onChanged: (value) => ReminderRepository().setCompleted(
                          item.id,
                          value ?? false,
                        ),
                      ),
                      title: Text(item.title),
                      subtitle: Text(
                        [
                          if (item.dueDate != null) _date(item.dueDate!),
                          if (item.dueKilometer != null)
                            '${item.dueKilometer} km',
                        ].join(' • '),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _edit(context, item);
                          if (value == 'delete') _delete(context, item);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                          PopupMenuItem(value: 'delete', child: Text('Sil')),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}
