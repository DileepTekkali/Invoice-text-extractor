import 'dart:math' as math;

import 'package:flutter/material.dart';

class LandingHeroAnimation extends StatefulWidget {
  final double width;
  final double height;

  const LandingHeroAnimation({super.key, this.width = 440, this.height = 340});

  @override
  State<LandingHeroAnimation> createState() => _LandingHeroAnimationState();
}

class _LandingHeroAnimationState extends State<LandingHeroAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = math.min(widget.width, widget.height);
    final ringSize = shortestSide * 0.74;
    final coreSize = shortestSide * 0.48;
    final isCompact = widget.width < 330;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final loop = _controller.value;
          final pulse = (math.sin(loop * math.pi * 2) + 1) / 2;
          final floatOffset = math.sin(loop * math.pi * 2) * 10;
          final orbitRotation = loop * math.pi * 2;
          final cardOffset = math.cos(loop * math.pi * 2) * 8;

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFDFEFF),
                        Color(0xFFF0F6FF),
                        Color(0xFFEFFAF7),
                      ],
                    ),
                    border: Border.all(color: const Color(0xFFD8E6F7)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1F6FEB).withAlpha(18),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -28,
                left: -18,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFDCEBFF), Color(0x00DCEBFF)],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -20,
                bottom: -30,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFDFF7EE), Color(0x00DFF7EE)],
                    ),
                  ),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, floatOffset),
                  child: SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.rotate(
                          angle: orbitRotation * 0.35,
                          child: Container(
                            width: ringSize,
                            height: ringSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFBED6F5),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                        Transform.rotate(
                          angle: -orbitRotation * 0.5,
                          child: SizedBox(
                            width: ringSize,
                            height: ringSize,
                            child: Stack(
                              children: [
                                Align(
                                  alignment: const Alignment(0, -1),
                                  child: _buildOrbitNode(
                                    color: const Color(0xFF1F6FEB),
                                    icon: Icons.document_scanner_outlined,
                                  ),
                                ),
                                Align(
                                  alignment: const Alignment(0.92, 0.12),
                                  child: _buildOrbitNode(
                                    color: const Color(0xFF35B6A8),
                                    icon: Icons.verified_outlined,
                                  ),
                                ),
                                Align(
                                  alignment: const Alignment(-0.86, 0.52),
                                  child: _buildOrbitNode(
                                    color: const Color(0xFFE36B2C),
                                    icon: Icons.auto_awesome_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: coreSize,
                          height: coreSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1F6FEB), Color(0xFF35B6A8)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1F6FEB).withAlpha(42),
                                blurRadius: 26,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isCompact ? 20 : 24),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(235),
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 88,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF1F6FEB,
                                        ).withAlpha(28),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Expanded(
                                      child: Icon(
                                        Icons.receipt_long_rounded,
                                        size: 68,
                                        color: Color(0xFF173B67),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD9E7FB),
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 36,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF35B6A8,
                                            ).withAlpha(84),
                                            borderRadius: BorderRadius.circular(
                                              99,
                                            ),
                                          ),
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
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 28 + cardOffset,
                left: 24,
                child: _buildFeatureCard(
                  title: 'Instant Validation',
                  subtitle: 'Reject non-invoices first',
                  accent: const Color(0xFF1F6FEB),
                  icon: Icons.rule_folder_outlined,
                ),
              ),
              Positioned(
                right: 18,
                top: widget.height * 0.34 - pulse * 10,
                child: _buildFeatureCard(
                  title: 'AI Extraction',
                  subtitle: 'Totals, parties, items',
                  accent: const Color(0xFF35B6A8),
                  icon: Icons.auto_awesome,
                ),
              ),
              Positioned(
                left: widget.width * 0.24,
                bottom: 22 - cardOffset,
                child: _buildMetricPill(
                  label: 'Responsive',
                  value: 'Web Ready',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrbitNode({required Color color, required IconData icon}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color.withAlpha(36)),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(232),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withAlpha(28)),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF11253F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.45,
              color: Color(0xFF5A718C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF10233F),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10233F).withAlpha(32),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: Colors.white24),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
