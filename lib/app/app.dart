import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/domain/app_settings.dart';
import '../features/settings/presentation/settings_controller.dart';
import 'router.dart';
import 'theme.dart';

/// The root widget of the app.
class DiscordServerManagerApp extends ConsumerWidget {
  const DiscordServerManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsControllerProvider).value;
    final themeMode = settings?.themeMode ?? AppThemeMode.system;

    return MaterialApp.router(
      title: 'Discord Server Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      routerConfig: router,
    );
  }
}
