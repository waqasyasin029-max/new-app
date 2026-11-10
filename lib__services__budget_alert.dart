import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../state/app_state.dart';
import 'notification_service.dart';

/// Sends one notification per month when 80% of the monthly budget is used.
class BudgetAlert {
  BudgetAlert._();
  static const _pref = 'budget_alert_80';
  static const threshold = 0.8;

  static Future<void> check(AppState s) async {
    try {
      final now = DateTime.now();
      final month = Fmt.firstOfMonth(now);
      final budget = (await s.incomes.salaryFor(month)).amount;
      if (budget <= 0) return;
      final spent = await s.expenses.total(month, Fmt.lastOfMonth(now));
      if (spent / budget < threshold) return;
      final key = Fmt.monthKey(now);
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_pref) == key) return;
      await prefs.setString(_pref, key);
      final left = budget - spent;
      final pct = (spent / budget * 100).floor();
      if (left >= 0) {
        await NotificationService.showBudgetAlert(
          'بجٹ کا $pct٪ خرچ ہو گیا',
          'اس مہینے صرف ${Fmt.number(left)} روپے باقی ہیں۔ سنبھال کر خرچ کریں۔',
        );
      } else {
        await NotificationService.showBudgetAlert(
          'بجٹ ختم ہو گیا',
          'آپ اس مہینے بجٹ سے ${Fmt.number(-left)} روپے زیادہ خرچ کر چکے ہیں۔',
        );
      }
    } catch (_) {
      // Alerts must never break saving.
    }
  }
}
