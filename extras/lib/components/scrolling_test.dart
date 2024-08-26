import 'package:flutter/material.dart';

class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  ScrollingText({required this.text, required this.style});

  @override
  _ScrollingTextState createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 10),
    )..repeat(reverse: true); // Add reverse: true for back and forth animation
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect( // Ensures text stays within bounds
      child: Container(
        width: 150, // Fixed width of the scrolling container
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_animation.value * 100, 0), // Scroll within the fixed width
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: 1, // Ensure single-line scrolling
                overflow: TextOverflow.visible,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
