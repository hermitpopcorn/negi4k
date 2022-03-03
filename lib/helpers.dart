import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'database.dart';

String getBalanceString(Account account) {
  int balance = calculateBalance(account);
  return "${account.currency} $balance";
}

int calculateBalance(Account account) {
  return 0;
}

DateTime getMonthStart(int year, int month) {
  return DateTime(year, month, 1);
}

DateTime getMonthEnd(int year, int month) {
  return DateTime(year, month + 1, 0, 23, 59, 59);
}

String decimalizeAmount(int amount, {bool separator = false}) {
  String s = (Decimal.fromInt(amount) / Decimal.fromInt(100)).toDouble().toStringAsFixed(2);
  if (!separator) return s;

  bool negative = amount < 0;
  if (negative) { s = s.substring(1); }
  List<String> parts = s.split(".");
  List<String> real = parts[0].split('');
  parts[0] = '';
  int c = 0;
  for (int i = real.length - 1; i >= 0; i--) {
    parts[0] = real[i] + parts[0];
    c++;
    if (c % 3 == 0 && i > 0) parts[0] = ',' + parts[0];
  }
  return (negative ? '-' : '') + parts.join(".");
}

Wrap displayAmountWidget(int amount, {String? currency, TextStyle? currencyStyle, TextStyle? numberStyle, TextStyle? decimalStyle}) {
  decimalStyle ??= const TextStyle(fontSize: 10);

  List<String> s = decimalizeAmount(amount, separator: true).split('.');
  return Wrap(    
    crossAxisAlignment: WrapCrossAlignment.end,
    children: [
      if (currency != null) Text(currency + ' ', style: currencyStyle),
      Text(s[0], style: numberStyle),
      Text('.' + s[1], style: decimalStyle),
    ],
  );
}

String formatDateTime(DateTime dt) => "${dt.year.toString()}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
String formatDate(DateTime dt) => "${dt.year.toString()} ${dt.month.toString().padLeft(2, '0')} ${dt.day.toString().padLeft(2, '0')}";
String formatTime(DateTime dt) => "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";