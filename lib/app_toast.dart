import 'dart:async';
import 'package:flutter/material.dart';

/// Global key to access navigator context anywhere in the application.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

enum ToastType { success, error, warning, info }

class AppToast {
  /// Show a premium center modal success popup
  static Future<void> showSuccess(
    BuildContext? context, {
    required String title,
    required String message,
    Duration duration = const Duration(milliseconds: 1800),
    VoidCallback? onDismissed,
  }) {
    return show(
      context,
      type: ToastType.success,
      title: title,
      message: message,
      duration: duration,
      onDismissed: onDismissed,
    );
  }

  /// Show a premium center modal error popup
  static Future<void> showError(
    BuildContext? context, {
    required String title,
    required String message,
    Duration duration = const Duration(milliseconds: 2500),
    VoidCallback? onDismissed,
  }) {
    return show(
      context,
      type: ToastType.error,
      title: title,
      message: message,
      duration: duration,
      onDismissed: onDismissed,
    );
  }

  /// Show a premium center modal warning popup
  static Future<void> showWarning(
    BuildContext? context, {
    required String title,
    required String message,
    Duration duration = const Duration(milliseconds: 2200),
    VoidCallback? onDismissed,
  }) {
    return show(
      context,
      type: ToastType.warning,
      title: title,
      message: message,
      duration: duration,
      onDismissed: onDismissed,
    );
  }

  /// Show a premium center modal info popup
  static Future<void> showInfo(
    BuildContext? context, {
    required String title,
    required String message,
    Duration duration = const Duration(milliseconds: 1800),
    VoidCallback? onDismissed,
  }) {
    return show(
      context,
      type: ToastType.info,
      title: title,
      message: message,
      duration: duration,
      onDismissed: onDismissed,
    );
  }

  /// Core general dialog invocation
  static Future<void> show(
    BuildContext? context, {
    required ToastType type,
    required String title,
    required String message,
    Duration duration = const Duration(milliseconds: 1800),
    VoidCallback? onDismissed,
  }) async {
    final effectiveContext = (context != null && context.mounted)
        ? context
        : appNavigatorKey.currentContext;

    if (effectiveContext == null) return;

    try {
      await showGeneralDialog(
        context: effectiveContext,
        barrierDismissible: true,
        barrierLabel: 'DismissCenterToast',
        barrierColor: Colors.black.withValues(alpha: 0.40),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (ctx, anim1, anim2) {
          return CenterToastDialog(
            type: type,
            title: title,
            message: message,
            duration: duration,
          );
        },
        transitionBuilder: (ctx, anim1, anim2, child) {
          final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
          return ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(curve),
            child: FadeTransition(opacity: anim1, child: child),
          );
        },
      );
    } catch (_) {
      // Graceful fallback if navigation was transitioning
    }

    if (onDismissed != null) {
      onDismissed();
    }
  }
}

class CenterToastDialog extends StatefulWidget {
  final ToastType type;
  final String title;
  final String message;
  final Duration duration;

  const CenterToastDialog({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    required this.duration,
  });

  @override
  State<CenterToastDialog> createState() => _CenterToastDialogState();
}

class _CenterToastDialogState extends State<CenterToastDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..forward();

    _dismissTimer = Timer(widget.duration, () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  _ToastConfig _getConfig() {
    switch (widget.type) {
      case ToastType.success:
        return _ToastConfig(
          icon: Icons.check_circle_rounded,
          accentColor: const Color(0xFF10B981),
          lightBg: const Color(0xFFECFDF5),
          borderColor: const Color(0xFFA7F3D0),
          badgeTag: 'SUCCESS',
        );
      case ToastType.error:
        return _ToastConfig(
          icon: Icons.cancel_rounded,
          accentColor: const Color(0xFFEF4444),
          lightBg: const Color(0xFFFEF2F2),
          borderColor: const Color(0xFFFECACA),
          badgeTag: 'ERROR',
        );
      case ToastType.warning:
        return _ToastConfig(
          icon: Icons.warning_amber_rounded,
          accentColor: const Color(0xFFF59E0B),
          lightBg: const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFFDE68A),
          badgeTag: 'NOTICE',
        );
      case ToastType.info:
        return _ToastConfig(
          icon: Icons.info_outline_rounded,
          accentColor: const Color(0xFF2563EB),
          lightBg: const Color(0xFFEFF6FF),
          borderColor: const Color(0xFFBFDBFE),
          badgeTag: 'INFO',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _getConfig();
    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = (screenW * 0.88).clamp(300.0, 420.0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: cardW,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cfg.borderColor.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: cfg.accentColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Circular Icon Avatar
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: cfg.lightBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: cfg.borderColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: cfg.accentColor.withValues(alpha: 0.15),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            cfg.icon,
                            color: cfg.accentColor,
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Message Body
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF475569),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // OK / Dismiss Button
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cfg.accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Smooth Linear Timer Progress at the bottom
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, _) {
                    return LinearProgressIndicator(
                      value: 1.0 - _progressController.value,
                      minHeight: 4,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        cfg.accentColor.withValues(alpha: 0.6),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastConfig {
  final IconData icon;
  final Color accentColor;
  final Color lightBg;
  final Color borderColor;
  final String badgeTag;

  _ToastConfig({
    required this.icon,
    required this.accentColor,
    required this.lightBg,
    required this.borderColor,
    required this.badgeTag,
  });
}
