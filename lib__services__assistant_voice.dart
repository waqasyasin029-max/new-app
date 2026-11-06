import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import 'gemini_api.dart';
import 'gemini_tts_service.dart';

/// The assistant's voice: Gemini speech from the user's own key. When it
/// cannot speak (no key, limit reached) the assistant simply stays silent and
/// the words stay on the screen.
class AssistantVoice {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _sub;
  Completer<void>? _playing;
  bool _stopped = false;
  bool _broken = false;
  String _key = '';
  String _voice = 'Kore';
  String _model = '';

  /// Called with a short reason when the voice stops working.
  void Function(String message)? onNotice;

  bool get ready => _key.isNotEmpty && !_broken;

  void configure({
    required String key,
    required String voice,
    required String model,
    String lastGood = '',
  }) {
    _key = key.trim();
    _voice = voice.isEmpty ? 'Kore' : voice;
    _model = model;
    _broken = false;
    if (lastGood.isNotEmpty) GeminiTts.lastGood = lastGood;
  }

  /// Completes when the text has been spoken (or was stopped or failed).
  Future<void> speak(String text) async {
    if (!ready || text.trim().isEmpty) return;
    _stopped = false;
    final parts = _split(text);
    final files = [for (final p in parts) _synth(p)];
    for (final f in files) {
      if (_stopped) return;
      final file = await f;
      if (_stopped || file == null) return;
      await _play(file);
    }
  }

  /// First sentence alone (so it starts sooner), the rest together.
  static List<String> _split(String text) {
    final parts = RegExp(r'[^۔؟!.?]+[۔؟!.?]*')
        .allMatches(text)
        .map((m) => m[0]!.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length <= 1) return [text.trim()];
    return [parts.first, parts.sublist(1).join(' ')];
  }

  Future<File?> _synth(String text) async {
    try {
      final r = await GeminiTts.synth(
        key: _key,
        voice: _voice,
        text: text,
        model: _model,
      );
      return r.file;
    } on GeminiError catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('The voice could not be made. The assistant will only write.');
    }
    return null;
  }

  void _fail(String message) {
    if (_broken) return;
    _broken = true;
    onNotice?.call(message);
  }

  Future<void> _play(File file) async {
    try {
      final done = Completer<void>();
      _playing = done;
      await _sub?.cancel();
      _sub = _player.onPlayerComplete.listen((_) {
        if (!done.isCompleted) done.complete();
      });
      await _player.play(DeviceFileSource(file.path));
      await done.future.timeout(const Duration(seconds: 90), onTimeout: () {});
    } catch (_) {}
  }

  Future<void> stop() async {
    _stopped = true;
    try {
      await _player.stop();
    } catch (_) {}
    final p = _playing;
    if (p != null && !p.isCompleted) p.complete();
  }

  Future<void> dispose() async {
    await stop();
    await _sub?.cancel();
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
