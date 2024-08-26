import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class StarryPainter extends CustomPainter {
  final List<Star> stars;
  final Animation<double> animation;

  StarryPainter(this.stars, this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (var star in stars) {
      Offset offset = Offset(
        size.width * star.x + cos(star.angle) * animation.value * star.orbitRadius,
        size.height * star.y + sin(star.angle) * animation.value * star.orbitRadius,
      );

      canvas.drawCircle(offset, star.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class Star {
  double x;
  double y;
  double size;
  double orbitRadius;
  double angle;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.orbitRadius,
    required this.angle,
  });
}

class StarryEffect extends StatefulWidget {
  @override
  _StarryEffectState createState() => _StarryEffectState();
}

class _StarryEffectState extends State<StarryEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Star> _stars;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..addListener(() {
      // print('Controller Status: ${_controller.status}, Value: ${_controller.value}');
      })
      // Start the animation initially
      ..forward();

    // When the animation completes, reverse it, and when that completes, forward it again
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controller.forward();
      }
    });

    _stars = List.generate(100, (index) {
      final random = Random();
      return Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 0.7 + 1,
        orbitRadius: random.nextDouble() * 50 + 50,
        angle: random.nextDouble() * 2 * pi,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: StarryPainter(_stars, _controller),
      size: Size.infinite,
    );
  }
}
