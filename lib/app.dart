import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/cellar_theme_data.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'core/router.dart';

/// Root application widget
class WineCellarApp extends ConsumerWidget {
  const WineCellarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final immersive = ref.watch(immersiveCellarThemeProvider);
    final globalVisual = ref.watch(appVisualThemeProvider);
    final effective = immersive ?? globalVisual;

    final useOverride = CellarThemeData.overridesAppTheme(effective);

    return MaterialApp.router(
      title: 'Ma Cave à Vin',
      debugShowCheckedModeBanner: false,
      
      // Theme — override when an immersive or global visual theme is active
      theme: useOverride
          ? CellarThemeData.forTheme(effective!)
          : AppTheme.lightTheme,
      darkTheme: useOverride ? null : AppTheme.darkTheme,
      themeMode: useOverride ? ThemeMode.light : ThemeMode.system,
      
      // Routing
      routerConfig: appRouter,
      
      // Localization
      locale: const Locale('fr'),
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
