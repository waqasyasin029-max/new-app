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

  bool breakfastEnabled = true;
  TimeOfDay breakfastTime = const TimeOfDay(hour: 12, minute: 0);
  bool dinnerEnabled = true;
  TimeOfDay dinnerTime = const TimeOfDay(hour: 21, minute: 30);

  /// 'system' | 'light' | 'dark'
  String themeMode = 'system';

  /// 'en' | 'ur'
  String language = 'en';
  bool onboardingDone = true;
  String voiceEngine = 'cloud'; // 'cloud' (AI) or 'phone'
  String groqKey = '';
  bool assistantOn = true;
  bool smartAgent = true;
  bool naturalVoice = true;
  String elevenKey = '';
  String elevenVoiceId = '';
  String userName = 'وقاص';

  bool get useCloudVoice => voiceEngine == 'cloud' && groqKey.trim().isNotEmpty;

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
    breakfastEnabled = prefs.getBool('breakfast_enabled') ?? true;
    breakfastTime = TimeOfDay(
      hour: prefs.getInt('breakfast_hour') ?? 12,
      minute: prefs.getInt('breakfast_minute') ?? 0,
    );
    dinnerEnabled = prefs.getBool('dinner_enabled') ?? true;
    dinnerTime = TimeOfDay(
      hour: prefs.getInt('dinner_hour') ?? 21,
      minute: prefs.getInt('dinner_minute') ?? 30,
    );
    themeMode = prefs.getString('theme_mode') ?? 'system';
    language = prefs.getString('language') ?? 'en';
    onboardingDone = prefs.getBool('onboarding_done') ?? false;
    voiceEngine = prefs.getString('voice_engine') ?? 'cloud';
    groqKey = prefs.getString('groq_key') ?? '';
    assistantOn = prefs.getBool('assistant_on') ?? true;
    smartAgent = prefs.getBool('smart_agent') ?? true;
    naturalVoice = prefs.getBool('natural_voice') ?? true;
    elevenKey = prefs.getString('eleven_key') ?? '';
    elevenVoiceId = prefs.getString('eleven_voice') ?? '';
    userName = prefs.getString('user_name') ?? 'وقاص';
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
    onboardingDone = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
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

  /// [meal] is 'breakfast' or 'dinner'.
  Future<void> setMealReminder(
    String meal, {
    bool? enabled,
    TimeOfDay? time,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (meal == 'breakfast') {
      if (enabled != null) breakfastEnabled = enabled;
      if (time != null) breakfastTime = time;
      await prefs.setBool('breakfast_enabled', breakfastEnabled);
      await prefs.setInt('breakfast_hour', breakfastTime.hour);
      await prefs.setInt('breakfast_minute', breakfastTime.minute);
    } else {
      if (enabled != null) dinnerEnabled = enabled;
      if (time != null) dinnerTime = time;
      await prefs.setBool('dinner_enabled', dinnerEnabled);
      await prefs.setInt('dinner_hour', dinnerTime.hour);
      await prefs.setInt('dinner_minute', dinnerTime.minute);
    }
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
      if (breakfastEnabled) {
        await NotificationService.scheduleAt(
          id: NotificationService.breakfastId,
          time: breakfastTime,
          title: NotificationService.breakfastTitle,
          text: NotificationService.breakfastBody,
        );
      } else {
        await NotificationService.cancelId(NotificationService.breakfastId);
      }
      if (dinnerEnabled) {
        await NotificationService.scheduleAt(
          id: NotificationService.dinnerId,
          time: dinnerTime,
          title: NotificationService.dinnerTitle,
          text: NotificationService.dinnerBody,
        );
      } else {
        await NotificationService.cancelId(NotificationService.dinnerId);
      }
    } catch (e) {
      // Never crash the app because a reminder could not be scheduled.
      NotificationService.lastError ??= '$e';
    }
  }

  Future<void> setSpeechLocale(String locale) async {
    speechLocale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('speech_locale', locale);
    notifyListeners();
  }

  Future<void> setVoiceEngine(String engine) async {
    voiceEngine = engine;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voice_engine', engine);
    notifyListeners();
  }

  Future<void> setAssistantOn(bool on) async {
    assistantOn = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('assistant_on', on);
    notifyListeners();
  }

  Future<void> setNaturalVoice(bool on) async {
    naturalVoice = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('natural_voice', on);
    notifyListeners();
  }

  Future<void> setEleven({required String key, required String voiceId}) async {
    elevenKey = key.trim();
    elevenVoiceId = voiceId.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eleven_key', elevenKey);
    await prefs.setString('eleven_voice', elevenVoiceId);
    notifyListeners();
  }

  Future<void> setSmartAgent(bool on) async {
    smartAgent = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('smart_agent', on);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    userName = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', userName);
    notifyListeners();
  }

  Future<void> setGroqKey(String key) async {
    groqKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groq_key', groqKey);
    notifyListeners();
  }
}
