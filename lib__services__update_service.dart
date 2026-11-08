import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Set at build time by the GitHub workflow (--dart-define=BUILD_NUMBER=...).
const int kBuildNumber = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);

/// The version people see (1.0.0), set from the VERSION file by the workflow.
const String kAppVersion = String.fromEnvironment('APP_VERSION');

/// What to show for the installed app: its version, or the build number for
/// builds made before versions existed.
String get appVersionLabel =>
    kAppVersion.isNotEmpty ? kAppVersion : '$kBuildNumber';

/// GitHub repository that publishes the releases (owner/name).
const String kUpdateRepo = 'waqasyasin029-max/new-app';

class UpdateInfo {
  final int build;
  final String title;
  final String notes;
  final String url;

  /// The new version number (like 1.1.0) read from the release name, if any.
  final String version;
  const UpdateInfo(
    this.build,
    this.title,
    this.notes,
    this.url, [
    this.version = '',
  ]);
}

class UpdateCheck {
  final UpdateInfo? update;
  final bool failed;
  const UpdateCheck({this.update, this.failed = false});
}

class UpdateService {
  /// Asks GitHub for the latest release. Never throws.
  static Future<UpdateCheck> check() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(
        Uri.parse('https://api.github.com/repos/$kUpdateRepo/releases/latest'),
      );
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'kharcha-tracker');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode == 404) return const UpdateCheck(); // no release yet
      if (res.statusCode != 200) return const UpdateCheck(failed: true);
      final body = await res.transform(utf8.decoder).join();
      final j = jsonDecode(body) as Map<String, dynamic>;
      final tag = ((j['tag_name'] as String?) ?? '').replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final build = int.tryParse(tag) ?? 0;
      String? url;
      for (final a in (j['assets'] as List? ?? const [])) {
        final name = (a['name'] as String?) ?? '';
        if (name.endsWith('.apk')) {
          url = a['browser_download_url'] as String?;
          break;
        }
      }
      if (url == null || build <= kBuildNumber) return const UpdateCheck();
      return UpdateCheck(
        update: UpdateInfo(
          build,
          (j['name'] as String?) ?? 'Update $build',
          ((j['body'] as String?) ?? '').trim(),
          url,
          RegExp(r'\d+\.\d+\.\d+').stringMatch((j['name'] as String?) ?? '') ??
              '',
        ),
      );
    } catch (_) {
      return const UpdateCheck(failed: true);
    } finally {
      client.close(force: true);
    }
  }

  /// Downloads the APK into the app cache and reports progress (0..1).
  static Future<File> download(
    UpdateInfo info,
    void Function(double) onProgress,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/kharcha-update-${info.build}.apk');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(info.url));
      req.headers.set('User-Agent', 'kharcha-tracker');
      final res = await req.close();
      if (res.statusCode != 200) {
        throw HttpException('Download failed (HTTP ${res.statusCode})');
      }
      final total = res.contentLength;
      var got = 0;
      var lastPercent = -1;
      final sink = file.openWrite();
      await for (final chunk in res) {
        got += chunk.length;
        sink.add(chunk);
        // Redraw only when the percentage changes, not for every small chunk.
        if (total > 0) {
          final percent = got * 100 ~/ total;
          if (percent != lastPercent) {
            lastPercent = percent;
            onProgress(got / total);
          }
        }
      }
      await sink.flush();
      await sink.close();
      return file;
    } finally {
      client.close(force: true);
    }
  }
}
