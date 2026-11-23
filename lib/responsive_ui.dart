import 'package:flutter/material.dart';

/// Responsive grid for summary/KPI cards across desktop, tablet, and 320px+ phones.
/// Uses MediaQuery.sizeOf instead of LayoutBuilder so live viewport resizes
/// never trigger Flutter performLayout element/dependent assertions.
class ResponsiveSummaryGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final int desktopBreakpoint;
  final int tabletBreakpoint;

  const ResponsiveSummaryGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.desktopBreakpoint = 1150,
    this.tabletBreakpoint = 700,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (screenWidth >= desktopBreakpoint) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            Expanded(child: children[i]),
          ],
        ],
      );
    }

    if (screenWidth >= tabletBreakpoint) {
      final rows = <Widget>[];
      for (int i = 0; i < children.length; i += 2) {
        final hasSecond = i + 1 < children.length;
        rows.add(
          Padding(
            padding: EdgeInsets.only(
              bottom: i + 2 < children.length ? spacing : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[i]),
                SizedBox(width: spacing),
                Expanded(
                  child: hasSecond ? children[i + 1] : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    }

    // Compact phones (< 480px, including 320px): crisp single column cards
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing > 10 ? 10 : spacing),
          children[i],
        ],
      ],
    );
  }
}

/// A sleek gradient statistics card used consistently across the dashboard and modules.
class GradientSummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final String percentage;
  final IconData icon;
  final List<Color> colors;
  final bool isUp; // Defines if the arrow is pointing up or down

  const GradientSummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.percentage,
    required this.icon,
    required this.colors,
    this.isUp = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Keep it constrained internally to prevent it stretching too wide
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 20,
      ), // Adjusted padding to look proportional
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44, // Slightly smaller circle to match a tight width design
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13, // Slightly reduced
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22, // Shrunk from 26 to 22
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isUp ? Icons.arrow_upward : Icons.arrow_downward,
                      color: const Color(0xFF4BFFAA),
                      size: 12,
                    ),
                    Text(
                      ' $percentage',
                      style: const TextStyle(
                        color: Color(0xFF4BFFAA),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared clean summary card container (without forced Expanded wrapper).
class ModuleSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const ModuleSummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: card,
    );
  }
}
