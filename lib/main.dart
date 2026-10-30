import 'package:flutter/material.dart';

import 'screens/login_page.dart';
import 'screens/shell_page.dart';
import 'session.dart';
import 'store.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FarmDeskApp(session: FarmSession(FarmStore())));
}

class FarmDeskApp extends StatefulWidget {
  const FarmDeskApp({super.key, required this.session});
  final FarmSession session;

  @override
  State<FarmDeskApp> createState() => _FarmDeskAppState();
}

class _FarmDeskAppState extends State<FarmDeskApp> {
  @override
  void initState() {
    super.initState();
    widget.session.restore();
    widget.session.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.session.token != null;
    return MaterialApp(
      title: 'Farm desk',
      theme: farmTheme(Brightness.light),
      darkTheme: farmTheme(Brightness.dark),
      themeMode: switch (widget.session.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: signedIn ? ShellPage(session: widget.session) : LoginPage(session: widget.session),
    );
  }
}
