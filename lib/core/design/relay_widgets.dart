import 'package:flutter/material.dart';

import '../../domain/models/baby_profile.dart';
import '../../domain/models/caregiver.dart';
import 'relay_theme.dart';

/// Soft warm card — the base surface for everything in the app.
class RelayCard extends StatelessWidget {
  const RelayCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.gradient,
    this.onTap,
    this.borderColor,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? c.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.outline),
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return PressableScale(onTap: onTap, child: card);
  }
}

/// Scales slightly on press — the app's standard tap feedback for cards and
/// large controls (paired with InkWell ripples elsewhere).
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.975,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Uppercase tracking label used above sections.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Caregiver attribution dot/avatar with stable per-person color.
class CaregiverDot extends StatelessWidget {
  const CaregiverDot({
    super.key,
    required this.caregiver,
    this.size = 28,
    this.showRing = false,
  });

  final Caregiver caregiver;
  final double size;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final color = c.avatarColor(caregiver.colorIndex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: showRing ? color : color.withValues(alpha: 0.5),
          width: showRing ? 2 : 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        caregiver.initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// Child avatar — a filled, friendly circle with the child's initial and
/// stable accent color. A tiny moon badge appears while they're asleep so the
/// switcher reads at a glance.
class ChildAvatar extends StatelessWidget {
  const ChildAvatar({
    super.key,
    required this.child,
    this.size = 40,
    this.selected = false,
    this.asleep = false,
  });

  final BabyProfile child;
  final double size;
  final bool selected;
  final bool asleep;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final color = c.avatarColor(child.colorIndex);
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, c.ink, 0.25)!],
        ),
        shape: BoxShape.circle,
        border: selected ? Border.all(color: c.surfaceRaised, width: 2) : null,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        child.initial,
        style: TextStyle(
          fontSize: size * 0.44,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
    if (!asleep) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: size * 0.42,
            height: size * 0.42,
            decoration: BoxDecoration(
              color: c.nightHigh,
              shape: BoxShape.circle,
              border: Border.all(color: c.surface, width: 1.5),
            ),
            child: Icon(
              Icons.nightlight_round,
              size: size * 0.22,
              color: c.onNight,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small rounded chip for statuses ("Owner", "On trial", event kinds).
class RelayChip extends StatelessWidget {
  const RelayChip(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final chipColor = color ?? c.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: chipColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded tinted icon square used in settings rows and feature lists.
class IconSquare extends StatelessWidget {
  const IconSquare({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.55, color: color),
    );
  }
}

/// Compact square action used for the quick-log row. Large tap target,
/// softly tinted per action so the row doesn't read as four identical cards.
class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final accent = color ?? c.clay;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: PressableScale(
        onTap: onTap,
        scale: 0.94,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Color.lerp(c.surface, accent, isDark ? 0.10 : 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: accent),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color.lerp(accent, c.ink, 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A drifting field of soft stars for night-time hero surfaces. Deterministic
/// (seeded from the size) so it never flickers between builds.
class StarFieldPainter extends CustomPainter {
  const StarFieldPainter({required this.color, this.density = 26});

  final Color color;
  final int density;

  @override
  void paint(Canvas canvas, Size size) {
    var seed = 9176;
    int next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed;
    }

    for (var i = 0; i < density; i++) {
      final dx = (next() % 1000) / 1000 * size.width;
      final dy = (next() % 1000) / 1000 * size.height;
      final r = 0.6 + (next() % 100) / 100 * 1.3;
      final alpha = 0.25 + (next() % 100) / 100 * 0.5;
      canvas.drawCircle(
        Offset(dx, dy),
        r,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
    // One soft crescent moon, top right. The cut-out happens inside a saved
    // layer so the gradient behind the card shows through the crescent.
    final moonCenter = Offset(size.width - 38, 30);
    canvas.saveLayer(Rect.fromCircle(center: moonCenter, radius: 18), Paint());
    canvas.drawCircle(
      moonCenter,
      13,
      Paint()..color = color.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      moonCenter.translate(6, -4),
      11,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(StarFieldPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.density != density;
}

/// A low warm sun arc with rays for daytime hero surfaces.
class SunArcPainter extends CustomPainter {
  const SunArcPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width - 44, size.height * 0.62);
    canvas.drawCircle(
      center,
      18,
      Paint()..color = color.withValues(alpha: 0.55),
    );
    final ray = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final angle = -3.14159 + i * (3.14159 / 6);
      final from = center + Offset.fromDirection(angle, 24);
      final to = center + Offset.fromDirection(angle, 31);
      canvas.drawLine(from, to, ray);
    }
    // Horizon line.
    canvas.drawLine(
      Offset(size.width - 86, center.dy + 20),
      Offset(size.width - 4, center.dy + 20),
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(SunArcPainter oldDelegate) => oldDelegate.color != color;
}
