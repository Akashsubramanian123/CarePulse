import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

const bool kReduceGlassEffects = false;

class GlassCard extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? tint;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glassParams = theme.extension<CarePulseGlass>()!;
    
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: tint != null
            ? LinearGradient(
                colors: [tint!.withOpacity(0.3), tint!.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : glassParams.glassFillGradient,
        border: Border.all(color: glassParams.glassBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: glassParams.shadowColor,
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          // Top inner highlight
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [glassParams.innerHighlightColor, Colors.transparent],
                  stops: const [0.0, 0.5],
                ),
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    if (kReduceGlassEffects) {
      return content;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: content,
      ),
    );
  }
}

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final glassParams = Theme.of(context).extension<CarePulseGlass>()!;
    
    return Container(
      decoration: BoxDecoration(
        gradient: glassParams.backgroundGradient,
      ),
      child: Stack(
        children: [
          // Top-left glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glassParams.glowTopLeftColor,
                boxShadow: [
                  BoxShadow(
                    color: glassParams.glowTopLeftColor,
                    blurRadius: 200,
                    spreadRadius: 50,
                  )
                ],
              ),
            ),
          ),
          // Bottom-right glow
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glassParams.glowBottomRightColor,
                boxShadow: [
                  BoxShadow(
                    color: glassParams.glowBottomRightColor,
                    blurRadius: 200,
                    spreadRadius: 50,
                  )
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
