import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum MicStatus { granted, denied, permanentlyDenied }

/// Wraps speech_to_text and keeps listening across Android's automatic
/// end-of-speech cut-offs so a long sentence is captured in full.
class SpeechService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _ready = false;
  bool _want = false;
  bool _gotWordsThisRound = false;
  int _silentRounds = 0;
  String _committed = '';
  String _partial = '';
  String _locale = 'ur_PK';
  bool _once = false;

  void Function(String text)? onText;
  void Function(bool listening)? onListening;
  void Function(String message)? onError;

  Future<MicStatus> ensureMic() async {
    var s = await Permission.microphone.status;
    if (!s.isGranted) s = await Permission.microphone.request();
    if (s.isGranted) return MicStatus.granted;
    if (s.isPermanentlyDenied) return MicStatus.permanentlyDenied;
    return MicStatus.denied;
  }

  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(onError: _onError, onStatus: _onStatus);
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  Future<void> start({
    required String localeId,
    String existing = '',
    bool once = false,
  }) async {
    _locale = localeId;
    _once = once;
    _committed = existing.trim();
    _partial = '';
    _silentRounds = 0;
    _want = true;
    onListening?.call(true);
    await _begin();
  }

  Future<void> _begin() async {
    _gotWordsThisRound = false;
    try {
      await _stt.listen(
        onResult: _onResult,
        localeId: _locale,
        listenFor: const Duration(minutes: 2),
        pauseFor: Duration(seconds: _once ? 4 : 8),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e) {
      _fail('Could not start listening: $e');
    }
  }

  Future<void> stop() async {
    _want = false;
    try {
      await _stt.stop();
    } catch (_) {}
    _commitPartial();
    onListening?.call(false);
  }

  /// Stops without producing any result (the user cancelled).
  Future<void> cancel() async {
    _want = false;
    _partial = '';
    try {
      await _stt.cancel();
    } catch (_) {}
    onListening?.call(false);
  }

  Future<void> dispose() async {
    _want = false;
    try {
      await _stt.cancel();
    } catch (_) {}
  }

  String _join(String a, String b) =>
      [a, b].where((s) => s.trim().isNotEmpty).join(' ').trim();

  void _commitPartial() {
    if (_partial.isNotEmpty) {
      _committed = _join(_committed, _partial);
      _partial = '';
    }
    onText?.call(_committed);
  }

  void _onResult(SpeechRecognitionResult r) {
    _partial = r.recognizedWords;
    if (_partial.trim().isNotEmpty) _gotWordsThisRound = true;
    if (r.finalResult) {
      _commitPartial();
    } else {
      onText?.call(_join(_committed, _partial));
    }
  }

  void _onStatus(String status) {
    if (status != 'done' && status != 'notListening') return;
    _commitPartial();
    if (!_want) {
      onListening?.call(false);
      return;
    }
    if (_once && _gotWordsThisRound) {
      // One answer is enough in assistant mode.
      _want = false;
      onListening?.call(false);
      return;
    }
    if (_gotWordsThisRound) {
      _silentRounds = 0;
    } else {
      _silentRounds++;
    }
    if (_silentRounds >= 2) {
      _want = false;
      onListening?.call(false);
      onError?.call(
        'Kuch sunai nahi diya. Mic dobara dabayein aur saaf bolein.',
      );
      return;
    }
    Future.delayed(const Duration(milliseconds: 350), () {
      if (_want && !_stt.isListening) _begin();
    });
  }

  void _onError(SpeechRecognitionError e) {
    switch (e.errorMsg) {
      case 'error_no_match':
      case 'error_speech_timeout':
        return; // handled by the silent-round counter in _onStatus
      case 'error_permission':
        _fail('Microphone permission is missing.');
        break;
      case 'error_network':
      case 'error_network_timeout':
      case 'error_server':
        _fail(
          'Speech recognition needs internet (or an offline language pack in Google app settings).',
        );
        break;
      case 'error_language_not_supported':
      case 'error_language_unavailable':
        _fail(
          'This language is not available on your phone. Choose another language above.',
        );
        break;
      case 'error_busy':
        _fail('Speech service is busy. Wait a moment and try again.');
        break;
      case 'error_audio':
        _fail('Could not access the microphone. Is another app using it?');
        break;
      default:
        _fail('Speech error: ${e.errorMsg}');
    }
  }

  void _fail(String message) {
    _want = false;
    _commitPartial();
    onListening?.call(false);
    onError?.call(message);
  }
}
