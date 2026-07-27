import 'package:intl/intl.dart';

final _pkrFormat = NumberFormat('#,##0.00', 'en_US');

/// Formats a number as "1,450.00" (no "Rs." prefix — add that in the UI
/// where needed, so this stays reusable).
String formatPkr(double value) => _pkrFormat.format(value);
