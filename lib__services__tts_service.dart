import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Reads text out loud. Uses ElevenLabs (natural voice) when the user added a
/// key, and the phone's own Urdu text-to-speech otherwise or when the
/// internet / key / limit fails.
class TtsService {
  static const defaultVoiceId = 'pNInz6obpgDQGcFmaJgB';
  static const _autoModels = ['eleven_v3', 'eleven_multilingual_v2'];

  /// The chosen model first, then the automatic ones as a safety net.
  List<String> _models = _autoModels;

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;
  bool available = false; // phone voice

  String _key = '';
  String _voice = defaultVoiceId;
  bool _cloudBroken = false;
  int _modelIndex = 0;
  Completer<void>? _playing;
  StreamSubscription<void>? _doneSub;

  /// Called once with a short reason when the natural voice stops working.
  void Function(String message)? onNotice;

  bool get cloudOn => _key.isNotEmpty && !_cloudBroken;

  void configure({
    required String key,
    required String voiceId,
    required bool enabled,
    String model = '',
  }) {
    final k = enabled ? key.trim() : '';
    final m = model.trim();
    final list = m.isEmpty
        ? _autoModels
        : [m, ..._autoModels.where((e) => e != m)];
    if (k != _key || list.first != _models.first) {
      _cloudBroken = false;
      _modelIndex = 0;
    }
    _models = list;
    _key = k;
    _voice = voiceId.trim().isEmpty ? defaultVoiceId : voiceId.trim();
  }

  /// True when something can speak (natural voice or the phone's voice).
  Future<bool> init() async {
    await _initPhone();
    return available || cloudOn;
  }

  Future<void> _initPhone() async {
    if (_ready) return;
    _ready = true;
    try {
      for (final lang in const ['ur-PK', 'ur-IN', 'ur']) {
        final ok = await _tts.isLanguageAvailable(lang);
        if (ok == true || ok == 1) {
          await _tts.setLanguage(lang);
          available = true;
          break;
        }
      }
      if (available) {
        await _tts.setSpeechRate(0.46);
        await _tts.setPitch(1.0);
        await _tts.setVolume(1.0);
        await _tts.awaitSpeakCompletion(true);
      }
    } catch (_) {
      available = false;
    }
  }

  bool _stopped = false;

  /// Completes when the text has been spoken (or was stopped). With the
  /// natural voice the sentences are fetched at the same time, so the second
  /// one is ready when the first one ends.
  Future<void> speak(String text) async {
    _stopped = false;
    if (!cloudOn) {
      await _speakPhone(text);
      return;
    }
    final parts = _split(text);
    final files = [
      for (final p in parts) _audioFor(p).catchError((_) => null as File?),
    ];
    for (var i = 0; i < parts.length; i++) {
      if (_stopped) return;
      File? f;
      try {
        f = await files[i];
      } catch (_) {
        f = null;
      }
      if (_stopped) return;
      if (f != null && await _play(f)) continue;
      await _speakPhone(parts[i]);
    }
  }

  Future<void> _speakPhone(String text) async {
    if (!available || _stopped) return;
    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  /// At most three chunks, split at sentence ends.
  static List<String> _split(String text) {
    final parts = RegExp(r'[^۔؟!.?]+[۔؟!.?]*')
        .allMatches(text)
        .map((m) => m[0]!.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length <= 3) return parts.isEmpty ? [text] : parts;
    return [parts[0], parts[1], parts.sublist(2).join(' ')];
  }

  Future<void> stop() async {
    _stopped = true;
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    final p = _playing;
    if (p != null && !p.isCompleted) p.complete();
  }

  Future<void> dispose() async {
    await stop();
    await _doneSub?.cancel();
    try {
      await _player.dispose();
    } catch (_) {}
  }

  // ------------------------------------------------------------ ElevenLabs

  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in utf8.encode(s)) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return '${h.toRadixString(16)}_${s.length}';
  }

  Future<File?> _audioFor(String text) async {
    final dir = await getTemporaryDirectory();
    for (var i = _modelIndex; i < _models.length; i++) {
      final model = _models[i];
      final file = File('${dir.path}/tts_${_hash('$model|$_voice|$text')}.mp3');
      if (await file.exists() && await file.length() > 0) {
        _modelIndex = i;
        return file;
      }
      final http.Response res;
      try {
        res = await http
            .post(
              Uri.parse(
                'https://api.elevenlabs.io/v1/text-to-speech/$_voice?output_format=mp3_44100_64',
              ),
              headers: {
                'xi-api-key': _key,
                'Content-Type': 'application/json; charset=utf-8',
                'Accept': 'audio/mpeg',
              },
              body: utf8.encode(
                jsonEncode({
                  'text': text,
                  'model_id': model,
                  'voice_settings': {
                    'stability': 0.5,
                    'similarity_boost': 0.75,
                  },
                }),
              ),
            )
            .timeout(const Duration(seconds: 25));
      } catch (_) {
        // No internet or too slow: use the phone voice for this sentence only.
        return null;
      }
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(res.bodyBytes, flush: true);
        _modelIndex = i;
        return file;
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        _fail('The natural voice key is not valid. Using the phone voice.');
        return null;
      }
      if (res.statusCode == 402 || res.statusCode == 429) {
        _fail('Natural voice limit reached. Using the phone voice.');
        return null;
      }
      // Model or voice not accepted: try the next model.
      if (i == _models.length - 1) {
        _fail('Natural voice could not load. Using the phone voice.');
        return null;
      }
    }
    return null;
  }

  void _fail(String message) {
    _cloudBroken = true;
    onNotice?.call(message);
  }

  Future<bool> _play(File file) async {
    try {
      final done = Completer<void>();
      _playing = done;
      await _doneSub?.cancel();
      _doneSub = _player.onPlayerComplete.listen((_) {
        if (!done.isCompleted) done.complete();
      });
      await _player.play(DeviceFileSource(file.path));
      await done.future.timeout(const Duration(seconds: 90), onTimeout: () {});
      return true;
    } catch (_) {
      return false;
    }
  }
}
