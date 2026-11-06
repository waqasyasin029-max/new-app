import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiError implements Exception {
  GeminiError(this.message, {this.tryNext = false, this.network = false});
  final String message;

  /// True when another model may work (model not found / not supported).
  final bool tryNext;
  final bool network;
  @override
  String toString() => message;
}

/// Text generation with the Gemini API (the user's own free key).
class GeminiApi {
  /// "Latest flash" always points at a current model; the second is a fallback.
  static const textModels = ['gemini-flash-latest', 'gemini-2.5-flash'];

  /// The model that answered last (shown in the checks).
  static String lastModel = '';

  static String detail(http.Response r) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['error'] is Map) {
        final m = '${(j['error'] as Map)['message'] ?? ''}';
        return m.length > 220 ? '${m.substring(0, 220)}…' : m;
      }
    } catch (_) {}
    return '';
  }

  /// Sends [body] to the first model that answers. [fast] first tries with
  /// thinking switched off (quicker answers), then without that setting.
  static Future<Map<String, dynamic>> generate({
    required String key,
    required Map<String, dynamic> body,
    List<String> models = textModels,
    bool fast = true,
  }) async {
    GeminiError? last;
    for (final m in models) {
      for (var attempt = 0; attempt < (fast ? 2 : 1); attempt++) {
        final b = Map<String, dynamic>.from(body);
        if (fast && attempt == 0) {
          final g = Map<String, dynamic>.from(
            (b['generationConfig'] as Map?)?.cast<String, dynamic>() ?? {},
          );
          g['thinkingConfig'] = {'thinkingBudget': 0};
          b['generationConfig'] = g;
        }
        http.Response r;
        try {
          r = await http
              .post(
                Uri.parse(
                  'https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent',
                ),
                headers: {
                  'x-goog-api-key': key.trim(),
                  'Content-Type': 'application/json; charset=utf-8',
                },
                body: utf8.encode(jsonEncode(b)),
              )
              .timeout(const Duration(seconds: 45));
        } catch (_) {
          throw GeminiError('No internet, or it is too slow.', network: true);
        }
        if (r.statusCode == 200) {
          final j = jsonDecode(utf8.decode(r.bodyBytes));
          if (j is Map<String, dynamic>) {
            lastModel = m;
            return j;
          }
          throw GeminiError('Gemini sent an unexpected answer.');
        }
        final c = r.statusCode;
        final d = detail(r);
        if (c == 401 || c == 403) {
          throw GeminiError('The Gemini key is not valid or not allowed.');
        }
        if (c == 429) {
          // Each model has its own free limit: try the next one.
          last = GeminiError(
            'Gemini free limit reached for now ($m). Wait a while or try tomorrow.',
            tryNext: true,
          );
          break;
        }
        if (c == 400 && d.toLowerCase().contains('api key')) {
          throw GeminiError('The Gemini key is not valid.');
        }
        if (c == 400 && fast && attempt == 0) continue; // retry w/o thinking
        last = GeminiError('$m: error $c. $d', tryNext: c == 404 || c == 400);
        if (c >= 500) {
          // Busy server: one more try on the same model.
          if (attempt == 0 && !fast) continue;
        }
        break;
      }
      if (last != null && !last.tryNext && !last.message.contains('error 5')) {
        throw last;
      }
    }
    throw last ?? GeminiError('No Gemini model answered.');
  }
}
