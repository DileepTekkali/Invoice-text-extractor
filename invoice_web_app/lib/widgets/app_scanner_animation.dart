import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppScannerAnimation extends StatefulWidget {
  final double width;
  final double height;
  final String title;
  final String subtitle;
  final Color accentColor;

  const AppScannerAnimation({
    super.key,
    this.width = 320,
    this.height = 240,
    this.title = 'Scanning invoice',
    this.subtitle = 'Reading text, tables, and totals',
    this.accentColor = const Color(0xFF1F6FEB),
  });

  @override
  State<AppScannerAnimation> createState() => _AppScannerAnimationState();
}

class _AppScannerAnimationState extends State<AppScannerAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = widget.width < 300 || widget.height < 220;
    final tagScale = isCompact ? 0.86 : 1.0;
    final sheetWidth = math.min(widget.width * 0.54, widget.width - 52);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final loop = _controller.value;
          final floatOffset = math.sin(loop * math.pi * 2) * 8;
          final pulse = (math.sin(loop * math.pi * 2) + 1) / 2;
          final sweep = loop < 0.5 ? loop * 2 : (1 - loop) * 2;
          final sheetHeight = widget.height * (isCompact ? 0.52 : 0.58);
          final scanTop = 24 + (sheetHeight - (isCompact ? 54 : 60)) * sweep;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: RadialGradient(
                      center: const Alignment(-0.35, -0.4),
                      radius: 1.05,
                      colors: [
                        const Color(0xFFE9F3FF),
                        const Color(0xFFF8FBFF),
                        const Color(0xFFFFFFFF),
                      ],
                    ),
                    border: Border.all(color: const Color(0xFFDCE8F8)),
                  ),
                ),
              ),
              Positioned(
                top: 18 + pulse * 6,
                right: 18,
                child: Transform.scale(
                  scale: tagScale,
                  alignment: Alignment.topRight,
                  child: _buildTag(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'PDF',
                    background: const Color(0xFFFFF1E9),
                    foreground: const Color(0xFFE66A2C),
                  ),
                ),
              ),
              Positioned(
                top: 56 - pulse * 6,
                right: 48,
                child: Transform.scale(
                  scale: tagScale,
                  alignment: Alignment.topRight,
                  child: _buildTag(
                    icon: Icons.image_outlined,
                    label: 'IMG',
                    background: const Color(0xFFEFFBF4),
                    foreground: const Color(0xFF1A8F5D),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                bottom: 18,
                child: Transform.scale(
                  scale: tagScale,
                  alignment: Alignment.bottomLeft,
                  child: _buildTag(
                    icon: Icons.auto_awesome_outlined,
                    label: isCompact ? 'AI' : 'AI Extract',
                    background: const Color(0xFFF4F1FF),
                    foreground: const Color(0xFF7252D6),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, floatOffset),
                    child: Container(
                      width: sheetWidth,
                      height: sheetHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFCADBF6)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1F6FEB).withAlpha(22),
                            blurRadius: 26,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                18,
                                18,
                                16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 96,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF1F6FEB,
                                      ).withAlpha(28),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  ...[0.82, 0.58, 0.74, 0.66, 0.9, 0.48].map(
                                    (widthFactor) => Padding(
                                      padding: const EdgeInsets.only(bottom: 9),
                                      child: Container(
                                        width: (sheetWidth - 36) * widthFactor,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFBFD3F4,
                                          ).withAlpha(84),
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFEAF2FF,
                                            ).withAlpha(204),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        width: 74,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: widget.accentColor.withAlpha(
                                            34,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 14,
                            right: 14,
                            top: scanTop,
                            child: Container(
                              height: 18,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                gradient: LinearGradient(
                                  colors: [
                                    widget.accentColor.withAlpha(0),
                                    widget.accentColor.withAlpha(92),
                                    const Color(0xFF5EEAD4).withAlpha(128),
                                    widget.accentColor.withAlpha(0),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.accentColor.withAlpha(38),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(left: 10, top: 10, child: _buildCorner()),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Transform.rotate(
                              angle: math.pi / 2,
                              child: _buildCorner(),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Transform.rotate(
                              angle: math.pi,
                              child: _buildCorner(),
                            ),
                          ),
                          Positioned(
                            left: 10,
                            bottom: 10,
                            child: Transform.rotate(
                              angle: -math.pi / 2,
                              child: _buildCorner(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: isCompact ? 14 : 18,
                child: Column(
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style:
                          (isCompact
                                  ? theme.textTheme.titleSmall
                                  : theme.textTheme.titleMedium)
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF12335B),
                              ),
                    ),
                    SizedBox(height: isCompact ? 2 : 4),
                    Text(
                      widget.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: isCompact ? 11 : null,
                        color: const Color(0xFF5B708C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withAlpha(38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner() {
    return SizedBox(
      width: 16,
      height: 16,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(width: 16, height: 2, color: widget.accentColor),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(width: 2, height: 16, color: widget.accentColor),
          ),
        ],
      ),
    );
  }
}
