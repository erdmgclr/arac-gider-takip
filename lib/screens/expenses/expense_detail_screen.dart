import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/expense.dart';
import 'edit_expense_screen.dart';

class ExpenseDetailScreen extends StatelessWidget {
  const ExpenseDetailScreen({super.key, required this.expense});
  final Expense expense;

  String _date(DateTime value) => Formatters.date(value);

  @override
  Widget build(BuildContext context) {
    final maintenance = expense.effectiveMaintenanceItems;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Masraf Detayı'),
        actions: [
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditExpenseScreen(expense: expense),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            expense.note?.isNotEmpty == true
                ? expense.note!
                : _typeLabel(expense),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _row(
            Icons.calendar_month_outlined,
            'Tarih',
            _date(expense.expenseDate),
          ),
          if (expense.kilometer != null)
            _row(Icons.speed_rounded, 'Kilometre', '${expense.kilometer} km'),
          _row(
            Icons.payments_outlined,
            'Toplam Tutar',
            Formatters.currency(expense.amount),
          ),
          if (expense.serviceName?.isNotEmpty == true)
            _row(Icons.store_outlined, 'Servis / Usta', expense.serviceName!),
          if (expense.laborCost != null)
            _row(
              Icons.handyman_outlined,
              'İşçilik',
              Formatters.currency(expense.laborCost),
            ),
          if (expense.type == ExpenseType.maintenance) ...[
            const SizedBox(height: 20),
            Text(
              'Yapılan İşlemler',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (maintenance.isEmpty) const Text('Bakım kalemi girilmemiş.'),
            for (final item in maintenance)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline_rounded),
                  title: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    [
                      if (item.brand?.isNotEmpty == true)
                        'Marka: ${item.brand}',
                      if (item.partNumber?.isNotEmpty == true)
                        'Parça no: ${item.partNumber}',
                      if (item.quantity != null)
                        '${item.quantity} ${item.unit ?? ''}',
                      if (item.note?.isNotEmpty == true) item.note!,
                      if (item.nextDueKilometer != null)
                        'Sonraki: ${item.nextDueKilometer} km',
                      if (item.nextDueDate != null)
                        'Sonraki: ${_date(item.nextDueDate!)}',
                      if (!item.reminderEnabled) 'Takip kapalı',
                    ].join('\n'),
                  ),
                ),
              ),
          ],
          if (expense.documentName != null) ...[
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Fiş / Fatura'),
              subtitle: Text(expense.documentName!),
              trailing: expense.driveDocumentId == null
                  ? null
                  : const Icon(Icons.cloud_done_outlined),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
  );
  String _typeLabel(Expense value) => value.type == ExpenseType.maintenance
      ? 'Bakım / Onarım'
      : value.type.name;
}
