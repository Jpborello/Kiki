import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/welcome/welcome_screen.dart';

class KikiDrawApp extends StatelessWidget {
  const KikiDrawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KikiDraw',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const WelcomeScreen(),
    );
  }
}
