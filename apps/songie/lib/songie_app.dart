import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'settings/songie_settings.dart';

class SongieApp extends StatelessWidget {
  const SongieApp({required this.settings, super.key});

  final SongieSettings settings;

  @override
  Widget build(BuildContext context) {
    const foreground = Color(0xFF202020);
    return MaterialApp(
      title: 'Songie',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF505050),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: foreground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        dividerColor: const Color(0xFFE5E5E5),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: foreground,
          displayColor: foreground,
        ),
      ),
      home: HomeScreen(settings: settings),
    );
  }
}
