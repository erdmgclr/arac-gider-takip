import 'package:intl/intl.dart';

/// Uygulama genelinde tekrarlanan tarih/para birimi formatlama mantığını
/// tek bir yerde toplar. Önceden `settings_screen.dart` ve
/// `add_vehicle_screen.dart` gibi dosyalarda ayrı ayrı yazılmış olan
/// `_formatDate` fonksiyonlarının yerini alır.
class Formatters {
  Formatters._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  static final NumberFormat _decimal = NumberFormat.decimalPattern('tr_TR');

  static final DateFormat _date = DateFormat('dd.MM.yyyy', 'tr_TR');
  static final DateFormat _dateTime = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');

  /// Örn. "1.234,56 ₺"
  static String currency(num? value) => _currency.format(value ?? 0);

  /// Örn. "₺1.234" — ondalıksız, kısa özet kartları için (aylık/toplam gider,
  /// km başı maliyet gibi yerlerde kullanılır).
  static String currencyRounded(num? value) =>
      '₺${_decimal.format((value ?? 0).round())}';

  /// Örn. "12.345" (ondalıksız, kilometre gibi tam sayı değerler için)
  static String decimal(num? value) => _decimal.format(value ?? 0);

  /// Örn. "15.08.2026"
  static String date(DateTime? value) =>
      value == null ? 'Tarihi bilinmeyen' : _date.format(value.toLocal());

  /// Örn. "15.08.2026 14:30"
  static String dateTime(DateTime? value) =>
      value == null ? 'Tarihi bilinmeyen' : _dateTime.format(value.toLocal());
}
