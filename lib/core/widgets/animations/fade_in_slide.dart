import 'package:flutter/material.dart';
import 'dart:async';

class FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double verticalOffset;
  final Curve curve;
  final int index;

  const FadeInSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.verticalOffset = 30.0,
    this.curve = Curves.easeOutCubic,
    this.index = 0,
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.verticalOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    // Stagger based on index (cap at 10 items to prevent huge delays on long lists)
    final delay = Duration(milliseconds: (widget.index.clamp(0, 10)) * 50);
    _delayTimer = Timer(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: _slideAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
