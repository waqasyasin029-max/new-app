import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../data/repositories.dart';
import 'notification_service.dart';

/// Budget notifications:
/// * once per month when 80% of the monthly budget is used;
/// * once per week while spending is above the budget.
/// Checked after every saved expense and in the background every few hours.
class BudgetAlert {
  BudgetAlert._();
  static const _pref80 = 'budget_alert_80';
  static const _prefOver = 'budget_over_at';
  static const threshold = 0.8;
  static const overEvery = Duration(days: 7);

  static Future<void> check({bool background = false}) async {
    try {
      final now = DateTime.now();
      final month = Fmt.firstOfMonth(now);
      final budget = (await IncomeRepository().salaryFor(month)).amount;
      if (budget <= 0) return;
      final spent = await ExpenseRepository().total(month, Fmt.lastOfMonth(now));
      if (spent / budget < threshold) return;
      final key = Fmt.monthKey(now);
      final prefs = await SharedPreferences.getInstance();
      final left = budget - spent;

      if (left < 0) {
        final last = prefs.getInt(_prefOver);
        if (last != null &&
            now.difference(DateTime.fromMillisecondsSinceEpoch(last)) <
                overEvery) {
          return;
        }
        await prefs.setInt(_prefOver, now.millisecondsSinceEpoch);
        await prefs.setString(_pref80, key);
        if (background) await NotificationService.init();
        await NotificationService.showBudgetAlert(
          'بجٹ ختم ہو گیا',
          'آپ اس مہینے بجٹ سے ${Fmt.number(-left)} روپے زیادہ خرچ کر چکے ہیں۔ صرف ضروری چیزوں پر خرچ کریں۔',
        );
        return;
      }

      if (prefs.getString(_pref80) == key) return;
      await prefs.setString(_pref80, key);
      final pct = (spent / budget * 100).floor();
      if (background) await NotificationService.init();
      await NotificationService.showBudgetAlert(
        'بجٹ کا $pct٪ خرچ ہو گیا',
        'اس مہینے صرف ${Fmt.number(left)} روپے باقی ہیں۔ سنبھال کر خرچ کریں۔',
      );
    } catch (_) {
      // Alerts must never break saving.
    }
  }
}
