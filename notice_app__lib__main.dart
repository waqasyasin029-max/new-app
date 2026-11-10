import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'github.dart';
import 'update.dart';

const _orange = Color(0xFFEE6F2B);
const _bg = Color(0xFFF8F8FA);
const _line = Color(0xFFE9E9ED);
const _field = Color(0xFFF1F1F4);
const _ink = Color(0xFF16161A);
const _muted = Color(0xFF5E5E69);
const _green = Color(0xFF1F9D55);

void main() => runApp(const NoticeApp());

class NoticeApp extends StatelessWidget {
  const NoticeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kharcha Notice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _orange, primary: _orange),
        scaffoldBackgroundColor: _bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: _bg,
          surfaceTintColor: Colors.transparent,
          foregroundColor: _ink,
          elevation: 0,
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink),
        ),
      ),
      home: const _Root(),
    );
  }
}

/// Decides between the first-time setup and the main screen.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  String? _token;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _token = p.getString('gh_token');
      _loaded = true;
    });
    if (_token != null) _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    final u = await UpdateService.check();
    if (u != null && mounted) {
      showDialog<void>(context: context, builder: (_) => _UpdateDialog(u));
    }
  }

  Future<void> _setToken(String? t) async {
    final p = await SharedPreferences.getInstance();
    if (t == null) {
      await p.remove('gh_token');
    } else {
      await p.setString('gh_token', t);
    }
    if (!mounted) return;
    setState(() => _token = t);
    if (t != null) _checkUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: SizedBox());
    final t = _token;
    if (t == null) return _SetupScreen(onSaved: (v) => _setToken(v));
    return _HomeScreen(token: t, onSignOut: () => _setToken(null));
  }
}

// ---------------------------------------------------------------- setup

class _SetupScreen extends StatefulWidget {
  final ValueChanged<String> onSaved;
  const _SetupScreen({required this.onSaved});

  @override
  State<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<_SetupScreen> {
  final _c = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = _c.text.trim();
    if (t.isEmpty) {
      setState(() => _error = 'Pehle token paste karo.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await GithubApi(t).verify();
      widget.onSaved(t);
    } on GithubError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _step(String n, String title, String sub) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(n, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB9490F))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              Text(sub, style: const TextStyle(fontSize: 12.5, color: _muted)),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF58A4B), _orange]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text('Kharcha Notice', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Dosto ko notification bhejne ka chhota app.\nPehli baar ek chhota setup.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _muted),
              ),
            ),
            const SizedBox(height: 20),
            _step('1', 'GitHub token banao',
                'Sirf "$kNoticeRepo" repo ke liye, Contents: Read and write.'),
            _step('2', 'Yahan paste karo', 'Token sirf is phone me rehta hai.'),
            const SizedBox(height: 6),
            TextField(
              controller: _c,
              obscureText: _hide,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'GitHub token',
                filled: true,
                fillColor: _field,
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.vpn_key_outlined),
                label: const Text('Save karo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Token banane ka tareeqa: GitHub > Settings > Developer settings > Fine-grained tokens > '
              'Generate new token. Repository access me sirf kharcha-notices chuno, '
              'Permissions > Contents > Read and write.',
              style: TextStyle(fontSize: 12.5, color: _muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- home

class _HomeScreen extends StatefulWidget {
  final String token;
  final VoidCallback onSignOut;
  const _HomeScreen({required this.token, required this.onSignOut});

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  late final GithubApi _api = GithubApi(widget.token);
  final _title = TextEditingController();
  final _body = TextEditingController();
  DateTime? _expires;
  bool _sending = false;
  List<Notice>? _history;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _title.addListener(_redraw);
    _body.addListener(_redraw);
    _loadHistory();
  }

  void _redraw() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final h = await _api.history();
      if (mounted) {
        setState(() {
          _history = h;
          _historyError = null;
        });
      }
    } on GithubError catch (e) {
      if (mounted) setState(() => _historyError = e.message);
    } catch (_) {
      if (mounted) setState(() => _historyError = 'History nahi aa saki.');
    }
  }

  String _newId() {
    final d = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${p(d.month)}${p(d.day)}-${p(d.hour)}${p(d.minute)}${p(d.second)}';
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _canSend => _title.text.trim().isNotEmpty && _body.text.trim().isNotEmpty && !_sending;

  Future<bool> _confirm(String title, String text, String yes) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _send({required bool stop}) async {
    final ok = stop
        ? await _confirm('Notice band karo?', 'Phir kisi ko koi naya notice nahi aayega.', 'Band karo')
        : await _confirm('Sab ko bhejna hai?', 'Ye notice sab dosto ke phones tak pahunch jayega.', 'Bhejo');
    if (!ok) return;
    setState(() => _sending = true);
    final n = stop
        ? Notice(id: _newId(), title: '', body: '', active: false)
        : Notice(
            id: _newId(),
            title: _title.text.trim(),
            body: _body.text.trim(),
            expires: _expires == null ? null : _dateKey(_expires!),
          );
    try {
      await _api.send(n);
      if (!mounted) return;
      if (!stop) {
        _title.clear();
        _body.clear();
        _expires = null;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => _SentScreen(stopped: stop)),
      );
      _loadHistory();
    } on GithubError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nahi bheja ja saka: ${e.message}')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nahi bheja ja saka. Internet check karo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _expires ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _expires = d);
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: _field,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
  );

  Widget _preview() {
    final t = _title.text.trim().isEmpty ? '…' : _title.text.trim();
    final m = _body.text.trim().isEmpty ? '…' : _body.text.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDCE3EE), Color(0xFFEEF1F6)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              'PHONE PAR AISA DIKHEGA',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: _muted),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.94),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.account_balance_wallet, size: 10, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Text('Kharcha Tracker · abhi', style: TextStyle(fontSize: 11.5, color: _muted)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.6)),
                            Text(m, style: const TextStyle(fontSize: 13, color: _muted, height: 1.7)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFF58A4B), _orange]),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 22),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard() {
    final h = _history;
    if (_historyError != null) {
      return Text(_historyError!, style: const TextStyle(color: _muted, fontSize: 13));
    }
    if (h == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    }
    if (h.isEmpty) {
      return const Text('Abhi koi notice nahi bheja.', style: TextStyle(color: _muted, fontSize: 13));
    }
    final liveId = h.firstWhere((n) => n.isLive, orElse: () => const Notice(id: '', title: '', body: '')).id;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          for (var i = 0; i < h.length; i++)
            Container(
              decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: _line))),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h[i].active ? h[i].title : 'Notice band kiya',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(_prettyId(h[i].id), style: const TextStyle(fontSize: 12, color: _muted)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _badge(h[i].id == liveId && liveId.isNotEmpty),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _prettyId(String id) {
    if (id.length < 15) return id;
    return '${id.substring(6, 8)}/${id.substring(4, 6)}/${id.substring(0, 4)}  '
        '${id.substring(9, 11)}:${id.substring(11, 13)}';
  }

  Widget _badge(bool live) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: live ? _green.withOpacity(0.14) : _field,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      live ? 'Live' : 'Purana',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: live ? _green : _muted),
    ),
  );

  void _menu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: const Text('Update check karo'),
              subtitle: Text('Version $kAppVersion'),
              onTap: () async {
                Navigator.pop(ctx);
                final u = await UpdateService.check();
                if (!mounted) return;
                if (u == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Aap ke paas naya version hai.')),
                  );
                } else {
                  showDialog<void>(context: context, builder: (_) => _UpdateDialog(u));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Token hata do'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onSignOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Naya notice'),
        actions: [IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _menu)],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHistory,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              TextField(
                controller: _title,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                maxLength: 60,
                style: const TextStyle(fontSize: 17),
                decoration: _dec('Title (Urdu)'),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _body,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                maxLength: 300,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(fontSize: 17),
                decoration: _dec('Message (Urdu)'),
              ),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: _dec('Kab tak dikhana hai (optional)'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _expires == null ? 'Koi limit nahi' : _dateKey(_expires!),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_expires != null)
                        GestureDetector(
                          onTap: () => setState(() => _expires = null),
                          child: const Icon(Icons.close, size: 18, color: _muted),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _preview(),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _canSend ? () => _send(stop: false) : null,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Sab ko bhejo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'PICHLE NOTICE',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: _muted),
                    ),
                  ),
                  TextButton(
                    onPressed: _sending ? null : () => _send(stop: true),
                    child: const Text('Notice band karo'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _historyCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SentScreen extends StatelessWidget {
  final bool stopped;
  const _SentScreen({required this.stopped});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: _green.withOpacity(0.14), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: _green, size: 40),
              ),
              const SizedBox(height: 14),
              Text(stopped ? 'Notice band ho gaya' : 'Bhej diya',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                stopped
                    ? 'Ab dosto ko koi purana notice nahi dikhega.'
                    : 'Dosto ko agle 1 se 3 ghante me mil jayega.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text('Theek hai', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- update

class _UpdateDialog extends StatefulWidget {
  final AppUpdate update;
  const _UpdateDialog(this.update);

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  String? _error;

  Future<void> _go() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      var perm = await Permission.requestInstallPackages.status;
      if (!perm.isGranted) perm = await Permission.requestInstallPackages.request();
      final file = await UpdateService.download(widget.update, (p) {
        if (mounted) setState(() => _progress = p);
      });
      await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = 'Update nahi ho saka. Dobara try karo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _progress != null;
    return AlertDialog(
      title: const Text('Naya version aaya'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.update.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (widget.update.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.update.notes, style: const TextStyle(fontSize: 13, color: _muted)),
          ],
          if (busy) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(value: _progress),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Baad me')),
        FilledButton(onPressed: busy ? null : _go, child: const Text('Update karo')),
      ],
    );
  }
}
