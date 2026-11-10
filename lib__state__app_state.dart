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
  TimeOfDay reminderTime = const TimeOfDay(hour: 22, minute: 0);

  /// 'system' | 'light' | 'dark'
  String themeMode = 'system';

  /// 'en' | 'ur'
  String language = 'en';

  /// The person's name, shown on Home. Empty when not given.
  String userName = '';
  bool onboardingDone = true;

  /// False on a fresh install until the accounts + app-lock setup is finished.
  bool setupDone = true;

  /// False until the first-run name popup and welcome animation are done.
  bool welcomeDone = true;

  /// Ask for the phone's fingerprint / PIN when the app opens.
  bool appLock = false;

  /// Seconds away from the app before it locks again. 0 = right away,
  /// -1 = only when the app was closed (never on coming back from background).
  int appLockDelay = 30;

  Future<void> init() async {
    categories = await categoryRepo.all();
    accounts = await accountRepo.all();
    final prefs = await SharedPreferences.getInstance();
    // People who already used the app keep their old reminder time (11 PM);
    // new installs get 10 PM.
    final old = prefs.getBool('onboarding_done') ?? false;
    reminderEnabled = prefs.getBool('reminder_enabled') ?? true;
    reminderTime = TimeOfDay(
      hour: prefs.getInt('reminder_hour') ?? (old ? 23 : 22),
      minute: prefs.getInt('reminder_minute') ?? 0,
    );
    themeMode = prefs.getString('theme_mode') ?? 'system';
    onboardingDone = prefs.getBool('onboarding_done') ?? false;
    language = prefs.getString('language') ?? 'en';
    // People who already used the app skip the new first-time setup.
    setupDone = prefs.getBool('setup_done') ?? onboardingDone;
    welcomeDone = prefs.getBool('welcome_done') ?? setupDone;
    appLock = prefs.getBool('app_lock') ?? false;
    appLockDelay = prefs.getInt('app_lock_delay') ?? 30;
    userName = prefs.getString('user_name') ?? '';
    applyLook();
  }

  /// True when the dark theme should be showing right now.
  bool get isDark {
    if (themeMode == 'dark') return true;
    if (themeMode == 'light') return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  Future<void> finishOnboarding() async {
    returnedFromSetup = false;
    onboardingDone = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }

  /// True when the person came back to the intro pages from the first setup:
  /// the intro then opens on its last page.
  bool returnedFromSetup = false;

  /// Back from the first setup step goes to the intro pages again.
  Future<void> backToOnboarding() async {
    returnedFromSetup = true;
    onboardingDone = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', false);
  }

  Future<void> finishSetup() async {
    setupDone = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_done', true);
  }

  Future<void> finishWelcome() async {
    welcomeDone = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('welcome_done', true);
  }

  /// For 5 minutes after the name is first set it can be changed freely.
  /// After that it can be changed once every 24 hours.
  static const nameFreeWindow = Duration(minutes: 5);
  static const nameLockPeriod = Duration(hours: 24);

  /// Until when the name cannot be changed, or null if it can be changed now.
  Future<DateTime?> nameLockedUntil() async {
    if (userName.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final setAt = prefs.getInt('name_set_at');
    if (setAt == null) return null; // set before this rule existed
    final windowEnd = DateTime.fromMillisecondsSinceEpoch(setAt)
        .add(nameFreeWindow);
    final changed = prefs.getInt('name_changed_at');
    final from = changed == null
        ? windowEnd
        : DateTime.fromMillisecondsSinceEpoch(changed);
    final until = from.add(nameLockPeriod);
    final now = DateTime.now();
    if (now.isBefore(windowEnd)) return null;
    return now.isBefore(until) ? until : null;
  }

  Future<void> setUserName(String name) async {
    final first = userName.isEmpty;
    userName = name.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', userName);
    final now = DateTime.now();
    final setAt = prefs.getInt('name_set_at');
    if (first || setAt == null) {
      await prefs.setInt('name_set_at', now.millisecondsSinceEpoch);
      await prefs.remove('name_changed_at');
    } else if (now.isAfter(
      DateTime.fromMillisecondsSinceEpoch(setAt).add(nameFreeWindow),
    )) {
      await prefs.setInt('name_changed_at', now.millisecondsSinceEpoch);
    }
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
      // The breakfast and dinner reminders were removed: clear any that an
      // older version of the app had already scheduled.
      await NotificationService.cancelId(NotificationService.breakfastId);
      await NotificationService.cancelId(NotificationService.dinnerId);
    } catch (e) {
      // Never crash the app because a reminder could not be scheduled.
      NotificationService.lastError ??= '$e';
    }
  }

  Future<void> setAppLockDelay(int seconds) async {
    appLockDelay = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_lock_delay', seconds);
    notifyListeners();
  }

  Future<void> setAppLock(bool on) async {
    appLock = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock', on);
    notifyListeners();
  }
}
