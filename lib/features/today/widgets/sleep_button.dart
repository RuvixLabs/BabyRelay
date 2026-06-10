import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/relay_theme.dart';
import '../../../core/design/relay_widgets.dart';

/// The one-tap promise: a single, huge, unmissable sleep toggle.
/// Asleep → a sage "wake" surface; awake → a deep dusk "sleep" surface, so
/// the button always shows the action it will take.
class SleepButton extends StatelessWidget {
  const SleepButton({
    super.key,
    required this.isAsleep,
    required this.onPressed,
    this.childName,
  });

  final bool isAsleep;
  final VoidCallback onPressed;
  final String? childName;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = childName ?? 'baby';

    final Gradient gradient;
    final Color glow;
    if (isAsleep) {
      final hi = isDark ? Color.lerp(c.sage, Colors.black, 0.25)! : c.sage;
      final lo = Color.lerp(hi, Colors.black, 0.22)!;
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [hi, lo],
      );
      glow = hi;
    } else {
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Color.lerp(c.nightHigh, Colors.black, 0.15)!,
                Color.lerp(c.nightLow, Colors.black, 0.15)!,
              ]
            : [c.nightHigh, c.nightLow],
      );
      glow = c.nightHigh;
    }

    final label = isAsleep ? 'Awake' : 'Asleep';
    final hint = isAsleep
        ? 'Tap when $name wakes up'
        : 'Tap when $name falls asleep';
    final icon = isAsleep ? Icons.wb_sunny_rounded : Icons.nightlight_round;

    return Semantics(
      button: true,
      label: 'Log $label',
      child: PressableScale(
        scale: 0.965,
        onTap: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: isDark ? 0.25 : 0.38),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: Tween(begin: 0.85, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  icon,
                  key: ValueKey(isAsleep),
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  Text(
                    hint,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
