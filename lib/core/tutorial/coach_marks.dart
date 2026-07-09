import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/relay_theme.dart';
import '../design/relay_widgets.dart';

enum CoachMarkResult { completed, skipped }

class CoachMarkStep {
  const CoachMarkStep({
    required this.targetKey,
    required this.title,
    required this.body,
    required this.icon,
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
  final IconData icon;
}

Future<CoachMarkResult> showCoachMarks({
  required BuildContext context,
  required List<CoachMarkStep> steps,
}) async {
  if (steps.isEmpty) return CoachMarkResult.completed;
  final result = await showGeneralDialog<CoachMarkResult>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    pageBuilder: (context, animation, secondaryAnimation) =>
        _CoachMarkOverlay(steps: steps),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 160),
    useRootNavigator: true,
  );
  return result ?? CoachMarkResult.skipped;
}

class _CoachMarkOverlay extends StatefulWidget {
  const _CoachMarkOverlay({required this.steps});

  final List<CoachMarkStep> steps;

  @override
  State<_CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<_CoachMarkOverlay> {
  int _index = 0;

  CoachMarkStep get _step => widget.steps[_index];

  Rect? _targetRect() {
    final context = _step.targetKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    final target = _targetRect();

    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fallback = Rect.fromCenter(
              center: Offset(
                constraints.maxWidth / 2,
                constraints.maxHeight / 2,
              ),
              width: math.min(220, constraints.maxWidth - 48),
              height: 92,
            );
            final rect = target ?? fallback;
            final cardWidth = math.min(340.0, constraints.maxWidth - 40);
            final left = (rect.center.dx - cardWidth / 2)
                .clamp(20.0, constraints.maxWidth - cardWidth - 20.0)
                .toDouble();
            final showBelow = rect.center.dy < constraints.maxHeight * 0.55;
            final lowestTop = math.max(24.0, constraints.maxHeight - 360);
            final top = showBelow
                ? math.min(rect.bottom + 18, lowestTop)
                : math.max(24.0, rect.top - 246);
            final maxCardHeight = math.max(
              180.0,
              constraints.maxHeight - top - 20,
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SpotlightPainter(rect: rect, colors: c),
                  ),
                ),
                Positioned(
                  left: left,
                  top: top,
                  width: cardWidth,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxCardHeight),
                    child: SingleChildScrollView(
                      child: RelayCard(
                        radius: 22,
                        padding: const EdgeInsets.all(18),
                        color: c.surfaceRaised,
                        borderColor: c.outline,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                IconSquare(icon: _step.icon, color: c.clayDeep),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _step.title,
                                    style: text.titleLarge,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(_step.body, style: text.bodyMedium),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _ProgressDots(
                                  count: widget.steps.length,
                                  selected: _index,
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(0, 42),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      onPressed: () => Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pop(CoachMarkResult.skipped),
                                      child: const Text('Skip tour'),
                                    ),
                                    const SizedBox(width: 6),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(82, 42),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                      ),
                                      onPressed: () {
                                        if (_index == widget.steps.length - 1) {
                                          Navigator.of(
                                            context,
                                            rootNavigator: true,
                                          ).pop(CoachMarkResult.completed);
                                          return;
                                        }
                                        setState(() => _index++);
                                      },
                                      child: Text(
                                        _index == widget.steps.length - 1
                                            ? 'Done'
                                            : 'Next',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.selected});

  final int count;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: i == selected ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == selected ? c.clayDeep : c.outline,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          if (i < count - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.rect, required this.colors});

  final Rect rect;
  final RelayColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final spotlight = RRect.fromRectAndRadius(
      rect.inflate(8),
      const Radius.circular(28),
    );

    canvas.saveLayer(screen, Paint());
    canvas.drawRect(
      screen,
      Paint()..color = colors.ink.withValues(alpha: 0.58),
    );
    canvas.drawRRect(spotlight, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    canvas.drawRRect(
      spotlight,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors.sun.withValues(alpha: 0.92),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return rect != oldDelegate.rect || colors != oldDelegate.colors;
  }
}
