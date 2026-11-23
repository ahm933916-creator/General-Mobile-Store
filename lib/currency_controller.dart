import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/database_helper.dart';

final ValueNotifier<CurrencySettings> currencySettings = ValueNotifier(const CurrencySettings());

class CurrencySettings {
  final String code;
  final double rate;
  const CurrencySettings({this.code = 'SYP', this.rate = 1});
  String get symbol => code == 'USD' ? '\$' : 'ل.س';
  double display(double value) => code == 'USD' ? value / (rate <= 0 ? 1 : rate) : value;
  String format(double value) => '${display(value).toStringAsFixed(code == 'USD' ? 2 : 0)} $symbol';
}

String formatStoredAmount(double value, {required String? code, required double? rate}) {
  final storedCode = code == 'USD' ? 'USD' : 'SYP';
  return '${(storedCode == 'USD' ? value : value).toStringAsFixed(storedCode == 'USD' ? 2 : 0)} ${storedCode == 'USD' ? '\$' : 'ل.س'}';
}

Future<void> loadCurrencySettings() async {
  final prefs = await SharedPreferences.getInstance();
  currencySettings.value = CurrencySettings(
    code: prefs.getString('currency_code') ?? 'SYP',
    rate: prefs.getDouble('currency_rate') ?? 1,
  );
}

Future<void> saveCurrencySettings({required String code, required double rate}) async {
  final previous = currencySettings.value;
  final double nextRate = rate <= 0 ? 1.0 : rate;
  if (previous.code != code || previous.rate != nextRate) {
    await DatabaseHelper.instance.convertProductPrices(fromCode: previous.code, fromRate: previous.rate, toCode: code, toRate: nextRate);
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('currency_code', code);
  await prefs.setDouble('currency_rate', nextRate);
  currencySettings.value = CurrencySettings(code: code, rate: nextRate);
}
