import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/gemini_tts_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Test page: paste a Gemini key, pick a voice, hear it say Urdu.
class GeminiVoiceScreen extends StatefulWidget {
  const GeminiVoiceScreen({super.key});

  @override
  State<GeminiVoiceScreen> createState() => _GeminiVoiceScreenState();
}

class _GeminiVoiceScreenState extends State<GeminiVoiceScreen> {
  final _player = AudioPlayer();
  late final TextEditingController _key;
  final _text = TextEditingController(
    text:
        'السلام علیکم وقاص سر! بتائیے، آج کتنا خرچہ ہوا؟ '
        'میں نے تین سو روپے کا پیٹرول اور دو سو کی چائے لکھ لی ہے۔',
  );
  final _style = TextEditingController();
  bool _female = true;
  bool _busy = false;
  String _voice = 'Kore';
  String _model = '';
  String? _result;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _key = TextEditingController(text: s.geminiKey);
    _voice = GeminiTts.voices.any((v) => v.name == s.geminiVoice)
        ? s.geminiVoice
        : 'Kore';
    _model = GeminiTts.models.contains(s.geminiModel) ? s.geminiModel : '';
    _female = GeminiTts.voices.firstWhere((v) => v.name == _voice).female;
  }

  @override
  void dispose() {
    _player.dispose();
    _key.dispose();
    _text.dispose();
    _style.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final key = _key.text.trim();
    if (key.isEmpty) {
      snack(context, 'Paste the Gemini key first.');
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
    try {
      final r = await GeminiTts.synth(
        key: key,
        voice: _voice,
        text: _text.text.trim(),
        model: _model,
        style: _style.text,
      );
      await app.setGemini(key: key, voice: _voice, model: _model, ok: r.model);
      if (!mounted) return;
      setState(() {
        _ok = true;
        _result = 'Played with ${r.model}';
      });
      await _player.play(DeviceFileSource(r.file.path));
    } on GeminiError catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final names = [
      for (final v in GeminiTts.voices)
        if (v.female == _female) v.name,
    ];
    if (!names.contains(_voice)) _voice = names.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini voice test')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            '1. Open aistudio.google.com/apikey and create a free key.\n'
            '2. Paste it here, pick a voice and tap Play.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: tr('Gemini key'),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Female'),
                selected: _female,
                onSelected: (_) => setState(() => _female = true),
              ),
              ChoiceChip(
                label: const Text('Male'),
                selected: !_female,
                onSelected: (_) => setState(() => _female = false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _voice,
            borderRadius: BorderRadius.circular(16),
            decoration: InputDecoration(labelText: tr('Voice'), isDense: true),
            items: [
              for (final n in names)
                DropdownMenuItem(value: n, child: Text(n, verbatim: true)),
            ],
            onChanged: (v) => setState(() => _voice = v ?? _voice),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _model,
            borderRadius: BorderRadius.circular(16),
            decoration: InputDecoration(labelText: tr('Model'), isDense: true),
            items: [
              DropdownMenuItem(value: '', child: Text('Automatic')),
              for (final m in GeminiTts.models)
                DropdownMenuItem(value: m, child: Text(m, verbatim: true)),
            ],
            onChanged: (v) => setState(() => _model = v ?? ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _style,
            decoration: InputDecoration(
              labelText: tr('Style (optional)'),
              hintText: 'Say warmly and naturally',
              isDense: true,
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
        ],
      ),
    );
  }
}
