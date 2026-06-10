import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/relay_theme.dart';

/// The one-tap promise: a single, huge, unmissable sleep toggle.
class SleepButton extends StatelessWidget {
  const SleepButton({
    super.key,
    required this.isAsleep,
    required this.onPressed,
  });

  final bool isAsleep;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final base = isAsleep ? c.sage : c.dusk;
    // Dim the action color at night so the 2am screen stays gentle.
    final color = Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(base, Colors.black, 0.35)!
        : base;
    final label = isAsleep ? 'Awake' : 'Asleep';
    final hint = isAsleep
        ? 'Tap when baby wakes up'
        : 'Tap when baby falls asleep';
    final icon = isAsleep ? Icons.wb_sunny_rounded : Icons.nightlight_round;

    return Semantics(
      button: true,
      label: 'Log $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onPressed();
          },
          borderRadius: BorderRadius.circular(26),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 30),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
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
      ),
    );
  }
}
