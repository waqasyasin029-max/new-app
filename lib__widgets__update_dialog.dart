import 'package:flutter/material.dart' hide Text;
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/update_service.dart';
import '../core/app_icons.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      icon: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.gradient,
        ),
        child: const Icon(AppIcons.systemUpdate, size: 30, color: Colors.white),
      ),
      title: const Text('New update available', textAlign: TextAlign.center),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Version ${widget.info.build}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    notes,
                    verbatim: true,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    color: AppColors.primary,
                    backgroundColor: AppColors.line,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _progress > 0
                      ? 'Downloading ${(_progress * 100).toStringAsFixed(0)}%'
                      : 'Starting…',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 14),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Your expenses and settings are kept.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _busy ? null : _install,
                  child: const Text('Update'),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Later'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
