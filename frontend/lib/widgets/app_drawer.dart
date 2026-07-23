import 'package:flutter/material.dart';

import '../services/theme_controller.dart';

enum DrawerSection {
  home,
  news,
  fearGreed,
  market,
}

class AppDrawer extends StatelessWidget {
  final DrawerSection currentSection;
  final WidgetBuilder homeBuilder;
  final WidgetBuilder newsBuilder;
  final WidgetBuilder fearGreedBuilder;
  final WidgetBuilder marketBuilder;

  const AppDrawer({
    super.key,
    required this.currentSection,
    required this.homeBuilder,
    required this.newsBuilder,
    required this.fearGreedBuilder,
    required this.marketBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final headerGradient = isDark
        ? [const Color(0xFF1D4ED8), const Color(0xFF0F172A)]
        : [Colors.blue.shade600, Colors.blue.shade400];

    return Drawer(
      child: Container(
        color: drawerBg,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: headerGradient,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Pulse',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '실시간 분석 대시보드',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _DrawerMenuItem(
                      icon: Icons.home_rounded,
                      title: 'Pulse',
                      subtitle: '메인 화면',
                      current: currentSection == DrawerSection.home,
                      onTap: () {
                        Navigator.pop(context);
                        if (currentSection != DrawerSection.home) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: homeBuilder),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    _DrawerMenuItem(
                      icon: Icons.newspaper_rounded,
                      title: '실시간뉴스',
                      subtitle: '최신 뉴스',
                      current: currentSection == DrawerSection.news,
                      onTap: () {
                        Navigator.pop(context);
                        if (currentSection != DrawerSection.news) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: newsBuilder),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    _DrawerMenuItem(
                      icon: Icons.psychology_rounded,
                      title: '공포탐욕지수',
                      subtitle: '시장 심리',
                      current: currentSection == DrawerSection.fearGreed,
                      onTap: () {
                        Navigator.pop(context);
                        if (currentSection != DrawerSection.fearGreed) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: fearGreedBuilder),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    _DrawerMenuItem(
                      icon: Icons.show_chart_rounded,
                      title: '증시',
                      subtitle: '주요 시장 데이터',
                      current: currentSection == DrawerSection.market,
                      onTap: () {
                        Navigator.pop(context);
                        if (currentSection != DrawerSection.market) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: marketBuilder),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: Text(
                        '테마',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeController.instance.mode,
                        builder: (context, themeMode, _) {
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ThemeChoiceChip(
                                label: '시스템',
                                selected: themeMode == ThemeMode.system,
                                onTap: () => ThemeController.instance
                                    .setThemeMode(ThemeMode.system),
                              ),
                              _ThemeChoiceChip(
                                label: '라이트',
                                selected: themeMode == ThemeMode.light,
                                onTap: () => ThemeController.instance
                                    .setThemeMode(ThemeMode.light),
                              ),
                              _ThemeChoiceChip(
                                label: '다크',
                                selected: themeMode == ThemeMode.dark,
                                onTap: () => ThemeController.instance
                                    .setThemeMode(ThemeMode.dark),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: isDark ? Colors.grey.shade400 : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey[600],
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

class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool current;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
    final inactiveBg = isDark ? const Color(0xFF111827) : Colors.blue.shade50;
    final activeText = isDark ? Colors.white : Colors.black87;
    final inactiveText = isDark ? Colors.grey.shade300 : Colors.black87;
    return Material(
      color: current ? activeBg : (isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC)),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: current ? activeBg : inactiveBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: current
                      ? (isDark ? const Color(0xFF93C5FD) : Colors.blue)
                      : (isDark ? Colors.grey.shade400 : Colors.blue),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: current ? activeText : inactiveText,
                            ),
                          ),
                        ),
                        if (current) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF172554)
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '현재',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.blue.shade100
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.grey.shade500 : Colors.blueGrey.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected
            ? (isDark ? const Color(0xFF08111F) : Colors.white)
            : (isDark ? Colors.grey.shade200 : Colors.blueGrey.shade700),
      ),
      selectedColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.grey.shade100,
      side: BorderSide(
        color: selected
            ? Colors.transparent
            : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
