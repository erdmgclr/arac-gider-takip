import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../repositories/expense_repository.dart';
import 'edit_expense_screen.dart';
import 'expense_detail_screen.dart';

class ExpenseHistoryScreen extends StatelessWidget {
  const ExpenseHistoryScreen({
    super.key,
    required this.vehicleName,
    this.vehicleId,
    this.expenses = const <Expense>[],
  });
  final String? vehicleId;
  final String vehicleName;
  final List<Expense> expenses;

  Future<void> _delete(BuildContext context, Expense expense) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Kayıt silinsin mi?'),
            content: const Text(
              'Kayıt rapor ve toplam hesaplarından çıkarılacaktır.',
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
    if (confirmed) {
      await ExpenseRepository().delete(expense.id);
    }
    // Ekran kapatılmaz; Firestore akışı listeyi yerinde günceller.
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final resolvedVehicleId =
        vehicleId ?? (expenses.isEmpty ? null : expenses.first.vehicleId);
    return Scaffold(
      appBar: AppBar(title: Text('$vehicleName Kayıtları')),
      body: uid == null
          ? const Center(child: Text('Oturum bulunamadı.'))
          : resolvedVehicleId == null
          ? const Center(child: Text('Henüz masraf kaydı yok.'))
          : StreamBuilder<List<Expense>>(
              stream: ExpenseRepository().watchForVehicle(
                uid,
                resolvedVehicleId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const <Expense>[];
                if (items.isEmpty) {
                  return const Center(child: Text('Henüz masraf kaydı yok.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExpenseDetailScreen(expense: item),
                        ),
                      ),
                      leading: Icon(
                        item.type == ExpenseType.fuel
                            ? Icons.local_gas_station
                            : Icons.receipt_long,
                      ),
                      title: Text(
                        item.note?.isNotEmpty == true
                            ? item.note!
                            : _label(item),
                      ),
                      subtitle: Text(
                        '${item.expenseDate.day.toString().padLeft(2, '0')}.${item.expenseDate.month.toString().padLeft(2, '0')}.${item.expenseDate.year}${item.documentName == null ? '' : ' • Belge var'}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EditExpenseScreen(expense: item),
                              ),
                            );
                            // Düzenleme dönüşünde bu ekran açık kalır.
                          } else {
                            await _delete(context, item);
                          }
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

  String _label(Expense value) => value.type == ExpenseType.fuel
      ? value.subType ?? 'Yakıt'
      : value.type.name;
}
