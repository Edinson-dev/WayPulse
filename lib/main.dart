import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'core/constants/app_theme.dart';
import 'config/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await WakelockPlus.enable();
  } catch (_) {
    // Wakelock puede no estar soportado en algunas plataformas web
  }
  runApp(
    const ProviderScope(
      child: WayPulseApp(),
    ),
  );
}

class WayPulseApp extends StatelessWidget {
  const WayPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WayPulse Navigation',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
