import 'package:flutter/material.dart';

class ImportExpensesScreen extends StatelessWidget {
  const ImportExpensesScreen({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
  });
  final String vehicleId;
  final String vehicleName;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Giderleri İçe Aktar')),
    body: const SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Eski kurulum verilerinin genel kullanıcı hesaplarına aktarılmasını önlemek için bu özellik devre dışı bırakıldı.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
