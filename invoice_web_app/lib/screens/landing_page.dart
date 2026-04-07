import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../widgets/landing_hero_animation.dart';
import 'main_dashboard.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openDashboard({bool uploadImmediately = false}) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: MainDashboard(openUploadOnStart: uploadImmediately),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      body: AnimatedBuilder(
        animation: fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - fadeAnimation.value)),
              child: child,
            ),
          );
        },
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 900;
              final isVeryCompact = constraints.maxWidth < 460;
              final heroFontSize = isVeryCompact
                  ? 30.0
                  : isCompact
                  ? 38.0
                  : 52.0;
              final scannerWidth = isCompact
                  ? (constraints.maxWidth - 40).clamp(260.0, 360.0).toDouble()
                  : 440.0;

              return Stack(
                children: [
                  _buildAnimatedBackdrop(fadeAnimation.value),
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 20 : 40,
                      vertical: isCompact ? 20 : 28,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 16,
                      ),
                      child: Column(
                        children: [
                          _buildTopBar(isCompact),
                          const SizedBox(height: 28),
                          if (isCompact) ...[
                            _buildHeroCopy(heroFontSize),
                            const SizedBox(height: 24),
                            LandingHeroAnimation(
                              width: scannerWidth,
                              height: isVeryCompact ? 300 : 340,
                            ),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: _buildHeroCopy(heroFontSize)),
                                const SizedBox(width: 40),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: LandingHeroAnimation(
                                      width: scannerWidth,
                                      height: 360,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 32),
                          _buildRequirementStrip(isCompact),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBackdrop(double value) {
    final leftOffset = math.sin(value * math.pi * 2) * 18;
    final rightOffset = math.cos(value * math.pi * 2) * 14;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80 + leftOffset,
            left: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDDEBFF),
              ),
            ),
          ),
          Positioned(
            top: 120 - rightOffset,
            right: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE5FAF5),
              ),
            ),
          ),
          Positioned(
            left: 80,
            right: 80,
            top: 180,
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(160),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFFFFF).withAlpha(0),
                    const Color(0xFFE9F3FF).withAlpha(168),
                    const Color(0xFFFFFFFF).withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isCompact) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F6FEB), Color(0xFF35B6A8)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.receipt_long, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Invoice Intake Workspace',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              Text(
                'Validation, OCR, extraction, and invoice review',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
        if (!isCompact)
          TextButton.icon(
            onPressed: () => _openDashboard(),
            icon: const Icon(Icons.dashboard_customize_outlined),
            label: const Text('Open Dashboard'),
          ),
      ],
    );
  }

  Widget _buildHeroCopy(double heroFontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE9F3FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Smart invoice validation for PDF and image uploads',
            style: TextStyle(
              color: Color(0xFF1F5B9E),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Upload only valid invoices. Extract fields fast. Review everything in one place.',
          style: TextStyle(
            fontSize: heroFontSize,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: Color(0xFF10233F),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'The app validates whether a PDF or image is really an invoice, rejects invalid uploads, extracts structured fields and raw text, and shows every processed invoice in a clean responsive list.',
          style: TextStyle(fontSize: 16, height: 1.6, color: Colors.grey[700]),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => _openDashboard(uploadImmediately: true),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Start Scanning'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F6FEB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _openDashboard(),
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('View Invoice List'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _FeatureChip(
              icon: Icons.verified_user_outlined,
              label: 'Invoice validation',
            ),
            _FeatureChip(
              icon: Icons.auto_awesome_outlined,
              label: 'AI field extraction',
            ),
            _FeatureChip(
              icon: Icons.view_list_outlined,
              label: 'Responsive invoice list',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequirementStrip(bool isCompact) {
    final cards = const [
      _RequirementCard(
        step: '1',
        title: 'Upload PDF or Image',
        subtitle: 'Users can submit invoice PDFs, JPGs, JPEGs, or PNGs.',
      ),
      _RequirementCard(
        step: '2',
        title: 'Validate Invoice',
        subtitle:
            'The upload is checked first to confirm it is a valid invoice.',
      ),
      _RequirementCard(
        step: '3',
        title: 'Extract and Store',
        subtitle:
            'All detected fields and raw text are prepared for persistence.',
      ),
      _RequirementCard(
        step: '4',
        title: 'Show in List View',
        subtitle:
            'Processed invoices are visible in a responsive invoice list.',
      ),
    ];

    if (isCompact) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: card,
              ),
            )
            .toList(),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cards
          .map(
            (card) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: card,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD9E6F5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1F6FEB)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RequirementCard extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;

  const _RequirementCard({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E6F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 18,
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
              color: const Color(0xFFE8F2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: const TextStyle(
                color: Color(0xFF1F6FEB),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[700], height: 1.5),
          ),
        ],
      ),
    );
  }
}
