import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Short "level up" sound played when an expense is saved.
/// Uses the notification stream, so it stays quiet when the phone is on
/// silent or vibrate, and it does not pause music that is playing.
class SoundService {
  SoundService._();
  static const prefKey = 'save_sound';
  static AudioPlayer? _player;

  static Future<void> saved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(prefKey) ?? true)) return;
      var p = _player;
      if (p == null) {
        p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: false,
              stayAwake: false,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.notificationEvent,
              audioFocus: AndroidAudioFocus.none,
            ),
          ),
        );
        _player = p;
      }
      await p.stop();
      await p.play(AssetSource('sounds/save.wav'), volume: 0.8);
    } catch (_) {
      // A missing sound must never break saving.
    }
  }
}
