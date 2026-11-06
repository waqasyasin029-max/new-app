import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' hide Text;

import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/eleven_voices_service.dart';
import '../services/tts_service.dart';
import '../widgets/common.dart';

/// What the picker returns.
class PickedVoice {
  PickedVoice(this.id, this.name);
  final String id;
  final String name;
}

/// Lets the user hear and choose an ElevenLabs voice.
class VoicePickerScreen extends StatefulWidget {
  const VoicePickerScreen({
    super.key,
    required this.apiKey,
    required this.model,
    required this.currentId,
    required this.userName,
  });

  final String apiKey;
  final String model;
  final String currentId;
  final String userName;

  @override
  State<VoicePickerScreen> createState() => _VoicePickerScreenState();
}

class _VoicePickerScreenState extends State<VoicePickerScreen> {
  final _player = AudioPlayer();
  final _tts = TtsService();
  final _search = TextEditingController();

  bool _library = true; // false = my voices
  String _gender = 'female'; // '', 'female', 'male'
  bool _loading = false;
  String? _error;
  List<ElevenVoice> _items = [];
  String? _busyId; // voice being added
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _tts.configure(
      key: widget.apiKey,
      voiceId: widget.currentId,
      model: widget.model,
      enabled: true,
    );
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _player.dispose();
    _tts.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<ElevenVoice> list;
      if (_library) {
        list = await ElevenVoicesService.library(
          widget.apiKey,
          gender: _gender,
          search: _search.text,
        );
      } else {
        list = await ElevenVoicesService.mine(widget.apiKey);
        if (_gender.isNotEmpty) {
          list = list.where((v) => v.gender == _gender).toList();
        }
      }
      if (!mounted) return;
      setState(() => _items = list);
    } on VoiceApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load voices. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _preview(ElevenVoice v) async {
    await _tts.stop();
    if (_playingId == v.id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }
    if (v.previewUrl.isEmpty) {
      snack(context, 'This voice has no sample.');
      return;
    }
    setState(() => _playingId = v.id);
    try {
      await _player.stop();
      await _player.play(UrlSource(v.previewUrl));
    } catch (_) {
      if (mounted) {
        setState(() => _playingId = null);
        snack(context, 'Could not play the sample.');
      }
    }
  }

  /// Speaks an Urdu sentence in this voice (uses a few ElevenLabs characters).
  Future<void> _urduSample(ElevenVoice v) async {
    await _player.stop();
    setState(() => _playingId = null);
    String? note;
    _tts.onNotice = (m) => note = m;
    _tts.configure(
      key: widget.apiKey,
      voiceId: v.id,
      model: widget.model,
      enabled: true,
    );
    final name = widget.userName.trim();
    await _tts.speak(
      'السلام علیکم${name.isEmpty ? '' : ' $name سر'}! بتائیے، اب کتنا خرچہ ہوا؟',
    );
    if (note != null && mounted) snack(context, note!);
  }

  Future<void> _use(ElevenVoice v) async {
    var id = v.id;
    if (v.isLibrary) {
      setState(() => _busyId = v.id);
      try {
        id = await ElevenVoicesService.add(widget.apiKey, v);
      } on VoiceApiError catch (e) {
        if (mounted) {
          setState(() => _busyId = null);
          snack(context, e.message);
        }
        return;
      }
    }
    if (!mounted) return;
    Navigator.pop(context, PickedVoice(id, v.name));
  }

  Widget _chip(String label, bool on, VoidCallback tap) =>
      ChoiceChip(label: Text(label), selected: on, onSelected: (_) => tap());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose voice')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip('Urdu library', _library, () {
                  _library = true;
                  _load();
                }),
                _chip('My voices', !_library, () {
                  _library = false;
                  _load();
                }),
                const SizedBox(width: 8),
                _chip('Female', _gender == 'female', () {
                  _gender = 'female';
                  _load();
                }),
                _chip('Male', _gender == 'male', () {
                  _gender = 'male';
                  _load();
                }),
                _chip('All', _gender.isEmpty, () {
                  _gender = '';
                  _load();
                }),
              ],
            ),
          ),
          if (_library)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'Search a voice name',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _load,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              _library
                  ? 'Tap play to hear a free sample. "Use" adds the voice to your ElevenLabs account.'
                  : 'Tap play for a free sample, or the speaker to hear it say an Urdu sentence.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No voices found.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.line),
      itemBuilder: (_, i) {
        final v = _items[i];
        final current = v.id == widget.currentId;
        final playing = _playingId == v.id;
        return ListTile(
          title: Text(
            v.name,
            verbatim: true,
            style: TextStyle(
              fontWeight: current ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          subtitle: Text(
            [
              if (v.gender.isNotEmpty) v.gender,
              if (v.description.isNotEmpty) v.description,
            ].join(' · '),
            verbatim: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: Icon(
              playing ? Icons.stop_circle_outlined : Icons.play_circle_outline,
              size: 30,
            ),
            tooltip: 'Hear sample',
            onPressed: () => _preview(v),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!v.isLibrary)
                IconButton(
                  icon: const Icon(Icons.record_voice_over_outlined),
                  tooltip: 'Hear Urdu sentence',
                  onPressed: () => _urduSample(v),
                ),
              if (_busyId == v.id)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                FilledButton.tonal(
                  onPressed: _busyId != null ? null : () => _use(v),
                  child: Text(current ? 'Selected' : 'Use'),
                ),
            ],
          ),
        );
      },
    );
  }
}
