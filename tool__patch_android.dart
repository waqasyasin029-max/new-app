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
  _patchGradle();
  final stale = File('test/widget_test.dart');
  if (stale.existsSync()) {
    stale.deleteSync();
    stdout.writeln('Removed default test/widget_test.dart');
  }
  stdout.writeln('Android patch complete.');
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
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
''';
  const recog = '''
        <intent>
            <action android:name="android.speech.RecognitionService"/>
        </intent>
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

  x = x.replaceFirst(RegExp(r'<application'), '$perms    <application');
  x = x.replaceFirst('</application>', '$receivers    </application>');
  if (x.contains('<queries>')) {
    x = x.replaceFirst('<queries>', '<queries>\n$recog');
  } else {
    x = x.replaceFirst(
      '</manifest>',
      '    <queries>\n$recog    </queries>\n</manifest>',
    );
  }
  x = x.replaceFirstMapped(
    RegExp(r'android:label="[^"]*"'),
    (_) => 'android:label="Kharcha Tracker"',
  );
  f.writeAsStringSync(x);
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
    groovy.writeAsStringSync(x);
    stdout.writeln('Patched build.gradle');
  } else {
    stderr.writeln(
      'No android/app/build.gradle(.kts) found: add desugaring manually (see README).',
    );
  }
}

String _addDependency(String x, String line) {
  final m = RegExp(r'^dependencies\s*\{', multiLine: true).firstMatch(x);
  if (m != null) {
    return x.replaceRange(m.end, m.end, '\n$line');
  }
  return '$x\ndependencies {\n$line\n}\n';
}
