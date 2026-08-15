import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/receipt_ocr_result.dart';

class ReceiptReviewValue {
  const ReceiptReviewValue({
    required this.stationName,
    required this.dateTime,
    required this.fuelSubType,
    required this.amount,
    required this.quantity,
    required this.unitPrice,
    required this.receiptNumber,
  });
  final String? stationName;
  final DateTime? dateTime;
  final String? fuelSubType;
  final double? amount;
  final double? quantity;
  final double? unitPrice;
  final String? receiptNumber;
}

class ReceiptOcrReviewScreen extends StatefulWidget {
  const ReceiptOcrReviewScreen({
    super.key,
    required this.imagePath,
    required this.result,
  });
  final String imagePath;
  final ReceiptOcrResult result;

  @override
  State<ReceiptOcrReviewScreen> createState() => _ReceiptOcrReviewScreenState();
}

class _ReceiptOcrReviewScreenState extends State<ReceiptOcrReviewScreen> {
  late final _station = TextEditingController(
    text: widget.result.stationName ?? '',
  );
  late final _amount = TextEditingController(text: _text(widget.result.amount));
  late final _quantity = TextEditingController(
    text: _text(widget.result.quantity),
  );
  late final _unitPrice = TextEditingController(
    text: _text(widget.result.unitPrice),
  );
  late final _receipt = TextEditingController(
    text: widget.result.receiptNumber ?? '',
  );
  late String? _fuel = widget.result.fuelSubType;
  late final DateTime? _date = widget.result.dateTime;

  static String _text(double? value) =>
      value == null ? '' : value.toStringAsFixed(2).replaceAll('.', ',');
  double? _number(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _station.dispose();
    _amount.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _receipt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fiş Bilgilerini Kontrol Edin')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(widget.imagePath),
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _station,
              decoration: const InputDecoration(labelText: 'İstasyon Adı'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _fuel,
              decoration: const InputDecoration(labelText: 'Yakıt Türü'),
              items: const [
                DropdownMenuItem(value: 'BENZIN', child: Text('Benzin')),
                DropdownMenuItem(value: 'LPG', child: Text('LPG')),
                DropdownMenuItem(value: 'DIZEL', child: Text('Dizel')),
              ],
              onChanged: (value) => setState(() => _fuel = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Miktar',
                suffixText: 'L / kWh',
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
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _receipt,
              decoration: const InputDecoration(labelText: 'Fiş Numarası'),
            ),
            if (_date != null) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Okunan Tarih ve Saat',
                ),
                child: Text(
                  '${_date.day.toString().padLeft(2, '0')}.'
                  '${_date.month.toString().padLeft(2, '0')}.'
                  '${_date.year} '
                  '${_date.hour.toString().padLeft(2, '0')}:'
                  '${_date.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.check_rounded),
              label: const Text('Forma Aktar'),
              onPressed: () {
                Navigator.pop(
                  context,
                  ReceiptReviewValue(
                    stationName: _station.text.trim().isEmpty
                        ? null
                        : _station.text.trim(),
                    dateTime: _date,
                    fuelSubType: _fuel,
                    amount: _number(_amount.text),
                    quantity: _number(_quantity.text),
                    unitPrice: _number(_unitPrice.text),
                    receiptNumber: _receipt.text.trim().isEmpty
                        ? null
                        : _receipt.text.trim(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Okunan Ham Metin'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(widget.result.rawText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
