import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';

/// Three-page welcome shown once, before PIN setup. Skippable; finishing
/// (or skipping) records the flag and moves on to PIN setup.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPage {
  const _OnboardingPage(this.icon, this.title, this.message);

  final IconData icon;
  final String title;
  final String message;
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      Icons.self_improvement_rounded,
      'Your private space to reflect',
      'A quiet journal for your days — thoughts, moods and moments, '
          'all in one place.',
    ),
    _OnboardingPage(
      Icons.lock_outline_rounded,
      'Locked with your password',
      'Everything stays on this device, encrypted. '
          'No accounts, no cloud, nobody else.',
    ),
    _OnboardingPage(
      Icons.photo_library_outlined,
      'Capture the day your way',
      'Photos, moods, streaks — and a year book of your entries '
          'whenever you want to look back.',
    ),
  ];

  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() =>
      ref.read(sessionProvider.notifier).completeOnboarding();

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: TextButton(
                      onPressed: _finish,
                      child: const Text('Skip'),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gutter + AppSpacing.xs,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: c.accentContainer,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusXl,
                                ),
                              ),
                              child: Icon(page.icon, size: 44, color: c.accent),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              page.title,
                              style: AppTextStyles.display
                                  .copyWith(color: c.textPrimary),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              page.message,
                              style: AppTextStyles.body.copyWith(
                                color: c.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pages.length; i++)
                      AnimatedContainer(
                        duration: AppMotion.fast,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _index ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _index ? c.accent : c.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: VaultButton(
                    label: isLast ? 'Set up my password' : 'Next',
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
