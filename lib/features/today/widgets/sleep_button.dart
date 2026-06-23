import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/relay_theme.dart';
import '../../../core/design/relay_widgets.dart';

/// The one-tap promise: a single, huge, unmissable sleep control.
/// State and action are intentionally separate: the surrounding hero says what
/// is happening now, while this control always uses a verb.
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

    final Color background;
    final Color foreground;
    final Color border;
    final Color iconBackground;
    final String actionLabel;
    final String actionHint;
    final IconData actionIcon;
    final List<BoxShadow> shadows;

    if (isAsleep) {
      background = isDark ? c.duskSoft : c.surface;
      foreground = c.dusk;
      border = c.dusk.withValues(alpha: isDark ? 0.42 : 0.26);
      iconBackground = c.dusk.withValues(alpha: 0.12);
      actionLabel = 'End sleep';
      actionHint = 'Tap when $name wakes up';
      actionIcon = Icons.wb_twilight;
      shadows = [
        BoxShadow(
          color: c.ink.withValues(alpha: isDark ? 0.08 : 0.05),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];
    } else {
      background = c.clay;
      foreground = c.onClay;
      border = Color.lerp(c.clay, Colors.white, isDark ? 0.10 : 0.18)!;
      iconBackground = Colors.white.withValues(alpha: 0.14);
      actionLabel = 'Start sleep';
      actionHint = '$name is awake now · logs from now';
      actionIcon = Icons.nightlight_round;
      shadows = [
        BoxShadow(
          color: c.clay.withValues(alpha: isDark ? 0.22 : 0.30),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
    }

    return Semantics(
      excludeSemantics: true,
      button: true,
      label: actionLabel,
      hint: isAsleep
          ? 'Stops the timer and saves this sleep.'
          : 'Starts a live sleep timer.',
      child: PressableScale(
        scale: 0.965,
        onTap: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border, width: isAsleep ? 1.2 : 1),
            boxShadow: shadows,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(actionIcon, color: foreground, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      actionHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.78),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_rounded,
                color: foreground.withValues(alpha: 0.82),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
