import 'dart:convert';

import 'package:http/http.dart' as http;

/// The repo that holds the notices (public, only notice files in it).
const String kNoticeRepo = 'waqasyasin029-max/kharcha-notices';

class Notice {
  final String id;
  final String title;
  final String body;
  final String? expires; // yyyy-MM-dd or null
  final bool active;
  const Notice({
    required this.id,
    required this.title,
    required this.body,
    this.expires,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
    'active': active,
    'id': id,
    'title': title,
    'body': body,
    'expires': expires,
  };

  static Notice fromJson(Map<String, dynamic> j) => Notice(
    id: (j['id'] as String?) ?? '',
    title: (j['title'] as String?) ?? '',
    body: (j['body'] as String?) ?? '',
    expires: j['expires'] as String?,
    active: j['active'] == true,
  );

  /// True when people still get this notice today.
  bool get isLive {
    if (!active) return false;
    final e = expires;
    if (e == null || e.isEmpty) return true;
    final d = DateTime.tryParse(e);
    if (d == null) return true;
    final now = DateTime.now();
    return !DateTime(d.year, d.month, d.day).isBefore(
      DateTime(now.year, now.month, now.day),
    );
  }
}

class GithubError implements Exception {
  final String message;
  GithubError(this.message);
  @override
  String toString() => message;
}

class GithubApi {
  final String token;
  GithubApi(this.token);

  Map<String, String> get _h => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'kharcha-notice',
  };

  Uri _u(String path) => Uri.parse('https://api.github.com/repos/$kNoticeRepo$path');

  String _err(http.Response r) {
    try {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return '${j['message'] ?? 'HTTP ${r.statusCode}'}';
    } catch (_) {
      return 'HTTP ${r.statusCode}';
    }
  }

  /// Throws a readable error unless this token can write to the notices repo.
  Future<void> verify() async {
    final http.Response r;
    try {
      r = await http.get(_u(''), headers: _h).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw GithubError('Internet check karo, phir dobara try karo.');
    }
    if (r.statusCode == 401) throw GithubError('Token galat hai ya expire ho gaya.');
    if (r.statusCode == 404) {
      throw GithubError('Repo "$kNoticeRepo" nahi mili, ya token us repo ka nahi hai.');
    }
    if (r.statusCode != 200) throw GithubError(_err(r));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final perms = j['permissions'];
    if (perms is Map && perms['push'] != true) {
      throw GithubError('Token ko "Contents: Read and write" ki ijazat chahiye.');
    }
  }

  Future<String?> _sha(String path) async {
    final r = await http.get(_u('/contents/$path'), headers: _h);
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw GithubError(_err(r));
    final j = jsonDecode(r.body);
    return j is Map<String, dynamic> ? j['sha'] as String? : null;
  }

  Future<void> _put(String path, String content, String message, {String? sha}) async {
    final body = <String, dynamic>{
      'message': message,
      'content': base64Encode(utf8.encode(content)),
      if (sha != null) 'sha': sha,
    };
    final http.Response r;
    try {
      r = await http
          .put(_u('/contents/$path'), headers: _h, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw GithubError('Internet check karo, phir dobara try karo.');
    }
    if (r.statusCode != 200 && r.statusCode != 201) throw GithubError(_err(r));
  }

  /// Saves the notice in the history and makes it the one everybody gets.
  Future<void> send(Notice n) async {
    final text = const JsonEncoder.withIndent('  ').convert(n.toJson());
    await _put('notices/${n.id}.json', text, 'Notice ${n.id}');
    final sha = await _sha('latest.json');
    await _put('latest.json', text, 'Latest ${n.id}', sha: sha);
  }

  /// The newest notices first (at most [limit]).
  Future<List<Notice>> history({int limit = 10}) async {
    final r = await http.get(_u('/contents/notices'), headers: _h);
    if (r.statusCode == 404) return const [];
    if (r.statusCode != 200) throw GithubError(_err(r));
    final list = jsonDecode(r.body) as List;
    final names = [
      for (final f in list)
        if (f is Map && '${f['name']}'.endsWith('.json')) '${f['name']}',
    ]..sort((a, b) => b.compareTo(a));
    final out = <Notice>[];
    for (final name in names.take(limit)) {
      final fr = await http.get(
        _u('/contents/notices/$name'),
        headers: {..._h, 'Accept': 'application/vnd.github.raw+json'},
      );
      if (fr.statusCode != 200) continue;
      try {
        out.add(Notice.fromJson(jsonDecode(utf8.decode(fr.bodyBytes)) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }
}
