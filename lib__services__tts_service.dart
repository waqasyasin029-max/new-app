import 'package:flutter_tts/flutter_tts.dart';

/// Reads text out loud in Urdu using the phone's text-to-speech engine.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool available = false;

  Future<bool> init() async {
    if (_ready) return available;
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
    return available;
  }

  /// Completes when the sentence has been spoken (or was stopped).
  Future<void> speak(String text) async {
    if (!available) return;
    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
