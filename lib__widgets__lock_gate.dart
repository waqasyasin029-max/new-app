import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../core/app_icons.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../state/app_state.dart';

/// Shared helper for the phone's own lock (fingerprint, face, PIN or pattern).
class DeviceLock {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// True when the phone has some screen lock set up.
  static Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Shows the phone's own unlock sheet. Returns [DeviceLockResult].
  static Future<DeviceLockResult> ask(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      return ok ? DeviceLockResult.ok : DeviceLockResult.failed;
    } on PlatformException catch (e) {
      const missing = ['NotAvailable', 'NotEnrolled', 'PasscodeNotSet'];
      return missing.contains(e.code)
          ? DeviceLockResult.unavailable
          : DeviceLockResult.failed;
    } catch (_) {
      return DeviceLockResult.failed;
    }
  }
}

enum DeviceLockResult { ok, failed, unavailable }

/// Covers the whole app with a lock screen while it is locked: when the app
/// starts, and when it comes back after being away for more than 30 seconds.
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  static const _grace = Duration(seconds: 30);
  late bool _locked;
  bool _asking = false;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = context.read<AppState>().appLock;
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_asking) return; // the unlock sheet itself pauses the app for a moment
    if (state == AppLifecycleState.paused) {
      _leftAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null &&
          context.read<AppState>().appLock &&
          DateTime.now().difference(left) > _grace) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_asking) return;
    _asking = true;
    final r = await DeviceLock.ask('Unlock Kharcha Tracker');
    _asking = false;
    if (!mounted) return;
    if (r == DeviceLockResult.ok) {
      setState(() => _locked = false);
    } else if (r == DeviceLockResult.unavailable) {
      // The phone has no screen lock any more: do not lock the owner out.
      await context.read<AppState>().setAppLock(false);
      if (mounted) setState(() => _locked = false);
    } else {
      setState(() {}); // stay locked; the Unlock button tries again
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reading AppState here keeps the gate in step with the Settings switch.
    context.watch<AppState>();
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Material(
                color: AppColors.bgBottom,
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.gradient,
                            ),
                            child: const Icon(
                              AppIcons.lock,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Kharcha Tracker',
                            verbatim: true,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Locked',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 28),
                          FilledButton(
                            onPressed: _unlock,
                            child: const Text('Unlock'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
