import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'models/app_settings.dart';
import 'providers/app_providers.dart';
import 'screens/home_timer_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const ProviderScope(child: MagnApp()));
}

class MagnApp extends ConsumerWidget {
  const MagnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePref = ref.watch(
      settingsProvider.select((s) => s.themePreference),
    );

    final themeMode = switch (themePref) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.oledBlack => ThemeMode.dark,
    };

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(pureOled: true),
      themeMode: themeMode,
      home: const HomeTimerScreen(),
    );
  }
}
