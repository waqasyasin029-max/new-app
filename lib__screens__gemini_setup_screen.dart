import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/agent_service.dart';
import '../services/gemini_api.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Paste the free Gemini key and check that the assistant can think and
/// use its saving tools.
class GeminiSetupScreen extends StatefulWidget {
  const GeminiSetupScreen({super.key});

  @override
  State<GeminiSetupScreen> createState() => _GeminiSetupScreenState();
}

class _GeminiSetupScreenState extends State<GeminiSetupScreen> {
  late final TextEditingController _key;
  bool _checking = false;
  String _report = '';

  @override
  void initState() {
    super.initState();
    _key = TextEditingController(text: context.read<AppState>().geminiKey);
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    await context.read<AppState>().setGeminiKey(_key.text);
    if (mounted) snack(context, 'Saved.');
  }

  /// Tests what the assistant needs, with timings and the exact error from
  /// Google when one fails.
  Future<void> _check() async {
    final key = _key.text.trim();
    if (key.isEmpty) {
      snack(context, 'Paste the Gemini key first.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _report = '';
    });
    final lines = <String>[];
    void add(String s) {
      lines.add(s);
      if (mounted) setState(() => _report = lines.join('\n'));
    }

    String secs(Stopwatch w) =>
        (w.elapsedMilliseconds / 1000).toStringAsFixed(1);
    final w = Stopwatch()..start();
    try {
      await GeminiApi.generate(
        key: key,
        body: {
          'contents': [
            {
              'parts': [
                {'text': 'Reply with the single word: ok'},
              ],
            },
          ],
          'generationConfig': {'temperature': 0},
        },
      );
      add('1. Thinking: OK in ${secs(w)}s (${GeminiApi.lastModel})');
    } on GeminiError catch (e) {
      add('1. Thinking: FAILED. ${e.message}');
    } catch (e) {
      add('1. Thinking: FAILED. $e');
    }

    w
      ..reset()
      ..start();
    try {
      final j = await GeminiApi.generate(
        key: key,
        body: {
          'systemInstruction': {
            'parts': [
              {
                'text': 'You record expenses. Categories: Food, Fuel, Other. Accounts: Cash, JazzCash. Use the tools.',
              },
            ],
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': '300 ka petrol cash se'},
              ],
            },
          ],
          'tools': [
            {'functionDeclarations': AgentService.toolDeclarations},
          ],
          'toolConfig': {
            'functionCallingConfig': {'mode': 'AUTO'},
          },
          'generationConfig': {'temperature': 0.3},
        },
      );
      var what = 'no answer';
      final c = j['candidates'];
      if (c is List && c.isNotEmpty && c.first is Map) {
        final content = (c.first as Map)['content'];
        final parts = content is Map ? content['parts'] : null;
        if (parts is List) {
          final calls = parts
              .whereType<Map>()
              .where((p) => p['functionCall'] is Map)
              .map((p) => (p['functionCall'] as Map)['name'])
              .toList();
          what = calls.isEmpty
              ? 'answered in words only'
              : 'asked to run ${calls.join(', ')}';
        }
      }
      add('2. Saving tools: OK in ${secs(w)}s, Gemini $what');
    } on GeminiError catch (e) {
      add('2. Saving tools: FAILED. ${e.message}');
    } catch (e) {
      add('2. Saving tools: FAILED. $e');
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini assistant')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            '1. Open aistudio.google.com/apikey and create a free key.\n'
            '2. Paste it here and tap Save.\n'
            '3. Tap Check assistant to make sure it works.',
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
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _checking ? null : _check,
            icon: const Icon(Icons.health_and_safety_rounded),
            label: Text(_checking ? 'Checking…' : 'Check assistant'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          if (_report.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SelectableText(
                _report,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
