import 'package:flutter/material.dart';

/// True when the operating system asks for reduced motion. All animations of
/// the app are disabled in that case.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// A short fade that is skipped when the system asks for reduced motion.
class FadePageRoute<T> extends PageRouteBuilder<T> {
  FadePageRoute({required this.builder, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) => builder(context),
        transitionsBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
              Widget child,
            ) {
              if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
                return child;
              }
              return FadeTransition(opacity: animation, child: child);
            },
      );

  final WidgetBuilder builder;
}

/// A short scale that is skipped when the system asks for reduced motion.
Widget subtleScale(
  BuildContext context,
  Widget child,
  Animation<double> animation,
) {
  if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
    return child;
  }
  return ScaleTransition(
    scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
    child: child,
  );
}
