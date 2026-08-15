class ReceiptOcrResult {
  const ReceiptOcrResult({
    required this.rawText,
    this.stationName,
    this.dateTime,
    this.fuelSubType,
    this.amount,
    this.quantity,
    this.unitPrice,
    this.receiptNumber,
    this.plate,
  });

  final String rawText;
  final String? stationName;
  final DateTime? dateTime;
  final String? fuelSubType;
  final double? amount;
  final double? quantity;
  final double? unitPrice;
  final String? receiptNumber;
  final String? plate;
}
