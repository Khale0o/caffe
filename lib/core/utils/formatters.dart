import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'ar_EG',
    symbol: 'ج.م',
    decimalDigits: 2,
  );

  static final DateFormat _dateTime = DateFormat(
    'yyyy/MM/dd - hh:mm a',
    'ar_EG',
  );

  static String currency(num value) => _currency.format(value);

  static String dateTime(DateTime value) => _dateTime.format(value);
}
