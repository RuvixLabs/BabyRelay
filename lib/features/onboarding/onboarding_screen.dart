import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/design/relay_theme.dart';
import '../../data/family_repository.dart';
import '../../domain/models/baby_profile.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;

  // Draft answers.
  final _nameController = TextEditingController();
  final _caregiverController = TextEditingController();
  DateTime _dob = DateTime.now().subtract(const Duration(days: 150));
  int _wakeMinutes = 7 * 60;
  int _bedMinutes = 19 * 60;
  int _napsPerDay = 3;

  static const _stepCount = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AnalyticsService>().logEvent('onboarding_started');
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _caregiverController.dispose();
    super.dispose();
  }

  bool get _canAdvance {
    if (_step == 1) return _nameController.text.trim().isNotEmpty;
    return true;
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step == _stepCount - 1) {
      _finish();
      return;
    }
    context.read<AnalyticsService>().logEvent('onboarding_step_viewed', {
      'step': _step + 1,
    });
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_step == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final repo = context.read<FamilyRepository>();
    final analytics = context.read<AnalyticsService>();
    final router = GoRouter.of(context);
    await repo.completeOnboarding(
      baby: BabyProfile(
        nickname: _nameController.text.trim(),
        dob: _dob,
        wakeTimeMinutes: _wakeMinutes,
        bedtimeMinutes: _bedMinutes,
        napsPerDayEstimate: _napsPerDay,
      ),
      primaryCaregiverName: _caregiverController.text.trim(),
    );
    analytics.logEvent('onboarding_completed');
    analytics.logEvent('baby_profile_created');
    // Soft paywall after onboarding: show once, easily dismissed.
    router.go('/today');
    Future.microtask(() => router.push('/paywall'));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      onPressed: _back,
                      icon: const Icon(Icons.arrow_back),
                      padding: EdgeInsets.zero,
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: _ProgressDots(step: _step, count: _stepCount),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _WelcomeStep(),
                  _NameStep(
                    controller: _nameController,
                    onChanged: () => setState(() {}),
                  ),
                  _DobStep(
                    dob: _dob,
                    onChanged: (d) => setState(() => _dob = d),
                  ),
                  _ScheduleStep(
                    wakeMinutes: _wakeMinutes,
                    bedMinutes: _bedMinutes,
                    napsPerDay: _napsPerDay,
                    onWakeChanged: (v) => setState(() => _wakeMinutes = v),
                    onBedChanged: (v) => setState(() => _bedMinutes = v),
                    onNapsChanged: (v) => setState(() => _napsPerDay = v),
                  ),
                  _CaregiverStep(controller: _caregiverController),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: _canAdvance ? _next : null,
                    child: Text(
                      _step == 0
                          ? 'Get started'
                          : _step == _stepCount - 1
                          ? 'Create our timeline'
                          : 'Continue',
                    ),
                  ),
                  if (_step == _stepCount - 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'You can invite your partner or other caregivers right after.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: c.inkFaint,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == step ? 22 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i <= step ? c.clay : c.outline,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
      ],
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.headlineMedium),
          const SizedBox(height: 8),
          Text(subtitle, style: text.bodyMedium),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: c.clay.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.swap_horiz_rounded, size: 40, color: c.clayDeep),
          ),
          const SizedBox(height: 28),
          Text(
            'One baby.\nEvery caregiver.\nZero guesswork.',
            style: text.displayMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'BabyRelay keeps parents, partners, grandparents, and nannies on the same page — who did what, and what\'s next.',
            style: text.bodyLarge?.copyWith(color: c.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Who are we caring for?',
      subtitle: 'A nickname is fine — this stays private to your care team.',
      child: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        style: Theme.of(context).textTheme.titleLarge,
        decoration: const InputDecoration(
          hintText: 'e.g. Mae, Bubba, Little O',
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class _DobStep extends StatelessWidget {
  const _DobStep({required this.dob, required this.onChanged});

  final DateTime dob;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final months = DateTime.now().difference(dob).inDays ~/ 30;
    return _StepScaffold(
      title: 'When were they born?',
      subtitle:
          'Age drives the wake-window guidance — always shown with the why.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: dob,
                firstDate: DateTime.now().subtract(
                  const Duration(days: 365 * 3),
                ),
                lastDate: DateTime.now(),
                helpText: 'Date of birth',
              );
              if (picked != null) onChanged(picked);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.outline),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_outlined, color: c.clayDeep),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('MMMM d, y').format(dob),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Icon(Icons.edit_outlined, size: 18, color: c.inkFaint),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            months < 1
                ? 'A newborn — short, frequent naps are normal.'
                : 'About $months month${months == 1 ? '' : 's'} old.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({
    required this.wakeMinutes,
    required this.bedMinutes,
    required this.napsPerDay,
    required this.onWakeChanged,
    required this.onBedChanged,
    required this.onNapsChanged,
  });

  final int wakeMinutes;
  final int bedMinutes;
  final int napsPerDay;
  final ValueChanged<int> onWakeChanged;
  final ValueChanged<int> onBedChanged;
  final ValueChanged<int> onNapsChanged;

  String _label(int minutes) {
    final h12 = (minutes ~/ 60) % 12 == 0 ? 12 : (minutes ~/ 60) % 12;
    final suffix = minutes < 720 ? 'am' : 'pm';
    return '$h12:${(minutes % 60).toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _pick(
    BuildContext context,
    int current,
    String help,
    ValueChanged<int> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: help,
    );
    if (picked != null) onPicked(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    return _StepScaffold(
      title: 'A typical day',
      subtitle: 'Rough is fine — guidance adapts as you log real days.',
      child: Column(
        children: [
          _PickerRow(
            icon: Icons.wb_sunny_outlined,
            label: 'Usually wakes around',
            value: _label(wakeMinutes),
            onTap: () =>
                _pick(context, wakeMinutes, 'Typical wake time', onWakeChanged),
          ),
          const SizedBox(height: 10),
          _PickerRow(
            icon: Icons.bedtime_outlined,
            label: 'Bedtime is around',
            value: _label(bedMinutes),
            onTap: () =>
                _pick(context, bedMinutes, 'Target bedtime', onBedChanged),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text('Naps per day right now', style: text.bodyLarge),
              ),
              IconButton(
                onPressed: napsPerDay > 1
                    ? () => onNapsChanged(napsPerDay - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$napsPerDay', style: text.titleLarge),
              IconButton(
                onPressed: napsPerDay < 6
                    ? () => onNapsChanged(napsPerDay + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Not sure? Leave the guess — BabyRelay flags it if real days disagree.',
              style: text.bodyMedium?.copyWith(fontSize: 13, color: c.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.outline),
        ),
        child: Row(
          children: [
            Icon(icon, color: c.clayDeep, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: c.clayDeep),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaregiverStep extends StatelessWidget {
  const _CaregiverStep({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    return _StepScaffold(
      title: 'And you are?',
      subtitle:
          'Your name shows next to what you log, so everyone knows who did what.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            style: Theme.of(context).textTheme.titleLarge,
            decoration: const InputDecoration(hintText: 'e.g. Sara, Dad, Nana'),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.sageSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(Icons.group_add_outlined, color: c.sage),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Next: invite your partner or another caregiver from the Care team tab — that\'s where BabyRelay clicks.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
