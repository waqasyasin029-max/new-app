// Run from the project root after `flutter create`:   dart run tool/patch_android.dart
// Adds permissions, speech/notification declarations, desugaring and app name.
import 'dart:io';

const marker = 'kharcha-patched';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    stderr.writeln(
      'android/ folder not found. Run `flutter create --platforms=android .` first.',
    );
    exit(1);
  }
  _patchManifest(manifest);
  _patchMainActivity();
  _patchGradle();
  _writeProguard();
  final stale = File('test/widget_test.dart');
  if (stale.existsSync()) {
    stale.deleteSync();
    stdout.writeln('Removed default test/widget_test.dart');
  }
  stdout.writeln('Android patch complete.');
}

/// The phone-lock sheet (local_auth) needs a FragmentActivity.
void _patchMainActivity() {
  final root = Directory('android/app/src/main');
  var done = false;
  for (final e in root.listSync(recursive: true)) {
    if (e is File &&
        (e.path.endsWith('/MainActivity.kt') ||
            e.path.endsWith('/MainActivity.java'))) {
      final x = e.readAsStringSync();
      final y = x.replaceAll('FlutterActivity', 'FlutterFragmentActivity');
      if (y != x) e.writeAsStringSync(y);
      stdout.writeln('Patched ${e.path} to FlutterFragmentActivity');
      done = true;
    }
  }
  if (!done)
    stderr.writeln('WARNING: MainActivity not found; app lock may fail.');
}

void _patchManifest(File f) {
  var x = f.readAsStringSync();
  if (x.contains(marker)) {
    stdout.writeln('Manifest already patched.');
    return;
  }
  const perms =
      '''
    <!-- $marker -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
''';
  const receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
''';

  // No cloud/adb backup of the app's data: nobody can pull the database out.
  const noBackup = 'android:allowBackup="false" '
      'android:fullBackupContent="false" '
      'android:dataExtractionRules="@xml/no_backup_rules"';
  x = x.replaceFirst(
    RegExp(r'<application'),
    '$perms    <application $noBackup',
  );
  x = x.replaceFirst('</application>', '$receivers    </application>');
  x = x.replaceFirstMapped(
    RegExp(r'android:label="[^"]*"'),
    (_) => 'android:label="Kharcha Tracker"',
  );
  f.writeAsStringSync(x);
  final xmlDir = Directory('android/app/src/main/res/xml')
    ..createSync(recursive: true);
  File('${xmlDir.path}/no_backup_rules.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup><exclude domain="root"/><exclude domain="file"/><exclude domain="database"/><exclude domain="sharedpref"/></cloud-backup>
    <device-transfer><exclude domain="root"/><exclude domain="file"/><exclude domain="database"/><exclude domain="sharedpref"/></device-transfer>
</data-extraction-rules>
''');
  stdout.writeln('Patched AndroidManifest.xml');
}

void _patchGradle() {
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  if (kts.existsSync()) {
    var x = kts.readAsStringSync();
    if (x.contains('coreLibraryDesugaring')) {
      stdout.writeln('Gradle already patched.');
      return;
    }
    if (x.contains('compileOptions {')) {
      x = x.replaceFirst(
        'compileOptions {',
        'compileOptions {\n        isCoreLibraryDesugaringEnabled = true',
      );
    } else {
      x = x.replaceFirst(
        'android {',
        'android {\n    compileOptions {\n        isCoreLibraryDesugaringEnabled = true\n    }',
      );
    }
    x = _addDependency(
      x,
      '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
    );
    // Keep native libraries compressed inside the APK (about 10 MB download
    // instead of about 20 MB); they are unpacked when the app is installed.
    x = x.replaceFirst(
      'android {',
      'android {\n    packaging {\n        jniLibs {\n            useLegacyPackaging = true\n        }\n    }',
    );
    // Sign with our own fixed key so every update installs over the last one.
    x = x.replaceFirst(
      'buildTypes {',
      'signingConfigs {\n        create("release") {\n'
          '            storeFile = file(System.getProperty("user.home") + "/.android/debug.keystore")\n'
          '            storePassword = "android"\n'
          '            keyAlias = "androiddebugkey"\n'
          '            keyPassword = "android"\n'
          '            storeType = "pkcs12"\n'
          '        }\n    }\n    buildTypes {',
    );
    x = x.replaceAll(
      'signingConfigs.getByName("debug")',
      'signingConfigs.getByName("release")',
    );
    // No R8 renaming or shrinking: it broke the reminder library (Gson could
    // not read its saved data: "Missing type parameter"), so alarms never rang
    // and the app crashed when one fired. The proguard rules are a safety net.
    const signing = 'signingConfig = signingConfigs.getByName("release")';
    if (x.contains(signing)) {
      x = x.replaceFirst(
        signing,
        '$signing\n'
        '            isMinifyEnabled = false\n'
        '            isShrinkResources = false\n'
        '            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")',
      );
    } else {
      stderr.writeln(
        'WARNING: release signingConfig line not found; R8 settings not patched.',
      );
    }
    kts.writeAsStringSync(x);
    stdout.writeln('Patched build.gradle.kts');
  } else if (groovy.existsSync()) {
    var x = groovy.readAsStringSync();
    if (x.contains('coreLibraryDesugaring')) {
      stdout.writeln('Gradle already patched.');
      return;
    }
    if (x.contains('compileOptions {')) {
      x = x.replaceFirst(
        'compileOptions {',
        'compileOptions {\n        coreLibraryDesugaringEnabled true',
      );
    } else {
      x = x.replaceFirst(
        'android {',
        'android {\n    compileOptions {\n        coreLibraryDesugaringEnabled true\n    }',
      );
    }
    x = _addDependency(
      x,
      "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'",
    );
    // Keep native libraries compressed inside the APK (about 10 MB download
    // instead of about 20 MB); they are unpacked when the app is installed.
    x = x.replaceFirst(
      'android {',
      'android {\n    packaging {\n        jniLibs {\n            useLegacyPackaging = true\n        }\n    }',
    );
    x = x.replaceFirst(
      'buildTypes {',
      'signingConfigs {\n        release {\n'
          "            storeFile file(System.getProperty('user.home') + '/.android/debug.keystore')\n"
          "            storePassword 'android'\n"
          "            keyAlias 'androiddebugkey'\n"
          "            keyPassword 'android'\n"
          "            storeType 'pkcs12'\n"
          '        }\n    }\n    buildTypes {',
    );
    x = x.replaceAll('signingConfigs.debug', 'signingConfigs.release');
    const signing = 'signingConfig signingConfigs.release';
    if (x.contains(signing)) {
      x = x.replaceFirst(
        signing,
        '$signing\n'
        '            minifyEnabled false\n'
        '            shrinkResources false\n'
        "            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'",
      );
    } else {
      stderr.writeln(
        'WARNING: release signingConfig line not found; R8 settings not patched.',
      );
    }
    groovy.writeAsStringSync(x);
    stdout.writeln('Patched build.gradle');
  } else {
    stderr.writeln(
      'No android/app/build.gradle(.kts) found: add desugaring manually (see README).',
    );
  }
}

void _writeProguard() {
  File('android/app/proguard-rules.pro').writeAsStringSync('''
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
''');
  stdout.writeln('Wrote proguard-rules.pro');
}

String _addDependency(String x, String line) {
  final m = RegExp(r'^dependencies\s*\{', multiLine: true).firstMatch(x);
  if (m != null) {
    return x.replaceRange(m.end, m.end, '\n$line');
  }
  return '$x\ndependencies {\n$line\n}\n';
}
