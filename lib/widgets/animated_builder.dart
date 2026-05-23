import 'package:flutter/material.dart';

class SimpleAnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const SimpleAnimatedBuilder({
    super.key,
    required Listenable animation,
    required this.builder,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
