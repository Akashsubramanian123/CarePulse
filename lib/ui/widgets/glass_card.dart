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

class _GlassScaffoldScope extends InheritedWidget {
  const _GlassScaffoldScope({required super.child});

  @override
  bool updateShouldNotify(_GlassScaffoldScope oldWidget) => false;
}

class GlassScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
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
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
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
    final hasAncestor =
        context.dependOnInheritedWidgetOfExactType<_GlassScaffoldScope>() !=
            null;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glass = theme.extension<CarePulseGlass>()!;
    final padding = MediaQuery.paddingOf(context);

    // Resolve 56px top bar if title/topBar/appBar is provided
    Widget? resolvedTopBar = topBar;
    if (resolvedTopBar == null &&
        (title != null || titleWidget != null || appBar != null)) {
      Widget? resolvedLeading = leading;
      if (resolvedLeading == null &&
          appBar is AppBar &&
          (appBar as AppBar).leading != null) {
        resolvedLeading = (appBar as AppBar).leading;
      } else if (resolvedLeading == null && Navigator.canPop(context)) {
        resolvedLeading = SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: glass.textPrimary),
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
          ),
        );
      }

      Widget? resolvedTitle = titleWidget;
      if (resolvedTitle == null) {
        String titleStr = title ?? '';
        if (titleStr.isEmpty &&
            appBar is AppBar &&
            (appBar as AppBar).title is Text) {
          titleStr = ((appBar as AppBar).title as Text).data ?? '';
        }
        resolvedTitle = Text(
          titleStr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: glass.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        );
      }

      List<Widget> resolvedActions =
          actions ?? (appBar is AppBar ? (appBar as AppBar).actions ?? [] : []);

      resolvedTopBar = Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            if (resolvedLeading != null) resolvedLeading,
            if (resolvedLeading != null) const SizedBox(width: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: resolvedTitle,
              ),
            ),
            if (resolvedActions.isNotEmpty) ...[
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: resolvedActions,
              ),
            ],
          ],
        ),
      );
    }

    Widget content = body;
    // On tablets constrain page content to a max width of 640 centered
    content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: content,
      ),
    );

    // If already inside an ancestor GlassScaffold, do not duplicate background or top safe area
    if (hasAncestor) {
      if (resolvedTopBar != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: resolvedTopBar,
              ),
            ),
            Expanded(child: content),
          ],
        );
      }
      return content;
    }

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );

    return _GlassScaffoldScope(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
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
              Padding(
                padding: EdgeInsets.only(
                  left: safeAreaLeft ? padding.left : 0,
                  right: safeAreaRight ? padding.right : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (safeAreaTop) SizedBox(height: padding.top),
                    if (resolvedTopBar != null)
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: resolvedTopBar,
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              (safeAreaBottom && bottomNavigationBar == null)
                                  ? padding.bottom
                                  : 0,
                        ),
                        child: content,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
