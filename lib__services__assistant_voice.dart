import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import 'gemini_api.dart';
import 'gemini_tts_service.dart';
import 'uplift_tts_service.dart';

/// The assistant's voice. Uplift (Urdu voices) is used first when its key is
/// there, then Gemini. When neither can speak (no key, limit reached) the
/// assistant stays silent and the words stay on the screen.
class AssistantVoice {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _sub;
  Completer<void>? _playing;
  bool _stopped = false;

  String _geminiKey = '';
  String _geminiVoice = 'Kore';
  String _geminiModel = '';
  bool _geminiBroken = false;

  String _upliftKey = '';
  String _upliftVoice = '';
  bool _upliftBroken = false;

  /// Called with a short reason when a voice stops working.
  void Function(String message)? onNotice;

  bool get _upliftOn => _upliftKey.isNotEmpty && !_upliftBroken;
  bool get _geminiOn => _geminiKey.isNotEmpty && !_geminiBroken;
  bool get ready => _upliftOn || _geminiOn;

  void configure({
    required String geminiKey,
    required String geminiVoice,
    required String geminiModel,
    String lastGood = '',
    String upliftKey = '',
    String upliftVoice = '',
  }) {
    _geminiKey = geminiKey.trim();
    _geminiVoice = geminiVoice.isEmpty ? 'Kore' : geminiVoice;
    _geminiModel = geminiModel;
    _geminiBroken = false;
    _upliftKey = upliftKey.trim();
    _upliftVoice = upliftVoice;
    _upliftBroken = false;
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
    if (_upliftOn) {
      try {
        return await UpliftTts.synth(
          key: _upliftKey,
          voice: _upliftVoice,
          text: text,
        );
      } on UpliftError catch (e) {
        _upliftFailed(e.message);
      } catch (_) {
        _upliftFailed('The Uplift voice could not be made.');
      }
    }
    if (_geminiOn) {
      try {
        final r = await GeminiTts.synth(
          key: _geminiKey,
          voice: _geminiVoice,
          text: text,
          model: _geminiModel,
        );
        return r.file;
      } on GeminiError catch (e) {
        _geminiFailed(e.message);
      } catch (_) {
        _geminiFailed(
          'The voice could not be made. The assistant will only write.',
        );
      }
    }
    return null;
  }

  void _upliftFailed(String message) {
    if (_upliftBroken) return;
    _upliftBroken = true;
    onNotice?.call(message);
  }

  void _geminiFailed(String message) {
    if (_geminiBroken) return;
    _geminiBroken = true;
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
