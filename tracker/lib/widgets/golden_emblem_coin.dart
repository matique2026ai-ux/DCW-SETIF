import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An ultra-premium, floating & 3D rotating gold coin emblem for the Directorate of Commerce - Setif.
///
/// Features:
/// - Smooth 3D Y-axis coin spin / flip every 8 seconds (very lightweight, 0% idle CPU)
/// - Interactive manual 3D flip on tap
/// - Pure transparent circular coin
/// - Subtle natural floating / levitation (optional)
/// - Warm ambient gold glow aura and realistic floating drop shadow (optional)
/// - Polished metallic specular sheen sweep
class GoldenEmblemCoin extends StatefulWidget {
  final double size;
  final bool showOuterGlow;
  final bool animateGleam;
  final bool enableFloating;
  final bool enablePeriodicFlip;

  const GoldenEmblemCoin({
    super.key,
    this.size = 130.0,
    this.showOuterGlow = true,
    this.animateGleam = true,
    this.enableFloating = true,
    this.enablePeriodicFlip = true,
  });

  @override
  State<GoldenEmblemCoin> createState() => _GoldenEmblemCoinState();
}

class _GoldenEmblemCoinState extends State<GoldenEmblemCoin>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  Timer? _periodicTimer;

  late AnimationController _sheenController;
  late Animation<double> _sheenProgress;

  late AnimationController _floatController;
  late Animation<double> _floatOffset;
  late Animation<double> _shadowScale;

  @override
  void initState() {
    super.initState();

    // 1. 3D Coin Flip Animation (Smooth 360-degree Y-axis spin in 1.2s)
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _flipController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _flipController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _flipController.reset();
      }
    });

    if (widget.enablePeriodicFlip) {
      // Trigger a periodic 3D coin spin every 8 seconds without overloading the device
      _periodicTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        if (mounted && !_flipController.isAnimating) {
          _flipController.forward(from: 0.0);
        }
      });
    }

    // 2. Sheen Animation: sweeps across every 3.5 seconds
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _sheenProgress = Tween<double>(begin: -0.8, end: 1.8).animate(
      CurvedAnimation(
        parent: _sheenController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeInOutSine),
      ),
    );

    // 3. Floating Levitation Animation: smooth gentle breathing motion
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _floatOffset = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutSine,
      ),
    );

    _shadowScale = Tween<double>(begin: 0.90, end: 1.10).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutSine,
      ),
    );

    if (widget.animateGleam) {
      _sheenController.repeat();
    }
    if (widget.enableFloating) {
      _floatController.repeat(reverse: true);
    }
  }

  void _triggerManualFlip() {
    if (!_flipController.isAnimating) {
      _flipController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant GoldenEmblemCoin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateGleam != oldWidget.animateGleam) {
      if (widget.animateGleam) {
        _sheenController.repeat();
      } else {
        _sheenController.stop();
      }
    }
    if (widget.enableFloating != oldWidget.enableFloating) {
      if (widget.enableFloating) {
        _floatController.repeat(reverse: true);
      } else {
        _floatController.stop();
      }
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _flipController.dispose();
    _sheenController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return GestureDetector(
      onTap: _triggerManualFlip,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_floatController, _flipAnimation]),
          builder: (context, child) {
            final dy = widget.enableFloating ? _floatOffset.value : 0.0;
            final shadowFactor = widget.enableFloating ? _shadowScale.value : 1.0;
            final angle = _flipAnimation.value * 2 * math.pi;

            return SizedBox(
              width: widget.enableFloating ? s + 24 : s,
              height: widget.enableFloating ? s + 32 : s,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 1. Soft Floor Shadow beneath the floating coin (if floating enabled)
                  if (widget.showOuterGlow && widget.enableFloating)
                    Positioned(
                      bottom: 6 - dy * 0.4,
                      child: Container(
                        width: s * 0.65 * shadowFactor,
                        height: 14 * shadowFactor,
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(Radius.elliptical(s * 0.35, 7)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45 / shadowFactor),
                              blurRadius: 16 * shadowFactor,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.20 / shadowFactor),
                              blurRadius: 18 * shadowFactor,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 2. The 3D Rotating & Floating Gold Coin
                  Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // 3D Perspective Depth
                        ..rotateY(angle),
                      child: SizedBox(
                        width: s,
                        height: s,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Soft Ambient Gold Aura behind coin
                            if (widget.showOuterGlow)
                              Container(
                                width: s * 0.92,
                                height: s * 0.92,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFD700).withValues(alpha: 0.30),
                                      blurRadius: s * 0.22,
                                      spreadRadius: 2,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFFB8860B).withValues(alpha: 0.25),
                                      blurRadius: s * 0.12,
                                    ),
                                  ],
                                ),
                              ),

                            // Pristine Circular Coin Image
                            ClipOval(
                              child: Image.asset(
                                'assets/images/gold_coin_floating.png',
                                width: s,
                                height: s,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    'assets/images/gold_emblem.jpg',
                                    width: s,
                                    height: s,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),

                            // Realistic Metallic Specular Sheen Sweep
                            if (widget.animateGleam)
                              ClipOval(
                                child: SizedBox(
                                  width: s,
                                  height: s,
                                  child: AnimatedBuilder(
                                    animation: _sheenProgress,
                                    builder: (context, child) {
                                      final p = _sheenProgress.value;
                                      return CustomPaint(
                                        painter: _RealisticMetallicSheenPainter(progress: p),
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Renders a vivid, natural metallic specular sheen sweep that replicates
/// light glinting smoothly across a polished floating gold coin.
class _RealisticMetallicSheenPainter extends CustomPainter {
  final double progress;

  _RealisticMetallicSheenPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < -0.5 || progress > 1.5) return;

    final w = size.width;
    final h = size.height;
    final diag = w * 1.5;

    canvas.save();
    // Rotate canvas by -35 degrees to cast a realistic diagonal reflection angle
    canvas.translate(w / 2, h / 2);
    canvas.rotate(-0.61); // ~ -35 degrees
    canvas.translate(-w / 2, -h / 2);

    // Calculate light beam position along the diagonal
    final currentX = progress * diag - (diag - w) / 2;
    final beamWidth = w * 0.38;

    final sheenRect = Rect.fromLTWH(
      currentX - beamWidth / 2,
      -h * 0.5,
      beamWidth,
      h * 2.0,
    );

    // Realistic multi-tier metallic reflection gradient
    final sheenShader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.white.withValues(alpha: 0.0),
        const Color(0xFFFFF7D6).withValues(alpha: 0.15),
        const Color(0xFFFFFBE8).withValues(alpha: 0.40),
        Colors.white.withValues(alpha: 0.80),
        const Color(0xFFFFFBE8).withValues(alpha: 0.40),
        const Color(0xFFFFF7D6).withValues(alpha: 0.15),
        Colors.white.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.20, 0.40, 0.50, 0.60, 0.80, 1.0],
    ).createShader(sheenRect);

    final sheenPaint = Paint()
      ..shader = sheenShader
      ..blendMode = BlendMode.screen;

    canvas.drawRect(sheenRect, sheenPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RealisticMetallicSheenPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
