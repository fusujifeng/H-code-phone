import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final Color? backgroundColor;
  final BoxBorder? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding,
    this.blur = 24,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: backgroundColor ??
                theme.colorScheme.surface.withAlpha(200),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ??
                Border.all(
                  color: theme.colorScheme.onSurface.withAlpha(15),
                ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 20,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
