import 'package:flutter/material.dart';

/// Modern, branded Date Picker that forces a clean, upright (portrait) layout
/// on desktop and web, preventing the awkward 2-column landscape split.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  String? confirmText,
  String? cancelText,
}) {
  const primaryBlue = Color(0xFF1E40AF);
  const navyDark = Color(0xFF0F172A);

  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText ?? 'SELECT DATE',
    confirmText: confirmText ?? 'APPLY',
    cancelText: cancelText ?? 'CANCEL',
    initialEntryMode: DatePickerEntryMode.calendarOnly,
    builder: (ctx, child) {
      final mediaQuery = MediaQuery.of(ctx);
      // Forcing size where height > width guarantees Orientation.portrait on desktop/web
      final portraitMediaQuery = mediaQuery.copyWith(
        size: const Size(360, 640),
      );

      return MediaQuery(
        data: portraitMediaQuery,
        child: Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: navyDark,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              headerBackgroundColor: primaryBlue,
              headerForegroundColor: Colors.white,
              headerHeadlineStyle: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
              headerHelpStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFDBEAFE),
                letterSpacing: 1.1,
              ),
              dayStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                if (states.contains(WidgetState.disabled)) return const Color(0xFFCBD5E1);
                return navyDark;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return primaryBlue;
                return Colors.transparent;
              }),
              todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return primaryBlue;
              }),
              todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return primaryBlue;
                return const Color(0xFFEFF6FF);
              }),
              todayBorder: const BorderSide(color: primaryBlue, width: 1.5),
              yearStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return navyDark;
              }),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return primaryBlue;
                return Colors.transparent;
              }),
              dividerColor: const Color(0xFFE2E8F0),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              confirmButtonStyle: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
          child: child!,
        ),
      );
    },
  );
}
