import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  double rotationSpeed;
  double size;
  Color color;
  int shape; // 0: rectangle, 1: circle, 2: star

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
    required this.shape,
  });
}

class ConfettiOverlayWidget extends StatefulWidget {
  final int particleCount;
  final Widget child;

  const ConfettiOverlayWidget({
    super.key,
    this.particleCount = 65,
    required this.child,
  });

  @override
  State<ConfettiOverlayWidget> createState() => _ConfettiOverlayWidgetState();
}

class _ConfettiOverlayWidgetState extends State<ConfettiOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final Random _random = Random();

  static const List<Color> _confettiColors = [
    Color(0xFFFFD700), // Gold
    Color(0xFF10B981), // Emerald
    Color(0xFF6366F1), // Indigo
    Color(0xFFEC4899), // Pink
    Color(0xFF3B82F6), // Blue
    Color(0xFFF97316), // Orange
    Color(0xFF8B5CF6), // Purple
    Color(0xFF06B6D4), // Cyan
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(_updateParticles);

    _initParticles();
    _controller.repeat();
  }

  void _initParticles() {
    _particles.clear();
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(
        ConfettiParticle(
          x: _random.nextDouble(),
          y: _random.nextDouble() * -0.6, // Start above the screen
          vx: (_random.nextDouble() - 0.5) * 0.003,
          vy: 0.002 + _random.nextDouble() * 0.004,
          rotation: _random.nextDouble() * 2 * pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.1,
          size: 6.0 + _random.nextDouble() * 8.0,
          color: _confettiColors[_random.nextInt(_confettiColors.length)],
          shape: _random.nextInt(3),
        ),
      );
    }
  }

  void _updateParticles() {
    for (final p in _particles) {
      p.x += p.vx + sin(p.y * 10) * 0.001;
      p.y += p.vy;
      p.rotation += p.rotationSpeed;

      // Loop back to top once fallen below screen
      if (p.y > 1.1) {
        p.y = -0.1 - _random.nextDouble() * 0.2;
        p.x = _random.nextDouble();
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ConfettiPainter(particles: _particles),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final px = p.x * size.width;
      final py = p.y * size.height;

      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation);

      if (p.shape == 0) {
        // Rectangle ribbon
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.5,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );
      } else if (p.shape == 1) {
        // Circle particle
        canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
      } else {
        // Star particle
        final path = Path();
        final halfSize = p.size * 0.5;
        path.moveTo(0, -halfSize);
        path.lineTo(halfSize * 0.3, -halfSize * 0.3);
        path.lineTo(halfSize, 0);
        path.lineTo(halfSize * 0.3, halfSize * 0.3);
        path.lineTo(0, halfSize);
        path.lineTo(-halfSize * 0.3, halfSize * 0.3);
        path.lineTo(-halfSize, 0);
        path.lineTo(-halfSize * 0.3, -halfSize * 0.3);
        path.close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
