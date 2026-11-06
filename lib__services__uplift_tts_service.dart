import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpliftError implements Exception {
  UpliftError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Urdu speech from Uplift AI (a Pakistani voice company), with the user's
/// own API key. Text in, an mp3 file out.
class UpliftTts {
  static const endpoint =
      'https://api.upliftai.org/v1/synthesis/text-to-speech';
  static const defaultVoice = 'v_8eelc901';

  /// The voices named in Uplift's public integration. Others can be used by
  /// pasting their voice id.
  static const voices = <(String, String)>[
    ('Info / Education', 'v_8eelc901'),
    ('Gen Z', 'v_kwmp7zxt'),
    ('Dada Jee (elder)', 'v_yypgzenx'),
    ('Nostalgic News', 'v_30s70t3a'),
  ];

  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return '${h.toRadixString(16)}_${s.length}';
  }

  static String _detail(Uint8List body) {
    try {
      final t = utf8.decode(body, allowMalformed: true).trim();
      return t.length > 160 ? '${t.substring(0, 160)}…' : t;
    } catch (_) {
      return '';
    }
  }

  static Future<File> synth({
    required String key,
    required String voice,
    required String text,
  }) async {
    var t = text.trim();
    if (t.length > 2500) t = t.substring(0, 2500);
    final v = voice.trim().isEmpty ? defaultVoice : voice.trim();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/uplift_${_hash('$v|$t')}.mp3');
    if (await file.exists() && await file.length() > 200) return file;

    final http.Response r;
    try {
      r = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer ${key.trim()}',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: utf8.encode(
              jsonEncode({
                'text': t,
                'voiceId': v,
                'outputFormat': 'MP3_22050_128',
              }),
            ),
          )
          .timeout(const Duration(seconds: 40));
    } catch (_) {
      throw UpliftError('No internet or Uplift is slow. Try again.');
    }

    final c = r.statusCode;
    if (c == 401 || c == 403) {
      throw UpliftError('The Uplift key is not valid or not allowed.');
    }
    if (c == 402 || c == 429) {
      throw UpliftError(
        'Uplift voice limit reached (free minutes may be finished).',
      );
    }
    if (c != 200) {
      throw UpliftError('Uplift error $c. ${_detail(r.bodyBytes)}');
    }
    final b = r.bodyBytes;
    // An error can also come back as a small JSON message.
    if (b.length < 400 && b.isNotEmpty && b[0] == 0x7B) {
      throw UpliftError('Uplift said: ${_detail(b)}');
    }
    if (b.length < 200) {
      throw UpliftError('Uplift sent no audio.');
    }
    await file.writeAsBytes(b, flush: true);
    return file;
  }
}
