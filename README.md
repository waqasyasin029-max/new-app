# Kharcha Tracker (personal, offline, voice-first)

Flutter + Dart + SQLite. No backend, no subscription. All data stays on the phone.

## Build the APK (Windows / macOS / Linux)

1. Install Flutter (https://docs.flutter.dev/get-started/install) and Android Studio
   (for the Android SDK). Run `flutter doctor` and fix anything marked with a red cross.
   Accept licences: `flutter doctor --android-licenses`.
2. Create a fresh Android project, then copy this folder's contents over it (overwrite):
   ```
   flutter create --platforms=android --project-name kharcha_tracker --org com.personal kharcha_tracker
   ```
   Copy `lib/`, `tool/`, `pubspec.yaml`, `analysis_options.yaml` and `README.md`
   from this package into `kharcha_tracker/`, replacing existing files.
3. Inside `kharcha_tracker/`:
   ```
   dart run tool/patch_android.dart     # permissions, speech + notification setup, desugaring, app name
   flutter pub get
   dart run tool/parser_check.dart      # optional: 22 parser tests, should print ALL PASSED
   flutter analyze                      # should be clean (deprecation "info" lines are harmless)
   flutter run                          # phone with USB debugging, or an emulator
   flutter build apk --release
   ```
4. APK: `build/app/outputs/flutter-apk/app-release.apk`. Copy it to the phone and open it
   (allow "install unknown apps"), or `adb install -r build/app/outputs/flutter-apk/app-release.apk`.

## If the build complains

* **"desugar" / "core library desugaring" error**: the patch script did not match your Gradle file.
  In `android/app/build.gradle(.kts)` set `compileOptions { coreLibraryDesugaringEnabled true }`
  (Kotlin: `isCoreLibraryDesugaringEnabled = true`) and add
  `dependencies { coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4' }`.
* **minSdk error**: set `minSdk = 24` in `android/app/build.gradle(.kts)`.
* **A plugin "namespace not specified" error**: run `flutter pub upgrade` and retry.
* **flutter_local_notifications `uiLocalNotificationDateInterpretation` error**: you resolved v19+.
  Keep `^18.0.1`, or delete that one argument in `lib/services/notification_service.dart`.

## Using it

* Mic button (bottom of every tab) -> speak -> check the text -> **Review expenses** -> fix anything
  -> **Save**. Nothing is stored before you press Save. Expenses with no recognised amount are
  highlighted and must be filled in by you; the app never guesses amounts.
* Languages: pick Urdu (best for Urdu/Roman Urdu speech, the phone returns Urdu script, which the app
  understands), English (Pakistan) or English (US). Digits, number words ("teen sau pachas",
  "dhai hazar", "sadhe teen sau"), "2k" and Urdu numerals are all understood.
* Speech recognition is done by Google's speech service on the phone: it needs internet, or a
  downloaded offline language pack (Google app > Settings > Voice > Offline speech recognition).
* Daily reminder: Settings. Default 11:00 PM. For delivery exactly on the minute tap "Allow exact
  alarms". Also disable battery optimisation for the app on aggressive phones (Xiaomi, Oppo, Vivo, Infinix, Tecno).
* Salary: Settings > Salary & income. A salary carries forward to later months until you change it.
