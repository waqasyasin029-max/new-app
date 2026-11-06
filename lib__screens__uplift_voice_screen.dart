import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/uplift_tts_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Key and voice for Uplift AI (Urdu voices), with a Play button to test.
class UpliftVoiceScreen extends StatefulWidget {
  const UpliftVoiceScreen({super.key});

  @override
  State<UpliftVoiceScreen> createState() => _UpliftVoiceScreenState();
}

class _UpliftVoiceScreenState extends State<UpliftVoiceScreen> {
  final _player = AudioPlayer();
  late final TextEditingController _key;
  final _custom = TextEditingController();
  final _text = TextEditingController(
    text:
        'السلام علیکم وقاص سر! بتائیے، آج کتنا خرچہ ہوا؟ '
        'میں نے تین سو روپے کا پیٹرول اور دو سو کی چائے لکھ لی ہے۔',
  );
  String _voice = UpliftTts.defaultVoice; // or 'custom'
  bool _busy = false;
  bool _ok = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _key = TextEditingController(text: s.upliftKey);
    final v = s.upliftVoice;
    if (v.isEmpty) {
      _voice = UpliftTts.defaultVoice;
    } else if (UpliftTts.voices.any((e) => e.$2 == v)) {
      _voice = v;
    } else {
      _voice = 'custom';
      _custom.text = v;
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _key.dispose();
    _custom.dispose();
    _text.dispose();
    super.dispose();
  }

  String get _voiceId => _voice == 'custom' ? _custom.text.trim() : _voice;

  Future<void> _play() async {
    final key = _key.text.trim();
    if (key.isEmpty) {
      snack(context, 'Paste the Uplift key first.');
      return;
    }
    if (_text.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    await _player.stop();
    setState(() {
      _busy = true;
      _result = null;
    });
    final app = context.read<AppState>();
    final watch = Stopwatch()..start();
    try {
      final f = await UpliftTts.synth(
        key: key,
        voice: _voiceId,
        text: _text.text.trim(),
      );
      await app.setUplift(key: key, voice: _voiceId);
      if (!mounted) return;
      setState(() {
        _ok = true;
        _result =
            'Played. Made in ${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s. The assistant will use this voice.';
      });
      await _player.play(DeviceFileSource(f.path));
    } on UpliftError catch (e) {
      if (mounted) {
        setState(() {
          _ok = false;
          _result = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ok = false;
          _result = 'Could not play: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final app = context.read<AppState>();
    await app.setUplift(key: '', voice: '');
    if (!mounted) return;
    setState(() {
      _key.clear();
      _result = 'Uplift key removed. The assistant uses the Gemini voice.';
      _ok = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uplift voice (Urdu)')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            '1. Sign up at upliftai.org.\n'
            '2. Create an API key (it starts with sk_api_).\n'
            '3. Paste it here, pick a voice and tap Play.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: tr('Uplift key'),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _voice,
            borderRadius: BorderRadius.circular(16),
            decoration: InputDecoration(labelText: tr('Voice'), isDense: true),
            items: [
              for (final v in UpliftTts.voices)
                DropdownMenuItem(value: v.$2, child: Text(v.$1)),
              const DropdownMenuItem(
                value: 'custom',
                child: Text('Other (paste voice id)'),
              ),
            ],
            onChanged: (v) => setState(() => _voice = v ?? _voice),
          ),
          if (_voice == 'custom')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _custom,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: tr('Voice id (like v_8eelc901)'),
                  isDense: true,
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 6,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              labelText: tr('Sentence to speak'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _play,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_busy ? 'Generating…' : 'Play'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _result!,
                style: TextStyle(
                  color: _ok ? AppColors.muted : Colors.red,
                  fontSize: 13,
                ),
              ),
            ),
          if (context.read<AppState>().upliftKey.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: _remove,
                child: const Text('Remove Uplift key'),
              ),
            ),
        ],
      ),
    );
  }
}
