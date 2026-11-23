import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'login_page.dart';

class SplashScreen extends StatefulWidget {
  final String? message;
  const SplashScreen({super.key, this.message});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  late AnimationController _spinnerController;
  late AnimationController _shimmerController;
  late AnimationController _fadeController;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    // 1. Overall fade-in entrance
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // 2. 12-dot circular loader continuous rotation
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat();

    // 3. Shimmer highlight along the progress bar
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // 4. Progress bar animation from 0.0 to 1.0 (1% to 100%)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    );

    _progressController.addListener(() {
      setState(() {});
    });

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 350), () {
          _navigateToLogin();
        });
      }
    });

    // Start progress
    _progressController.forward();
  }

  void _navigateToLogin() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _spinnerController.dispose();
    _shimmerController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  String _getStatusText(int percent) {
    if (percent < 20) {
      return 'Initializing Paint Shop system...';
    } else if (percent < 45) {
      return 'Loading product catalogue & shades...';
    } else if (percent < 70) {
      return 'Syncing store inventory & accounts...';
    } else if (percent < 92) {
      return 'Finalizing POS billing engine...';
    } else {
      return 'Ready! Launching Paint Shop...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progressAnimation.value * 100).toInt().clamp(1, 100);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Ambient soft background gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.1),
                  radius: 1.3,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFF8FAFC),
                    Color(0xFFEFF6FF),
                    Color(0xFFE2E8F0),
                  ],
                  stops: [0.0, 0.45, 0.8, 1.0],
                ),
              ),
            ),
          ),

          // Widescreen ambient corner wave painter
          Positioned.fill(child: CustomPaint(painter: _CornerWavesPainter())),

          // Central Hero Illustration and Live Telemetry
          Center(
            child: FadeTransition(
              opacity: _fadeController,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: math.min(size.width * 0.95, 760),
                  maxHeight: math.min(size.height * 0.96, 880),
                ),
                child: AspectRatio(
                  aspectRatio: 957 / 1024,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. Pristine Paint Shop Art with Logo, Cans & Splashes
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/splash_art.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildFallbackHero();
                            },
                          ),
                        ),
                      ),

                      // 2. Interactive Loading HUD (Anchored in the clean lower area)
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 0,
                        child: FractionallySizedBox(
                          widthFactor: 0.85,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final hudWidth = math.min(
                                constraints.maxWidth,
                                430.0,
                              );
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Rotating 12-dot spinner matching reference
                                  AnimatedBuilder(
                                    animation: _spinnerController,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        size: const Size(36, 36),
                                        painter: _DotSpinnerPainter(
                                          progress: _spinnerController.value,
                                          color: const Color(0xFF0284C7),
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 10),

                                  // "Loading..." text + dynamic percent
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Loading...',
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFBFDBFE),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$percent%',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1D4ED8),
                                            fontFeatures: [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  // Dynamic status message
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: Text(
                                      _getStatusText(percent),
                                      key: ValueKey<String>(
                                        _getStatusText(percent),
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF64748B),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Progress Bar (Rounded pill with gradient fill & shimmer)
                                  Container(
                                    width: hudWidth,
                                    height: 14,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(12),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, barBox) {
                                        final fillWidth =
                                            barBox.maxWidth *
                                            _progressAnimation.value.clamp(
                                              0.01,
                                              1.0,
                                            );
                                        return Stack(
                                          children: [
                                            // Progress fill gradient
                                            Container(
                                              width: fillWidth,
                                              height: double.infinity,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF0284C7),
                                                    Color(0xFF0066FF),
                                                    Color(0xFF2563EB),
                                                  ],
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFF0066FF,
                                                    ).withAlpha(90),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Moving gloss shimmer highlight
                                            if (fillWidth > 20)
                                              Positioned(
                                                left:
                                                    (fillWidth - 25) *
                                                    _shimmerController.value,
                                                top: 0,
                                                bottom: 0,
                                                width: 25,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.white.withAlpha(
                                                          0,
                                                        ),
                                                        Colors.white.withAlpha(
                                                          130,
                                                        ),
                                                        Colors.white.withAlpha(
                                                          0,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // Tagline: "Welcome to Paint Shop Management"
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Welcome to Paint Shop Management',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E3A8A),
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      CustomPaint(
                                        size: const Size(120, 4),
                                        painter: _UnderlineCurvePainter(),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Top Right: Skip Button
        ],
      ),
    );
  }

  Widget _buildFallbackHero() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.format_paint_rounded,
              size: 80,
              color: Color(0xFF0066FF),
            ),
            SizedBox(height: 16),
            Text(
              'Paint Shop',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0066FF),
              ),
            ),
            Text(
              'Management System',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 12-dot rotating circular spinner matching the uploaded reference image
class _DotSpinnerPainter extends CustomPainter {
  final double progress;
  final Color color;

  _DotSpinnerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3.5;
    const dotCount = 12;
    final dotRadius = size.width / 13;

    for (int i = 0; i < dotCount; i++) {
      final angle = (i * 2 * math.pi / dotCount) - (math.pi / 2);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      // Trailing fade clockwise
      double diff = (i / dotCount - progress) % 1.0;
      if (diff < 0) diff += 1.0;
      final opacity = (1.0 - diff).clamp(0.12, 1.0);

      final paint = Paint()
        ..color = color.withAlpha((opacity * 255).round())
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotSpinnerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// Subtle decorative curve underneath "Welcome to Paint Shop Management"
class _UnderlineCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          Color(0xFF38BDF8),
          Color(0xFF0284C7),
          Colors.transparent,
        ],
        stops: [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height + 2,
        size.width,
        size.height * 0.5,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Corner waves for widescreen desktop browsers
class _CornerWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top-Left Wave Ribbon
    final tlPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.22, 0)
      ..cubicTo(
        size.width * 0.15,
        size.height * 0.10,
        size.width * 0.05,
        size.height * 0.16,
        0,
        size.height * 0.25,
      )
      ..close();

    final tlPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0284C7), Color(0xFF0066FF), Color(0xFF02479E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width * 0.25, size.height * 0.25))
      ..style = PaintingStyle.fill;

    canvas.drawPath(tlPath, tlPaint);

    // Bottom-Right Wave Ribbon
    final brPath = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width * 0.78, size.height)
      ..cubicTo(
        size.width * 0.85,
        size.height * 0.90,
        size.width * 0.95,
        size.height * 0.84,
        size.width,
        size.height * 0.75,
      )
      ..close();

    final brPaint = Paint()
      ..shader =
          const LinearGradient(
            colors: [Color(0xFF0284C7), Color(0xFF0066FF), Color(0xFF02479E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(
            Rect.fromLTWH(
              size.width * 0.75,
              size.height * 0.75,
              size.width * 0.25,
              size.height * 0.25,
            ),
          )
      ..style = PaintingStyle.fill;

    canvas.drawPath(brPath, brPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
