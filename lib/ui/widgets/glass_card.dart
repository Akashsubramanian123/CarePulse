import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                colors: [
                  tint!.withValues(alpha: 0.3),
                  tint!.withValues(alpha: 0.1)
                ],
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
      child: child,
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
  final Widget? child;

  const GradientBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final glassParams = Theme.of(context).extension<CarePulseGlass>()!;

    return Container(
      decoration: BoxDecoration(
        gradient: glassParams.backgroundGradient,
      ),
      child: Stack(
        fit: StackFit.expand,
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
          if (child != null) child!,
        ],
      ),
    );
  }
}

class GlassScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? topBar;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;
  final bool safeAreaTop;
  final bool safeAreaBottom;
  final bool safeAreaLeft;
  final bool safeAreaRight;
  final Key? gradientKey;

  const GlassScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.topBar,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.safeAreaLeft = true,
    this.safeAreaRight = true,
    this.gradientKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: appBar,
        bottomNavigationBar: bottomNavigationBar,
        bottomSheet: bottomSheet,
        floatingActionButton: floatingActionButton,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GradientBackground(
                key: gradientKey,
              ),
            ),
            SafeArea(
              top: safeAreaTop && (appBar == null),
              bottom: safeAreaBottom,
              left: safeAreaLeft,
              right: safeAreaRight,
              child: topBar != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        topBar!,
                        Expanded(child: body),
                      ],
                    )
                  : body,
            ),
          ],
        ),
      ),
    );
  }
}

class GlassTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? leading;
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const GlassTopBar({
    super.key,
    this.leading,
    required this.title,
    this.actions,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;

    Widget? leadWidget = leading;
    if (leadWidget == null && showBackButton) {
      leadWidget = SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: glass.textPrimary),
          tooltip: 'Back',
          onPressed: onBackPressed ?? () => Navigator.maybePop(context),
        ),
      );
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          if (leadWidget != null) ...[
            leadWidget,
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: glass.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
