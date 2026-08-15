import 'package:flutter/material.dart';

import '../models/maintenance_item.dart';
import 'app_date_time_picker.dart';

class MaintenanceItemsEditor extends StatelessWidget {
  const MaintenanceItemsEditor({
    super.key,
    required this.items,
    required this.serviceKilometer,
    required this.serviceDate,
    required this.onChanged,
  });

  final List<MaintenanceItem> items;
  final int? serviceKilometer;
  final DateTime serviceDate;
  final ValueChanged<List<MaintenanceItem>> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = items.map((e) => e.type).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Yapılan İşlemler',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: MaintenanceItem.labels.entries
              .map(
                (entry) => FilterChip(
                  label: Text(entry.value),
                  selected: selected.contains(entry.key),
                  onSelected: (value) {
                    final next = [...items];
                    if (value) {
                      next.add(
                        MaintenanceItem(
                          id: '${entry.key.toLowerCase()}_${DateTime.now().microsecondsSinceEpoch}',
                          type: entry.key,
                          title: entry.value,
                          reminderEnabled: false,
                        ),
                      );
                    } else {
                      next.removeWhere((item) => item.type == entry.key);
                    }
                    onChanged(next);
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < items.length; index++)
          Card(
            child: ExpansionTile(
              title: Text(
                items[index].title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(_summary(items[index])),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Detay ve Periyot Düzenle'),
                    onPressed: () async {
                      final value = await showDialog<MaintenanceItem>(
                        context: context,
                        builder: (_) => _MaintenanceItemDialog(
                          item: items[index],
                          serviceKilometer: serviceKilometer,
                          serviceDate: serviceDate,
                        ),
                      );
                      if (value != null) {
                        final next = [...items]..[index] = value;
                        onChanged(next);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _summary(MaintenanceItem item) {
    final details = <String>[];
    if (item.brand?.isNotEmpty == true) {
      details.add(item.brand!);
    }
    if (item.partNumber?.isNotEmpty == true) {
      details.add('Parça: ${item.partNumber}');
    }
    if (item.nextDueKilometer != null) {
      details.add('${item.nextDueKilometer} km');
    }
    if (item.nextDueDate != null) {
      details.add(_date(item.nextDueDate!));
    }
    return details.isEmpty ? 'Detay veya takip girilmedi' : details.join(' • ');
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}

class _MaintenanceItemDialog extends StatefulWidget {
  const _MaintenanceItemDialog({
    required this.item,
    required this.serviceKilometer,
    required this.serviceDate,
  });
  final MaintenanceItem item;
  final int? serviceKilometer;
  final DateTime serviceDate;
  @override
  State<_MaintenanceItemDialog> createState() => _MaintenanceItemDialogState();
}

class _MaintenanceItemDialogState extends State<_MaintenanceItemDialog> {
  late final brand = TextEditingController(text: widget.item.brand ?? '');
  late final part = TextEditingController(text: widget.item.partNumber ?? '');
  late final quantity = TextEditingController(
    text: widget.item.quantity?.toString() ?? '',
  );
  late final unit = TextEditingController(text: widget.item.unit ?? '');
  late final note = TextEditingController(text: widget.item.note ?? '');
  late final intervalKm = TextEditingController(
    text: widget.item.intervalKilometers?.toString() ?? '',
  );
  late final intervalMonths = TextEditingController(
    text: widget.item.intervalMonths?.toString() ?? '',
  );
  late DateTime? nextDate = widget.item.nextDueDate;
  late bool reminder = widget.item.reminderEnabled;

  @override
  void dispose() {
    for (final value in [
      brand,
      part,
      quantity,
      unit,
      note,
      intervalKm,
      intervalMonths,
    ]) {
      value.dispose();
    }
    super.dispose();
  }

  DateTime _addMonths(DateTime source, int months) {
    final targetMonth = source.month - 1 + months;
    final year = source.year + targetMonth ~/ 12;
    final month = targetMonth % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, source.day > lastDay ? lastDay : source.day);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item.title),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: brand,
              decoration: const InputDecoration(labelText: 'Marka'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: part,
              decoration: const InputDecoration(labelText: 'Parça Numarası'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Miktar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: unit,
                    decoration: const InputDecoration(labelText: 'Birim'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Kalem Notu'),
              maxLines: 2,
            ),
            const Divider(height: 28),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Yaklaşan işlemlerde takip et'),
              value: reminder,
              onChanged: (v) => setState(() => reminder = v),
            ),
            if (reminder) ...[
              TextField(
                controller: intervalKm,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kaç km sonra',
                  suffixText: 'km',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: intervalMonths,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kaç ay sonra',
                  suffixText: 'ay',
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Özel sonraki tarih'),
                subtitle: Text(
                  nextDate == null
                      ? 'Periyot ayından hesaplanır'
                      : '${nextDate!.day}.${nextDate!.month}.${nextDate!.year}',
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final value = await AppDateTimePicker.show(
                    context,
                    title: 'Sonraki Değişim Tarihi',
                    mode: AppPickerMode.date,
                    initialValue: nextDate ?? widget.serviceDate,
                    minimumDate: widget.serviceDate,
                    maximumDate: DateTime(2100),
                  );
                  if (value != null) {
                    setState(() => nextDate = value);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: () {
          final kmInterval = int.tryParse(intervalKm.text.trim());
          final monthInterval = int.tryParse(intervalMonths.text.trim());
          Navigator.pop(
            context,
            MaintenanceItem(
              id: widget.item.id,
              type: widget.item.type,
              title: widget.item.title,
              brand: brand.text.trim().isEmpty ? null : brand.text.trim(),
              partNumber: part.text.trim().isEmpty ? null : part.text.trim(),
              quantity: double.tryParse(quantity.text.replaceAll(',', '.')),
              unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
              note: note.text.trim().isEmpty ? null : note.text.trim(),
              intervalKilometers: kmInterval,
              intervalMonths: monthInterval,
              nextDueKilometer:
                  reminder &&
                      kmInterval != null &&
                      widget.serviceKilometer != null
                  ? widget.serviceKilometer! + kmInterval
                  : null,
              nextDueDate: reminder
                  ? (nextDate ??
                        (monthInterval == null
                            ? null
                            : _addMonths(widget.serviceDate, monthInterval)))
                  : null,
              reminderEnabled: reminder,
            ),
          );
        },
        child: const Text('Uygula'),
      ),
    ],
  );
}
