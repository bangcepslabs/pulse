import 'package:flutter/material.dart';

/// Shared visual tokens for Pulse's information-dense news surfaces.
abstract final class PulseUi {
  static const brand = Color(0xFF2563EB);
  static const maxContentWidth = 1180.0;
  static const sectionRadius = 18.0;
  static const itemRadius = 12.0;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color page(BuildContext context) =>
      isDark(context) ? const Color(0xFF08111F) : const Color(0xFFF5F7FA);

  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF101A2B) : Colors.white;

  static Color softSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF0D1727) : const Color(0xFFF8FAFC);

  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF243247) : const Color(0xFFE2E8F0);

  static Color strongBorder(BuildContext context) =>
      isDark(context) ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

  static Color primaryText(BuildContext context) =>
      isDark(context) ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

  static Color secondaryText(BuildContext context) =>
      isDark(context) ? const Color(0xFFB8C4D6) : const Color(0xFF526174);

  static Color mutedText(BuildContext context) =>
      isDark(context) ? const Color(0xFF8FA0B7) : const Color(0xFF718096);

  static Color brandSoft(BuildContext context) =>
      isDark(context) ? const Color(0xFF172554) : const Color(0xFFEEF4FF);

  static List<BoxShadow> shadow(BuildContext context,
      {bool prominent = false}) {
    final dark = isDark(context);
    return [
      BoxShadow(
        color: dark
            ? Colors.black.withValues(alpha: prominent ? 0.28 : 0.20)
            : const Color(0xFF0F172A)
                .withValues(alpha: prominent ? 0.07 : 0.04),
        blurRadius: prominent ? 24 : 14,
        offset: Offset(0, prominent ? 8 : 4),
      ),
    ];
  }

  static BoxDecoration sectionDecoration(
    BuildContext context, {
    bool prominent = false,
    Color? color,
    double radius = sectionRadius,
  }) {
    return BoxDecoration(
      color: color ?? surface(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border(context)),
      boxShadow: shadow(context, prominent: prominent),
    );
  }
}

class PulseSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PulseSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: PulseUi.brandSoft(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 17,
            color: PulseUi.isDark(context)
                ? const Color(0xFF93C5FD)
                : PulseUi.brand,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: PulseUi.primaryText(context),
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PulseUi.mutedText(context),
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}
