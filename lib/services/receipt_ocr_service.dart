import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/receipt_ocr_result.dart';

class ReceiptOcrService {
  Future<ReceiptOcrResult> read(String imagePath) async {
    if (!await File(imagePath).exists()) {
      throw StateError('Fiş görseli bulunamadı.');
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return _parse(text.text);
    } finally {
      await recognizer.close();
    }
  }

  ReceiptOcrResult _parse(String raw) {
    final normalized = raw.replaceAll('\r', '\n');
    final lines = normalized
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return ReceiptOcrResult(
      rawText: raw,
      stationName: _station(lines),
      dateTime: _dateTime(raw),
      fuelSubType: _fuel(raw),
      amount: _moneyByLabels(raw, const ['TOPLAM', 'GENEL TOPLAM', 'TUTAR']),
      quantity: _quantity(raw),
      unitPrice: _moneyByLabels(raw, const [
        'BİRİM FİYAT',
        'BIRIM FIYAT',
        'LİTRE FİYATI',
      ]),
      receiptNumber: _textAfter(
        raw,
        RegExp(
          r'(?:FİŞ|FIS|BELGE)\s*(?:NO|NUMARASI)?\s*[:#]?\s*([A-Z0-9-]+)',
          caseSensitive: false,
        ),
      ),
      plate: _textAfter(
        raw,
        RegExp(
          r'PLAKA\s*[:#]?\s*([0-9]{2}\s*[A-ZÇĞİÖŞÜ]{1,3}\s*\d{2,4})',
          caseSensitive: false,
        ),
      ),
    );
  }

  String? _station(List<String> lines) {
    const brands = [
      'OPET',
      'SHELL',
      'PETROL OFİSİ',
      'PETROL OFISI',
      'TOTAL',
      'AYTEMİZ',
      'AYTEMIZ',
      'BP',
      'SUNPET',
      'ALPET',
      'MOİL',
      'MOIL',
    ];
    for (final line in lines.take(8)) {
      final upper = line.toUpperCase();
      for (final brand in brands) {
        if (upper.contains(brand)) return _title(brand);
      }
    }
    return lines.isEmpty
        ? null
        : lines.first.length <= 40
        ? lines.first
        : null;
  }

  DateTime? _dateTime(String text) {
    final date = RegExp(
      r'(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})',
    ).firstMatch(text);
    if (date == null) {
      return null;
    }
    final time = RegExp(r'([01]?\d|2[0-3])[:.]([0-5]\d)').firstMatch(text);
    var year = int.parse(date.group(3)!);
    if (year < 100) {
      year += 2000;
    }
    return DateTime(
      year,
      int.parse(date.group(2)!),
      int.parse(date.group(1)!),
      time == null ? 12 : int.parse(time.group(1)!),
      time == null ? 0 : int.parse(time.group(2)!),
    );
  }

  String? _fuel(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('LPG') || upper.contains('OTOGAZ')) {
      return 'LPG';
    }
    if (upper.contains('MOTORİN') ||
        upper.contains('MOTORIN') ||
        upper.contains('DİZEL')) {
      return 'DIZEL';
    }
    if (upper.contains('BENZİN') ||
        upper.contains('BENZIN') ||
        upper.contains('KURŞUNSUZ')) {
      return 'BENZIN';
    }
    return null;
  }

  double? _quantity(String text) {
    final match = RegExp(
      r'(\d+[.,]\d{1,3})\s*(?:LT|LİTRE|LITRE|L\b)',
      caseSensitive: false,
    ).firstMatch(text);
    return match == null ? null : _number(match.group(1));
  }

  double? _moneyByLabels(String text, List<String> labels) {
    for (final label in labels) {
      final escaped = RegExp.escape(label);
      final match = RegExp(
        '$escaped\\s*[:=]?\\s*(?:TL|₺)?\\s*(\\d+[.,]\\d{2})',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return _number(match.group(1));
      }
    }
    return null;
  }

  String? _textAfter(String text, RegExp expression) =>
      expression.firstMatch(text)?.group(1)?.trim();
  double? _number(String? value) => value == null
      ? null
      : double.tryParse(value.replaceAll('.', '').replaceAll(',', '.'));
  String _title(String value) => value
      .split(' ')
      .map((e) => e.isEmpty ? e : '${e[0]}${e.substring(1).toLowerCase()}')
      .join(' ');
}
