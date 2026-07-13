import 'package:flutter/material.dart';

class PinchZoomWrapper extends StatefulWidget {
  final Widget child;

  const PinchZoomWrapper({super.key, required this.child});

  @override
  State<PinchZoomWrapper> createState() => _PinchZoomWrapperState();
}

class _PinchZoomWrapperState extends State<PinchZoomWrapper> with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250))
      ..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformationController,
      onInteractionEnd: _onInteractionEnd,
      clipBehavior: Clip.none,
      minScale: 1.0,
      maxScale: 4.0,
      child: widget.child,
    );
  }
}
