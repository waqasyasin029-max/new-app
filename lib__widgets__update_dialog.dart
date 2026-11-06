import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/update_service.dart';

Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(info),
    );

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateDialog(this.info);

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _busy = false;
  double _progress = 0;
  String? _message;

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _progress = 0;
      _message = null;
    });
    try {
      var perm = await Permission.requestInstallPackages.status;
      if (!perm.isGranted)
        perm = await Permission.requestInstallPackages.request();
      if (!perm.isGranted) {
        setState(() {
          _busy = false;
          _message = 'Allow "Install unknown apps" for Kharcha Tracker, then tap Update again.';
        });
        return;
      }
      final file = await UpdateService.download(widget.info, (p) {
        if (mounted) setState(() => _progress = p);
      });
      final r = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = r.type == ResultType.done
            ? 'Installer opened. Tap Install there. If you cancelled, tap Update again.'
            : 'Could not open the installer: ${r.message}';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = 'Update failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.info.notes;
    return AlertDialog(
      title: const Text('New update available'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${widget.info.build}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (notes.isNotEmpty) ...[const SizedBox(height: 8), Text(notes)],
            if (_busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 4),
              Text(
                _progress > 0
                    ? 'Downloading ${(_progress * 100).toStringAsFixed(0)}%'
                    : 'Starting…',
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
            const SizedBox(height: 8),
            const Text(
              'Your expenses and settings are kept.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: _busy ? null : _install,
          child: const Text('Update'),
        ),
      ],
    );
  }
}
