import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'gemini_api.dart';
import 'speech_service.dart' show MicStatus;

/// Records the voice and turns it into text with Whisper large-v3 (served by
/// Groq). Much better at Urdu than the phone's built-in recogniser. Needs
/// internet and the user's own API key (kept only on this phone).
class CloudSpeechService {
  static const _endpoint =
      'https://api.groq.com/openai/v1/audio/transcriptions';
  static const _model = 'whisper-large-v3';

  final AudioRecorder _rec = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _maxTimer;
  bool _recording = false;
  bool _heard = false;
  double _maxDb = -160;
  DateTime _lastLoud = DateTime.now();
  DateTime _startedAt = DateTime.now();
  String _existing = '';
  String _key = '';
  String _locale = 'ur_PK';
  String _provider = 'groq';
  String _fallbackKey = '';

  void Function(String text)? onText;
  void Function(bool listening)? onListening;
  void Function(bool busy)? onBusy;
  void Function(String message)? onError;

  bool get isRecording => _recording;

  Future<MicStatus> ensureMic() async {
    var s = await Permission.microphone.status;
    if (!s.isGranted) s = await Permission.microphone.request();
    if (s.isGranted) return MicStatus.granted;
    if (s.isPermanentlyDenied) return MicStatus.permanentlyDenied;
    return MicStatus.denied;
  }

  Future<void> start({
    required String apiKey,
    required String localeId,
    String existing = '',
    String provider = 'groq',
    String fallbackKey = '',
  }) async {
    _provider = provider;
    _fallbackKey = fallbackKey.trim();
    _key = apiKey.trim();
    _locale = localeId;
    _existing = existing.trim();
    _heard = false;
    _maxDb = -160;
    _lastLoud = DateTime.now();
    _startedAt = DateTime.now();
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/speech_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      _recording = true;
      onListening?.call(true);
      _ampSub = _rec
          .onAmplitudeChanged(const Duration(milliseconds: 150))
          .listen(_onAmplitude);
      // Never record forever.
      _maxTimer = Timer(const Duration(seconds: 75), () => stop());
    } catch (e) {
      _recording = false;
      onListening?.call(false);
      onError?.call('Could not start the microphone: $e');
    }
  }

  void _onAmplitude(Amplitude a) {
    final db = a.current;
    if (db > _maxDb) _maxDb = db;
    final now = DateTime.now();
    if (db > -35) {
      _heard = true;
      _lastLoud = now;
    } else if (_heard &&
        now.difference(_lastLoud) > const Duration(milliseconds: 1600)) {
      // Spoke, then went quiet: finish by itself.
      stop();
    } else if (!_heard &&
        now.difference(_startedAt) > const Duration(seconds: 9)) {
      // Nobody spoke at all.
      stop();
    }
  }

  Future<void> stop() async {
    if (!_recording) return;
    _recording = false;
    _maxTimer?.cancel();
    await _ampSub?.cancel();
    _ampSub = null;
    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {}
    onListening?.call(false);

    final seconds = DateTime.now().difference(_startedAt).inMilliseconds / 1000;
    if (path == null || seconds < 0.8 || (!_heard && _maxDb < -50)) {
      _delete(path);
      onError?.call('Nothing was heard. Tap the mic again and speak clearly.');
      return;
    }

    onBusy?.call(true);
    try {
      final text = await _transcribe(path);
      if (text.isEmpty) {
        onError?.call(
          'Nothing was heard. Tap the mic again and speak clearly.',
        );
      } else {
        onText?.call([_existing, text].where((s) => s.isNotEmpty).join(' '));
      }
    } on _CloudError catch (e) {
      onError?.call(e.message);
    } on SocketException {
      onError?.call(
        'No internet. Turn on internet for AI voice, or switch to the phone voice engine in Settings.',
      );
    } on TimeoutException {
      onError?.call('The internet is too slow. Please try again.');
    } catch (e) {
      onError?.call('Voice error: $e');
    } finally {
      onBusy?.call(false);
      _delete(path);
    }
  }

  /// Gemini listens to the recording directly (used when there is no Groq key).
  Future<String> _transcribeGemini(String path, String key) async {
    final bytes = await File(path).readAsBytes();
    final ur = _locale.startsWith('ur');
    final prompt = ur
        ? 'Transcribe this audio word for word. The speaker talks in Urdu, '
              'sometimes mixed with English or Roman words (money amounts, '
              'JazzCash, Easypaisa, petrol, chai). Write Urdu in Urdu script and '
              'numbers as digits. Output only the transcript. If there is no '
              'speech, output nothing.'
        : 'Transcribe this audio word for word in English. Numbers as digits. '
              'Output only the transcript. If there is no speech, output nothing.';
    try {
      final j = await GeminiApi.generate(
        key: key,
        body: {
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inlineData': {
                    'mimeType': 'audio/wav',
                    'data': base64Encode(bytes),
                  },
                },
              ],
            },
          ],
          'generationConfig': {'temperature': 0},
        },
      );
      final c = j['candidates'];
      if (c is List && c.isNotEmpty && c.first is Map) {
        final content = (c.first as Map)['content'];
        final parts = content is Map ? content['parts'] : null;
        if (parts is List) {
          return parts
              .whereType<Map>()
              .where((p) => p['text'] is String && p['thought'] != true)
              .map((p) => (p['text'] as String).trim())
              .join(' ')
              .trim();
        }
      }
      return '';
    } on GeminiError catch (e) {
      throw _CloudError(e.message);
    }
  }

  Future<String> _transcribe(String path) async {
    if (_provider == 'gemini') return _transcribeGemini(path, _key);
    try {
      return await _transcribeGroq(path);
    } on _CloudError catch (e) {
      // The Groq key is wrong or its free limit is used up: Gemini listens
      // instead, if its key is there.
      if (e.recoverable && _fallbackKey.isNotEmpty) {
        return _transcribeGemini(path, _fallbackKey);
      }
      rethrow;
    }
  }

  Future<String> _transcribeGroq(String path) async {
    final lang = _locale.startsWith('ur') ? 'ur' : 'en';
    final req = http.MultipartRequest('POST', Uri.parse(_endpoint))
      ..headers['Authorization'] = 'Bearer $_key'
      ..fields['model'] = _model
      ..fields['language'] = lang
      ..fields['temperature'] = '0'
      ..fields['response_format'] = 'json'
      ..fields['prompt'] = lang == 'ur' ? _promptUr : _promptEn;
    req.files.add(
      await http.MultipartFile.fromPath('file', path, filename: 'speech.wav'),
    );
    final res = await http.Response.fromStream(
      await req.send().timeout(const Duration(seconds: 45)),
    ).timeout(const Duration(seconds: 45));
    if (res.statusCode == 200) {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      return ((j is Map ? j['text'] : '') ?? '').toString().trim();
    }
    if (res.statusCode == 401) {
      throw _CloudError(
        'The AI voice key is not valid. Check it in Settings > Voice input.',
        recoverable: true,
      );
    }
    if (res.statusCode == 429) {
      throw _CloudError(
        'AI voice free limit reached for now. Wait a minute, or use the phone voice engine.',
        recoverable: true,
      );
    }
    throw _CloudError('AI voice failed (HTTP ${res.statusCode}).');
  }

  /// Stops recording and throws the audio away (the user cancelled).
  Future<void> cancel() async {
    if (!_recording) return;
    _recording = false;
    _maxTimer?.cancel();
    await _ampSub?.cancel();
    _ampSub = null;
    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {}
    await _delete(path);
    onListening?.call(false);
  }

  Future<void> _delete(String? path) async {
    if (path == null) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _recording = false;
    _maxTimer?.cancel();
    await _ampSub?.cancel();
    try {
      await _rec.dispose();
    } catch (_) {}
  }

  // A short hint of the words this app hears often improves spelling.
  static const _promptUr =
      'آج 300 روپے کا پیٹرول، 200 کی چائے، 500 کی گروسری، ناشتہ، کھانا، کرایہ، بجلی کا بل، موبائل لوڈ، جاز کیش، ایزی پیسہ۔';
  static const _promptEn =
      'Today 300 rupees petrol, 200 for tea, 500 groceries, breakfast, lunch, rent, electricity bill, mobile load, JazzCash, Easypaisa.';
}

class _CloudError implements Exception {
  final String message;
  final bool recoverable;
  _CloudError(this.message, {this.recoverable = false});
}
