import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class GeminiError implements Exception {
  GeminiError(this.message, {this.tryNext = false});
  final String message;

  /// True when another model may work (model not found / not supported).
  final bool tryNext;
  @override
  String toString() => message;
}

class GeminiVoiceInfo {
  const GeminiVoiceInfo(this.name, this.female);
  final String name;
  final bool female;
}

/// Speech from the Gemini API (text in, audio out). Used to test whether
/// Google's voices speak Urdu well before building anything on top.
class GeminiTts {
  /// Tried in this order when the model is "Automatic".
  static const models = [
    'gemini-2.5-flash-preview-tts',
    'gemini-3.1-flash-tts-preview',
    'gemini-3.8-flash-tts',
  ];

  static const voices = <GeminiVoiceInfo>[
    GeminiVoiceInfo('Kore', true),
    GeminiVoiceInfo('Zephyr', true),
    GeminiVoiceInfo('Leda', true),
    GeminiVoiceInfo('Aoede', true),
    GeminiVoiceInfo('Callirrhoe', true),
    GeminiVoiceInfo('Autonoe', true),
    GeminiVoiceInfo('Despina', true),
    GeminiVoiceInfo('Erinome', true),
    GeminiVoiceInfo('Laomedeia', true),
    GeminiVoiceInfo('Achernar', true),
    GeminiVoiceInfo('Gacrux', true),
    GeminiVoiceInfo('Pulcherrima', true),
    GeminiVoiceInfo('Vindemiatrix', true),
    GeminiVoiceInfo('Sulafat', true),
    GeminiVoiceInfo('Puck', false),
    GeminiVoiceInfo('Charon', false),
    GeminiVoiceInfo('Fenrir', false),
    GeminiVoiceInfo('Orus', false),
    GeminiVoiceInfo('Enceladus', false),
    GeminiVoiceInfo('Iapetus', false),
    GeminiVoiceInfo('Umbriel', false),
    GeminiVoiceInfo('Algieba', false),
    GeminiVoiceInfo('Algenib', false),
    GeminiVoiceInfo('Rasalgethi', false),
    GeminiVoiceInfo('Alnilam', false),
    GeminiVoiceInfo('Schedar', false),
    GeminiVoiceInfo('Achird', false),
    GeminiVoiceInfo('Zubenelgenubi', false),
    GeminiVoiceInfo('Sadachbia', false),
    GeminiVoiceInfo('Sadaltager', false),
  ];

  /// Returns a playable wav file and the model that produced it.
  static Future<({File file, String model})> synth({
    required String key,
    required String voice,
    required String text,
    String model = '',
    String style = '',
  }) async {
    final list = model.isEmpty ? models : [model];
    GeminiError? last;
    for (final m in list) {
      try {
        final f = await _one(key, m, voice, text, style);
        return (file: f, model: m);
      } on GeminiError catch (e) {
        last = e;
        if (!e.tryNext) rethrow;
      }
    }
    throw last ?? GeminiError('No Gemini voice model answered.');
  }

  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return '${h.toRadixString(16)}_${s.length}';
  }

  static Future<File> _one(
    String key,
    String model,
    String voice,
    String text,
    String style,
  ) async {
    final prompt = style.trim().isEmpty ? text : '${style.trim()}: $text';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/gem_${_hash('$model|$voice|$prompt')}.wav');
    if (await file.exists() && await file.length() > 44) return file;

    final http.Response r;
    try {
      r = await http
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
            ),
            headers: {
              'x-goog-api-key': key.trim(),
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: utf8.encode(
              jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt},
                    ],
                  },
                ],
                'generationConfig': {
                  'responseModalities': ['AUDIO'],
                  'speechConfig': {
                    'voiceConfig': {
                      'prebuiltVoiceConfig': {'voiceName': voice},
                    },
                  },
                },
              }),
            ),
          )
          .timeout(const Duration(seconds: 40));
    } catch (_) {
      throw GeminiError('No internet or Google is slow. Try again.');
    }

    if (r.statusCode != 200) {
      String detail = '';
      try {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        detail = (j is Map && j['error'] is Map)
            ? '${(j['error'] as Map)['message'] ?? ''}'
            : '';
      } catch (_) {}
      if (detail.length > 220) detail = '${detail.substring(0, 220)}…';
      final c = r.statusCode;
      if (c == 400 && detail.toLowerCase().contains('api key')) {
        throw GeminiError('The Gemini key is not valid.');
      }
      if (c == 401 || c == 403) {
        throw GeminiError('The Gemini key is not valid or not allowed.');
      }
      if (c == 429) {
        throw GeminiError(
          'Gemini free limit reached for now. Wait a minute or try tomorrow.',
        );
      }
      throw GeminiError(
        '$model: error $c. $detail',
        tryNext: c == 404 || c == 400,
      );
    }

    String? b64;
    String mime = '';
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final parts = j['candidates'][0]['content']['parts'] as List;
      for (final p in parts) {
        final d = p is Map ? p['inlineData'] : null;
        if (d is Map && d['data'] is String) {
          b64 = d['data'] as String;
          mime = '${d['mimeType'] ?? ''}';
          break;
        }
      }
    } catch (_) {}
    if (b64 == null || b64.isEmpty) {
      throw GeminiError('$model: no audio came back.', tryNext: true);
    }
    final pcm = base64Decode(b64);
    final rate =
        int.tryParse(RegExp(r'rate=(\d+)').firstMatch(mime)?[1] ?? '') ?? 24000;
    await file.writeAsBytes(_wav(pcm, rate), flush: true);
    return file;
  }

  /// 16-bit mono PCM wrapped in a wav header so any player can read it.
  static Uint8List _wav(Uint8List pcm, int rate) {
    final b = BytesBuilder();
    void str(String s) => b.add(s.codeUnits);
    void u32(int v) =>
        b.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
    void u16(int v) =>
        b.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));
    str('RIFF');
    u32(36 + pcm.length);
    str('WAVE');
    str('fmt ');
    u32(16);
    u16(1);
    u16(1);
    u32(rate);
    u32(rate * 2);
    u16(2);
    u16(16);
    str('data');
    u32(pcm.length);
    b.add(pcm);
    return b.toBytes();
  }
}
