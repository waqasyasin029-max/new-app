import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Set by the GitHub workflow (--dart-define=BUILD_NUMBER=...).
const int kBuildNumber = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);
const String kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

/// Releases of this app live in the same repo as Kharcha Tracker, but with
/// tags like notice-v3 and never marked "latest", so the other app ignores them.
const String kUpdateRepo = 'waqasyasin029-max/new-app';
const String kTagPrefix = 'notice-v';

class AppUpdate {
  final int build;
  final String title;
  final String notes;
  final String url;
  const AppUpdate(this.build, this.title, this.notes, this.url);
}

class UpdateService {
  /// The newer release of this app, or null. Never throws.
  static Future<AppUpdate?> check() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(
        Uri.parse('https://api.github.com/repos/$kUpdateRepo/releases?per_page=30'),
      );
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'kharcha-notice');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(await res.transform(utf8.decoder).join()) as List;
      AppUpdate? best;
      for (final j in list) {
        if (j is! Map<String, dynamic> || j['draft'] == true) continue;
        final tag = (j['tag_name'] as String?) ?? '';
        if (!tag.startsWith(kTagPrefix)) continue;
        final build = int.tryParse(tag.substring(kTagPrefix.length)) ?? 0;
        if (build <= kBuildNumber || (best != null && build <= best.build)) continue;
        String? url;
        for (final a in (j['assets'] as List? ?? const [])) {
          final name = (a['name'] as String?) ?? '';
          if (name.endsWith('.apk')) {
            url = a['browser_download_url'] as String?;
            break;
          }
        }
        if (url == null) continue;
        best = AppUpdate(
          build,
          (j['name'] as String?) ?? 'Update $build',
          ((j['body'] as String?) ?? '').trim(),
          url,
        );
      }
      return best;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<File> download(AppUpdate u, void Function(double) onProgress) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/kharcha-notice-${u.build}.apk');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(u.url));
      req.headers.set('User-Agent', 'kharcha-notice');
      final res = await req.close();
      if (res.statusCode != 200) {
        throw HttpException('Download fail (HTTP ${res.statusCode})');
      }
      final total = res.contentLength;
      var got = 0;
      var last = -1;
      final sink = file.openWrite();
      await for (final chunk in res) {
        got += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          final p = got * 100 ~/ total;
          if (p != last) {
            last = p;
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
