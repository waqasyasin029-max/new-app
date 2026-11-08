import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'home_shell.dart';
import 'setup_screen.dart';
import '../core/app_icons.dart';

/// First launch shows the intro pages; afterwards the app opens directly.
class OnboardingGate extends StatelessWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context) {
    final done = context.select<AppState, bool>((s) => s.onboardingDone);
    final setup = context.select<AppState, bool>((s) => s.setupDone);
    final fromSetup = context.read<AppState>().returnedFromSetup;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: !done
          ? OnboardingScreen(
              key: const ValueKey('onboarding'),
              startAtEnd: fromSetup,
            )
          : !setup
          ? const FirstSetupScreen(key: ValueKey('setup'))
          : const HomeShell(key: ValueKey('home')),
    );
  }
}

class _Page {
  final IconData icon;
  final String title;
  final String text;
  const _Page(this.icon, this.title, this.text);
}

const _pages = <_Page>[
  _Page(
    AppIcons.editNote,
    'Add expenses in seconds',
    'Tap the orange plus, write the amount, pick a category and the account you paid from.',
  ),
  _Page(
    AppIcons.factCheck,
    'Know what is left',
    'Every payment is taken from the right account, so you always see how much money is in your cash, wallets and banks.',
  ),
  _Page(
    AppIcons.wallet,
    'All your accounts in one place',
    'Cash, JazzCash, Easypaisa, SadaPay, banks and more. Track balances, withdraw, transfer and match your real balance.',
  ),
  _Page(
    AppIcons.insights,
    'Reports, budget and reminders',
    'See history and monthly reports, set a monthly budget, and get one friendly reminder every night. Light or dark, English or Urdu, fully offline.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  /// True when opened again from Settings: closing just goes back.
  final bool replay;

  /// Opens on the last page (when coming back from the first setup).
  final bool startAtEnd;
  const OnboardingScreen({
    super.key,
    this.replay = false,
    this.startAtEnd = false,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final _controller = PageController(
    initialPage: widget.startAtEnd ? _pages.length - 1 : 0,
  );
  late int _index = widget.startAtEnd ? _pages.length - 1 : 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _last => _index == _pages.length - 1;

  void _finish() {
    if (widget.replay) {
      Navigator.of(context).pop();
    } else {
      context.read<AppState>().finishOnboarding();
    }
  }

  void _next() {
    if (_last) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    // Back shows the previous page; only the first page leaves the screen.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _controller.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      },
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  _LangSwitch(
                    urdu: s.language == 'ur',
                    onChanged: (v) => s.setLanguage(v ? 'ur' : 'en'),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _last ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(
                      onPressed: _last ? null : _finish,
                      child: Text(
                        'Skip',
                        urdu: true,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _PageView(page: _pages[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? AppColors.primary : AppColors.line,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.gradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextButton(
                    onPressed: _next,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      _last ? 'Get started' : 'Next',
                      urdu: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                children: [
                  Text(
                    'Developed by',
                    verbatim: true,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Waqas Yasin',
                    verbatim: true,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Made in Pakistan',
                    verbatim: true,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _PageView extends StatelessWidget {
  final _Page page;
  const _PageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40EE6F2B),
                  blurRadius: 32,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Icon(page.icon, color: Colors.white, size: 84),
          ),
          const SizedBox(height: 44),
          Text(
            page.title,
            urdu: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            page.text,
            urdu: true,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// English  [switch]  اردو: one switch instead of two buttons.
class _LangSwitch extends StatelessWidget {
  final bool urdu;
  final ValueChanged<bool> onChanged;
  const _LangSwitch({required this.urdu, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    TextStyle st(bool on) => TextStyle(
      color: on ? AppColors.primary : AppColors.muted,
      fontWeight: on ? FontWeight.w800 : FontWeight.w600,
      fontSize: 14,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('English', verbatim: true, style: st(!urdu)),
        Switch(value: urdu, onChanged: onChanged),
        Text('اردو', verbatim: true, style: st(urdu)),
      ],
    );
  }
}
