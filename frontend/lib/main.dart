import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'screens/landing_screen.dart';
import 'services/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  runApp(const MyApp());
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

ThemeData _buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2563EB),
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: Typography.material2021().black.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    canvasColor: const Color(0xFFF8FAFC),
    iconTheme: const IconThemeData(color: Color(0xFF334155)),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF1F5F9),
      disabledColor: const Color(0xFFE2E8F0),
      selectedColor: const Color(0xFFE0ECFF),
      secondarySelectedColor: const Color(0xFFDBEAFE),
      labelStyle: const TextStyle(color: Color(0xFF0F172A)),
      secondaryLabelStyle: const TextStyle(color: Color(0xFF2563EB)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8FAFC),
      foregroundColor: Color(0xFF0F172A),
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Color(0xFF2563EB),
      unselectedLabelColor: Color(0xFF64748B),
      dividerColor: Color(0xFFE2E8F0),
      indicatorColor: Color(0xFF2563EB),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
      ),
      hintStyle: const TextStyle(color: Color(0xFF64748B)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) return const Color(0xFF2563EB);
        return const Color(0xFF94A3B8);
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) return const Color(0xFFBFDBFE);
        return const Color(0xFFE2E8F0);
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF2563EB),
      linearTrackColor: Color(0xFFE2E8F0),
      circularTrackColor: Color(0xFFE2E8F0),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE2E8F0),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF2563EB),
      textColor: Color(0xFF0F172A),
    ),
  );
}

ThemeData _buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF60A5FA),
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF111827),
    onSurface: const Color(0xFFE5E7EB),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    textTheme: Typography.material2021().white.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    scaffoldBackgroundColor: const Color(0xFF0B1220),
    canvasColor: const Color(0xFF0B1220),
    iconTheme: const IconThemeData(color: Color(0xFFCBD5E1)),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF111827),
      disabledColor: const Color(0xFF1F2937),
      selectedColor: const Color(0xFF1D4ED8),
      secondarySelectedColor: const Color(0xFF1E3A8A),
      labelStyle: const TextStyle(color: Color(0xFFE5E7EB)),
      secondaryLabelStyle: const TextStyle(color: Color(0xFFBFDBFE)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0B1220),
      foregroundColor: Color(0xFFE5E7EB),
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Color(0xFF93C5FD),
      unselectedLabelColor: Color(0xFF94A3B8),
      dividerColor: Color(0xFF1F2937),
      indicatorColor: Color(0xFF60A5FA),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF111827),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.2),
      ),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) return const Color(0xFF60A5FA);
        return const Color(0xFF64748B);
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) return const Color(0xFF1E3A8A);
        return const Color(0xFF1F2937);
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF60A5FA),
      linearTrackColor: Color(0xFF1F2937),
      circularTrackColor: Color(0xFF1F2937),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF111827),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF111827),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Color(0xFF0F172A),
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF1F2937),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF60A5FA),
      textColor: Color(0xFFE5E7EB),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Pulse',
          debugShowCheckedModeBanner: false,
          scrollBehavior: _AppScrollBehavior(),
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: themeMode,
          home: const LandingScreen(),
        );
      },
    );
  }
}
