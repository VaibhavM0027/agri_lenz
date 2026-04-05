import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/main_shell.dart';
import 'theme/agri_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final dark = prefs.getBool('dark_mode') ?? false;
  runApp(AgriLenzApp(initialThemeMode: dark ? ThemeMode.dark : ThemeMode.light));
}

class AgriLenzApp extends StatefulWidget {
  const AgriLenzApp({super.key, required this.initialThemeMode});

  final ThemeMode initialThemeMode;

  @override
  State<AgriLenzApp> createState() => _AgriLenzAppState();
}

class _AgriLenzAppState extends State<AgriLenzApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
  }

  Future<void> _persistTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final p = await SharedPreferences.getInstance();
    await p.setBool('dark_mode', mode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agri Lenz',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AgriTheme.materialTheme(),
      darkTheme: AgriTheme.darkTheme(),
      home: MainShell(
        themeMode: _themeMode,
        onThemeModeChanged: _persistTheme,
      ),
    );
  }
}
