import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/i18n.dart' show L10n;
import 'core/theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/add_expense_flow.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'widgets/lock_gate.dart';
import 'widgets/update_dialog.dart';
import 'state/app_state.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void openRecordScreen() {
  final ctx = navigatorKey.currentContext;
  if (ctx != null && ctx.mounted) AddExpenseFlow.start(ctx);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await NotificationService.init();
  } catch (_) {}
  NotificationService.onTap = (payload) {
    if (payload == NotificationService.payloadRecord) openRecordScreen();
  };

  final state = AppState();
  await state.init();

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const KharchaApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Re-schedule on every launch so the daily reminder always stays correct.
    await state.applyReminder();
    try {
      // App was cold-started by tapping the reminder notification.
      final payload = await NotificationService.launchPayload();
      if (payload == NotificationService.payloadRecord) openRecordScreen();
    } catch (_) {}
    _checkForUpdateOnLaunch();
  });
}

/// Quietly asks GitHub for a newer release; shows the update dialog if there is one.
Future<void> _checkForUpdateOnLaunch() async {
  final r = await UpdateService.check();
  final ctx = navigatorKey.currentState?.overlay?.context;
  if (r.update != null && ctx != null && ctx.mounted) {
    showUpdateDialog(ctx, r.update!);
  }
}

class KharchaApp extends StatefulWidget {
  const KharchaApp({super.key});

  @override
  State<KharchaApp> createState() => _KharchaAppState();
}

class _KharchaAppState extends State<KharchaApp> with WidgetsBindingObserver {
  /// "dark-urdu" combination currently painted; a change repaints everything.
  String? _look;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Phone switched between light and dark while the app follows the system.
  @override
  void didChangePlatformBrightness() {
    if (mounted) setState(() {});
  }

  /// Marks every widget dirty so colours and text that are read from globals
  /// (and const widgets) are rebuilt after a theme or language change.
  void _rebuildAll() {
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    state.applyLook();
    final look = '${AppColors.dark}-${L10n.urdu}';
    if (_look != look) {
      final first = _look == null;
      _look = look;
      if (!first) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
      }
    }
    final dark = AppColors.dark;
    return MaterialApp(
      title: 'Kharcha Tracker',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: buildAppTheme(),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
        ),
        child: Directionality(
          textDirection: L10n.urdu ? TextDirection.rtl : TextDirection.ltr,
          child: AppBackground(
            child: LockGate(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
      home: const OnboardingGate(),
    );
  }
}
