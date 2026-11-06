import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n.dart' show L10n;
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../services/notification_service.dart';

/// Single source of truth for repositories, categories and user settings.
/// [revision] increases whenever stored data changes so screens reload.
class AppState extends ChangeNotifier {
  final categoryRepo = CategoryRepository();
  final expenses = ExpenseRepository();
  final incomes = IncomeRepository();
  final accountRepo = AccountRepository();

  List<Category> categories = [];
  List<Account> accounts = [];
  int revision = 0;

  bool reminderEnabled = true;
  TimeOfDay reminderTime = const TimeOfDay(hour: 23, minute: 0);
  String speechLocale = 'ur_PK';

  /// 'system' | 'light' | 'dark'
  String themeMode = 'system';

  /// 'en' | 'ur'
  String language = 'en';

  static const speechLocales = {
    'ur_PK': 'اردو (Urdu / Roman Urdu)',
    'en_PK': 'English (Pakistan)',
    'en_US': 'English (US)',
  };

  Future<void> init() async {
    categories = await categoryRepo.all();
    accounts = await accountRepo.all();
    final prefs = await SharedPreferences.getInstance();
    reminderEnabled = prefs.getBool('reminder_enabled') ?? true;
    reminderTime = TimeOfDay(
      hour: prefs.getInt('reminder_hour') ?? 23,
      minute: prefs.getInt('reminder_minute') ?? 0,
    );
    speechLocale = prefs.getString('speech_locale') ?? 'ur_PK';
    themeMode = prefs.getString('theme_mode') ?? 'system';
    language = prefs.getString('language') ?? 'en';
    applyLook();
  }

  /// True when the dark theme should be showing right now.
  bool get isDark {
    if (themeMode == 'dark') return true;
    if (themeMode == 'light') return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  /// Pushes the chosen theme and language into the globals the UI reads.
  void applyLook() {
    AppColors.dark = isDark;
    L10n.urdu = language == 'ur';
  }

  Future<void> setThemeMode(String mode) async {
    themeMode = mode;
    applyLook();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    language = lang;
    applyLook();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
    // The reminder text follows the app language.
    await applyReminder();
  }

  Category categoryByName(String name) => categories.firstWhere(
    (c) => c.name == name,
    orElse: () => categories.last,
  );

  Category? categoryById(int id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> reloadAccounts() async {
    accounts = await accountRepo.all();
    changed();
  }

  /// Call after any insert/update/delete.
  void changed() {
    revision++;
    notifyListeners();
  }

  Future<void> setReminder({bool? enabled, TimeOfDay? time}) async {
    if (enabled != null) reminderEnabled = enabled;
    if (time != null) reminderTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', reminderEnabled);
    await prefs.setInt('reminder_hour', reminderTime.hour);
    await prefs.setInt('reminder_minute', reminderTime.minute);
    notifyListeners();
    await applyReminder();
  }

  Future<void> applyReminder() async {
    try {
      if (reminderEnabled) {
        await NotificationService.requestPermission();
        await NotificationService.scheduleDaily(reminderTime);
      } else {
        await NotificationService.cancel();
      }
    } catch (_) {
      // Never crash the app because a reminder could not be scheduled.
    }
  }

  Future<void> setSpeechLocale(String locale) async {
    speechLocale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('speech_locale', locale);
    notifyListeners();
  }
}
